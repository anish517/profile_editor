import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'avatar_processor.dart';
import 'avatar_storage.dart';

class AvatarEditorScreen extends StatefulWidget {
  const AvatarEditorScreen({
    required this.sourcePath,
    required this.storage,
    required this.processor,
    super.key,
  });

  final String sourcePath;
  final AvatarStorage storage;
  final AvatarProcessor processor;

  @override
  State<AvatarEditorScreen> createState() => _AvatarEditorScreenState();
}

class _AvatarEditorScreenState extends State<AvatarEditorScreen> {
  final GlobalKey _previewKey = GlobalKey();
  final TransformationController _controller = TransformationController();

  double _zoom = 1.0;
  double _brightness = 0;
  bool _isBusy = false;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncZoomFromTransform);
  }

  @override
  void dispose() {
    _controller.removeListener(_syncZoomFromTransform);
    _controller.dispose();
    super.dispose();
  }

  void _syncZoomFromTransform() {
    final scale = _controller.value.getMaxScaleOnAxis().clamp(1.0, 4.0);
    if ((scale - _zoom).abs() > 0.01 && mounted) {
      setState(() {
        _zoom = scale;
      });
    }
  }

  Future<void> _setZoom(double value) async {
    final currentScale = _controller.value.getMaxScaleOnAxis();
    final ratio = value / currentScale;

    final box = _previewKey.currentContext?.findRenderObject() as RenderBox?;
    final size = box?.size ?? const Size(300, 300);
    final center = Offset(size.width / 2, size.height / 2);

    final scaleMatrix = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(ratio, ratio, ratio, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);

    final next = scaleMatrix * _controller.value;

    setState(() {
      _zoom = value;
      _isDirty = true;
      _controller.value = next;
    });
  }

  Future<void> _resetEdits() async {
    setState(() {
      _zoom = 1.0;
      _brightness = 0;
      _isDirty = false;
      _controller.value = Matrix4.identity();
    });
  }

  Future<bool> _confirmDiscardIfNeeded() async {
    if (!_isDirty) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Discard changes?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Discard'),
            ),
          ],
        );
      },
    );

    return shouldDiscard ?? false;
  }

  Future<void> _save() async {
    final boundaryContext = _previewKey.currentContext;
    if (boundaryContext == null || _isBusy) return;

    setState(() {
      _isBusy = true;
    });

    try {
      final boundary =
          boundaryContext.findRenderObject() as RenderRepaintBoundary;
      final capturedImage = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await capturedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final pngBytes = byteData?.buffer.asUint8List();
      if (pngBytes == null) {
        throw StateError('Failed to capture avatar preview.');
      }

      final jpg = await widget.processor.finalizeAvatar(pngBytes);
      final savedPath = await widget.storage.saveAvatar(jpg);
      if (!mounted) return;
      Navigator.of(context).pop(savedPath);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save avatar. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  List<double> _brightnessMatrix(double value) {
    final shift = (value / 100) * 255;
    return <double>[
      1,
      0,
      0,
      0,
      shift,
      0,
      1,
      0,
      0,
      shift,
      0,
      0,
      1,
      0,
      shift,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  Future<void> _handleBackNavigation(bool didPop) async {
    if (didPop) return;
    final allowPop = await _confirmDiscardIfNeeded();
    if (allowPop && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = SizedBox(
      width: 300,
      height: 300,
      child: Stack(
        children: [
          RepaintBoundary(
            key: _previewKey,
            child: ClipRect(
              child: ColoredBox(
                color: Colors.black,
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  transformationController: _controller,
                  onInteractionStart: (_) {
                    setState(() {
                      _isDirty = true;
                    });
                  },
                  child: ColorFiltered(
                    colorFilter: ColorFilter.matrix(
                      _brightnessMatrix(_brightness),
                    ),
                    child: Image.file(
                      File(widget.sourcePath),
                      fit: BoxFit.cover,
                      width: 300,
                      height: 300,
                      errorBuilder: (_, _, _) {
                        return const Center(
                          child: Text('Could not load selected image.'),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: CustomPaint(
              size: const Size(300, 300),
              painter: _CircularAvatarOverlayPainter(),
            ),
          ),
        ],
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _handleBackNavigation(didPop),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit avatar'),
          actions: [
            TextButton(
              onPressed: _isBusy ? null : _resetEdits,
              child: const Text('Reset'),
            ),
            TextButton(
              onPressed: _isBusy ? null : _save,
              child: const Text('Save avatar'),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(child: preview),
              const SizedBox(height: 24),
              const Text('Zoom'),
              Slider(
                value: _zoom,
                min: 1,
                max: 4,
                divisions: 300,
                onChanged: _isBusy ? null : _setZoom,
              ),
              const SizedBox(height: 12),
              const Text('Brightness'),
              Slider(
                value: _brightness,
                min: -100,
                max: 100,
                divisions: 200,
                onChanged: _isBusy
                    ? null
                    : (value) {
                        setState(() {
                          _brightness = value;
                          _isDirty = true;
                        });
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircularAvatarOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.35);
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, overlayPaint);
    canvas.drawCircle(center, radius, clearPaint);
    canvas.drawCircle(center, radius, borderPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
