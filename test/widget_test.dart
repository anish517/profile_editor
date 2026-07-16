import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profile_editor/src/avatar_image_picker.dart';
import 'package:profile_editor/src/avatar_processor.dart';
import 'package:profile_editor/src/avatar_storage.dart';
import 'package:profile_editor/src/profile_screen.dart';

class _FakeStorage implements AvatarStorage {
  String? avatarPath;
  bool removeShouldThrow = false;
  int removeCalls = 0;

  @override
  Future<String?> getCurrentAvatarPath() async => avatarPath;

  @override
  Future<void> removeAvatar() async {
    removeCalls += 1;
    if (removeShouldThrow) {
      throw StateError('remove failed');
    }
    avatarPath = null;
  }

  @override
  Future<String> saveAvatar(Uint8List jpgBytes) async {
    avatarPath = '/tmp/avatar.jpg';
    return avatarPath!;
  }
}

class _FakePicker implements AvatarPicker {
  AvatarImageSource? lastSource;

  @override
  Future<String?> pickImage(AvatarImageSource source) async {
    lastSource = source;
    return null;
  }
}

void main() {
  testWidgets('edit avatar opens source chooser options', (
    WidgetTester tester,
  ) async {
    final fakeStorage = _FakeStorage();
    final fakePicker = _FakePicker();

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          storage: fakeStorage,
          imagePicker: fakePicker,
          processor: AvatarProcessor(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit avatar'));
    await tester.pumpAndSettle();

    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('remove avatar asks for confirmation and cancels cleanly', (
    WidgetTester tester,
  ) async {
    final fakeStorage = _FakeStorage()..avatarPath = '/tmp/avatar.jpg';
    final fakePicker = _FakePicker();

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          storage: fakeStorage,
          imagePicker: fakePicker,
          processor: AvatarProcessor(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remove avatar'));
    await tester.pumpAndSettle();
    expect(find.text('Remove current avatar?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(fakeStorage.removeCalls, 0);
  });
}
