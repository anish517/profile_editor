import 'package:flutter/material.dart';

import 'src/avatar_image_picker.dart';
import 'src/avatar_processor.dart';
import 'src/avatar_storage.dart';
import 'src/profile_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Profile Editor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: ProfileScreen(
        storage: LocalAvatarStorage(),
        imagePicker: AvatarImagePicker(),
        processor: AvatarProcessor(),
      ),
    );
  }
}
