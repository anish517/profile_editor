import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class AvatarProcessor {
  Future<Uint8List> normalizeForEditing(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    return compute(_normalizeForEditingSync, bytes);
  }

  Future<Uint8List> finalizeAvatar(Uint8List squarePngBytes) async {
    return compute(_finalizeAvatarSync, squarePngBytes);
  }
}

Uint8List _normalizeForEditingSync(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw StateError('Could not decode selected image.');
  }

  final maxSide = decoded.width > decoded.height
      ? decoded.width
      : decoded.height;
  final img.Image normalized = maxSide > 4096
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? 4096 : null,
          height: decoded.height > decoded.width ? 4096 : null,
          interpolation: img.Interpolation.average,
        )
      : decoded;

  return Uint8List.fromList(img.encodeJpg(normalized, quality: 95));
}

Uint8List _finalizeAvatarSync(Uint8List squarePngBytes) {
  final decoded = img.decodePng(squarePngBytes);
  if (decoded == null) {
    throw StateError('Could not process edited image.');
  }

  final resized = img.copyResize(
    decoded,
    width: 512,
    height: 512,
    interpolation: img.Interpolation.cubic,
  );

  return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
}
