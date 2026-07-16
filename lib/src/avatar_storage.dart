import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract class AvatarStorage {
  Future<String?> getCurrentAvatarPath();
  Future<String> saveAvatar(Uint8List jpgBytes);
  Future<void> removeAvatar();
}

class LocalAvatarStorage implements AvatarStorage {
  static const _avatarFileName = 'avatar.jpg';

  Future<String> _avatarPath() async {
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, _avatarFileName);
  }

  @override
  Future<String?> getCurrentAvatarPath() async {
    final path = await _avatarPath();
    final file = File(path);
    return file.existsSync() ? path : null;
  }

  @override
  Future<String> saveAvatar(Uint8List jpgBytes) async {
    final targetPath = await _avatarPath();
    final targetFile = File(targetPath);
    final tempFile = File('$targetPath.tmp');

    await tempFile.writeAsBytes(jpgBytes, flush: true);
    if (targetFile.existsSync()) {
      await targetFile.delete();
    }
    await tempFile.rename(targetPath);
    return targetPath;
  }

  @override
  Future<void> removeAvatar() async {
    final path = await _avatarPath();
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
