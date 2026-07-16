import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:profile_editor/src/avatar_processor.dart';

void main() {
  test('normalizeForEditing downscales images larger than 4096px', () async {
    final processor = AvatarProcessor();
    final image = img.Image(width: 5000, height: 3000);
    final bytes = Uint8List.fromList(img.encodeJpg(image, quality: 95));
    final file = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}big_test.jpg',
    );
    await file.writeAsBytes(bytes, flush: true);

    final normalized = await processor.normalizeForEditing(file.path);
    final decoded = img.decodeJpg(normalized)!;

    expect(decoded.width, lessThanOrEqualTo(4096));
    expect(decoded.height, lessThanOrEqualTo(4096));
    if (file.existsSync()) {
      await file.delete();
    }
  });

  test('finalizeAvatar exports fixed 512x512 jpeg', () async {
    final processor = AvatarProcessor();
    final source = img.Image(width: 300, height: 300);
    final png = Uint8List.fromList(img.encodePng(source));

    final jpeg = await processor.finalizeAvatar(png);
    final decoded = img.decodeJpg(jpeg)!;

    expect(decoded.width, 512);
    expect(decoded.height, 512);
  });
}
