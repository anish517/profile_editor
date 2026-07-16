import 'package:image_picker/image_picker.dart';

enum AvatarImageSource { camera, gallery }

abstract class AvatarPicker {
  Future<String?> pickImage(AvatarImageSource source);
}

class AvatarImagePicker implements AvatarPicker {
  AvatarImagePicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> pickImage(AvatarImageSource source) async {
    final picked = await _picker.pickImage(
      source: source == AvatarImageSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 4096,
      maxHeight: 4096,
      imageQuality: 95,
    );
    return picked?.path;
  }
}
