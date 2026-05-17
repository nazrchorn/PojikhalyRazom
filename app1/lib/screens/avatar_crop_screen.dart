import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class AvatarCropScreen extends StatefulWidget {
  final File imageFile;
  final Color accentColor;

  const AvatarCropScreen({
    super.key,
    required this.imageFile,
    this.accentColor = const Color(0xFF1F6F66),
  });

  @override
  State<AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<AvatarCropScreen> {
  final GlobalKey _captureKey = GlobalKey();
  final TransformationController _controller = TransformationController();
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _resetView() {
    _controller.value = Matrix4.identity();
  }

  Future<void> _confirmCrop() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);
    try {
      final boundary = _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Не вдалося знайти область кадрування');
      }

      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Не вдалося зберегти зображення');
      }

      final tempDir = await Directory.systemTemp.createTemp('avatar_crop_');
      final outFile = File('${tempDir.path}${Platform.pathSeparator}avatar_${DateTime.now().millisecondsSinceEpoch}.png');
      await outFile.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

      if (!mounted) return;
      Navigator.pop(context, outFile);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не вдалося зберегти кадрований аватар: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double cropSize = (size.width - 48).clamp(260.0, 360.0);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Підігнати аватар'),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        surfaceTintColor: Theme.of(context).appBarTheme.surfaceTintColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'Збільшуй і рухай фото так, щоб обличчя було в центрі круга',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: cropSize,
                  height: cropSize,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(cropSize / 2),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: RepaintBoundary(
                    key: _captureKey,
                    child: ClipOval(
                      child: Container(
                        color: Colors.transparent,
                        child: InteractiveViewer(
                          transformationController: _controller,
                          minScale: 1.0,
                          maxScale: 4.0,
                          boundaryMargin: const EdgeInsets.all(80),
                          clipBehavior: Clip.none,
                          child: SizedBox.expand(
                            child: Image.file(
                              widget.imageFile,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : _resetView,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Скинути'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _confirmCrop,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.accentColor,
                      foregroundColor: Colors.white,
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(_isSaving ? 'Збереження...' : 'Підтвердити'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                child: const Text('Скасувати'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

