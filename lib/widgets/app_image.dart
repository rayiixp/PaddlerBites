import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../services/firestore_image_store.dart';

/// Network image with a grey placeholder for missing or broken URLs.
class AppNetworkImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData placeholderIcon;

  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.fastfood_outlined,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return _placeholder();
    if (FirestoreImageStore.isReference(url)) {
      // Photo saved in Firestore (project without a Storage bucket).
      return FutureBuilder<Uint8List?>(
        future: FirestoreImageStore.load(url!),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) return _placeholder();
          return Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => _placeholder(),
          );
        },
      );
    }
    return Image.network(
      url!,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => _placeholder(),
      loadingBuilder: (context, child, progress) => progress == null ? child : _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade100,
      child: Center(child: Icon(placeholderIcon, color: Colors.grey.shade400)),
    );
  }
}

/// Stall logo tile: the uploaded photo, or the storefront icon on the stall colour.
class StallLogo extends StatelessWidget {
  final String imageUrl;
  final double size;
  final double radius;
  final Color bgColor;

  const StallLogo({
    super.key,
    required this.imageUrl,
    required this.size,
    this.radius = 16,
    this.bgColor = const Color(0xFF0D3B2E),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(radius)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: imageUrl.isEmpty
            ? Icon(Icons.storefront_outlined, color: AppTheme.primaryColor, size: size * 0.5)
            : AppNetworkImage(url: imageUrl, width: size, height: size, placeholderIcon: Icons.storefront_outlined),
      ),
    );
  }
}
