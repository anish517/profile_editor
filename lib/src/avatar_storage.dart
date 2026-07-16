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
  static const _avatarStateFileName = 'avatar_current.txt';

  Future<String> _docsPath() async {
    final docs = await getApplicationDocumentsDirectory();
    return docs.path;
  }

  Future<String> _stateFilePath() async {
    final docsPath = await _docsPath();
    return p.join(docsPath, _avatarStateFileName);
  }

  @override
  Future<String?> getCurrentAvatarPath() async {
    final statePath = await _stateFilePath();
    final stateFile = File(statePath);
    if (!stateFile.existsSync()) {
      return null;
    }

    final currentPath = (await stateFile.readAsString()).trim();
    if (currentPath.isEmpty) {
      return null;
    }

    final avatarFile = File(currentPath);
    return avatarFile.existsSync() ? currentPath : null;
  }

  @override
  Future<String> saveAvatar(Uint8List jpgBytes) async {
    final docsPath = await _docsPath();
    final previousPath = await getCurrentAvatarPath();

    final avatarFileName = 'avatar_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final nextAvatarPath = p.join(docsPath, avatarFileName);
    final nextAvatarTempPath = '$nextAvatarPath.tmp';

    await File(nextAvatarTempPath).writeAsBytes(jpgBytes, flush: true);
    await File(nextAvatarTempPath).rename(nextAvatarPath);

    final statePath = await _stateFilePath();
    final stateTempPath = '$statePath.tmp';
    await File(stateTempPath).writeAsString(nextAvatarPath, flush: true);
    final stateFile = File(statePath);
    if (stateFile.existsSync()) {
      await stateFile.delete();
    }
    await File(stateTempPath).rename(statePath);

    if (previousPath != null && previousPath != nextAvatarPath) {
      final previousFile = File(previousPath);
      if (previousFile.existsSync()) {
        try {
          await previousFile.delete();
        } catch (_) {
          // Best effort cleanup; current avatar reference already switched.
        }
      }
    }

    return nextAvatarPath;
  }

  @override
  Future<void> removeAvatar() async {
    final currentPath = await getCurrentAvatarPath();
    if (currentPath != null) {
      final avatarFile = File(currentPath);
      if (avatarFile.existsSync()) {
        await avatarFile.delete();
      }
    }

    final statePath = await _stateFilePath();
    final stateFile = File(statePath);
    if (stateFile.existsSync()) {
      await stateFile.delete();
    }
  }
}
