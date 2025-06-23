import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';

class ImageViewerScreen extends StatelessWidget {
  final String imageUrl;

  const ImageViewerScreen({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: kIsWeb
            ? _buildWebImage()
            : _buildMobileImage(),
      ),
    );
  }

  Widget _buildWebImage() {
    return Image.network(
      imageUrl,
      headers: const {'Origin': 'http://localhost'},
      fit: BoxFit.contain,
      loadingBuilder: (_, child, progress) {
        return progress == null
            ? child
            : const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      },
      errorBuilder: (_, __, error) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 50),
            const SizedBox(height: 16),
            const Text(
              'Error al cargar la imagen',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Solución: Actualiza la página (F5)',
              style: TextStyle(color: Colors.white.withOpacity(0.8)),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 16),
              Text(
                'Detalle técnico: ${error.toString()}',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMobileImage() {
    return ExtendedImage.network(
      imageUrl,
      fit: BoxFit.contain,
      mode: ExtendedImageMode.gesture,
      enableLoadState: true,
      initGestureConfigHandler: (_) => GestureConfig(
        minScale: 0.8,
        maxScale: 4.0,
        initialScale: 1.0,
        cacheGesture: false,
      ),
      loadStateChanged: (state) {
        switch (state.extendedImageLoadState) {
          case LoadState.loading:
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          case LoadState.failed:
            return const Center(
              child: Text(
                'Error al cargar la imagen',
                style: TextStyle(color: Colors.white),
              ),
            );
          case LoadState.completed:
            return null;
        }
      },
    );
  }
}