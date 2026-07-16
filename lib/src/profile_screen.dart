import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'avatar_editor_screen.dart';
import 'avatar_image_picker.dart';
import 'avatar_processor.dart';
import 'avatar_storage.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.storage,
    required this.imagePicker,
    required this.processor,
    super.key,
  });

  final AvatarStorage storage;
  final AvatarPicker imagePicker;
  final AvatarProcessor processor;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _avatarPath;
  int _avatarRevision = 0;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final path = await widget.storage.getCurrentAvatarPath();
    if (!mounted) return;
    setState(() {
      _avatarPath = path;
    });
  }

  Future<void> _pickAndEditAvatar() async {
    final source = await showModalBottomSheet<AvatarImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Camera'),
                onTap: () =>
                    Navigator.of(context).pop(AvatarImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Gallery'),
                onTap: () =>
                    Navigator.of(context).pop(AvatarImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    try {
      final selectedPath = await widget.imagePicker.pickImage(source);
      if (selectedPath == null || !mounted) return;
      final savedPath = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => AvatarEditorScreen(
            sourcePath: selectedPath,
            storage: widget.storage,
            processor: widget.processor,
          ),
        ),
      );
      if (savedPath == null || !mounted) return;
      await FileImage(File(savedPath)).evict();
      setState(() {
        _avatarPath = savedPath;
        _avatarRevision += 1;
      });
    } on PlatformException {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Permission needed'),
            content: const Text(
              'Please grant camera/gallery permission to continue.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _pickAndEditAvatar();
                },
                child: const Text('Try again'),
              ),
              FilledButton(
                onPressed: () async {
                  await openAppSettings();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Open settings'),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _removeAvatar() async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove current avatar?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove avatar'),
            ),
          ],
        );
      },
    );

    if (shouldRemove != true) return;

    try {
      final previousPath = _avatarPath;
      await widget.storage.removeAvatar();
      if (previousPath != null) {
        await FileImage(File(previousPath)).evict();
      }
      if (!mounted) return;
      setState(() {
        _avatarPath = null;
        _avatarRevision += 1;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not remove avatar. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarProvider = _avatarPath == null
        ? null
        : FileImage(File(_avatarPath!));
    return Scaffold(
      appBar: AppBar(title: const Text('Profile Editor')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              key: ValueKey('avatar-$_avatarRevision'),
              radius: 56,
              backgroundImage: avatarProvider,
              child: avatarProvider == null
                  ? const Icon(Icons.person, size: 56)
                  : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _pickAndEditAvatar,
              child: const Text('Edit avatar'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _avatarPath == null ? null : _removeAvatar,
              child: const Text('Remove avatar'),
            ),
          ],
        ),
      ),
    );
  }
}
