import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// Full-screen pinch-to-zoom viewer for AI-generated illustrations —
/// same interaction pattern as MermaidView's expand button, applied to
/// images instead of diagrams.
class ZoomableImageView extends StatelessWidget {
  const ZoomableImageView({super.key, required this.imageUrl});
  final String imageUrl;
  static void open(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, _, __) => ZoomableImageView(imageUrl: imageUrl),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Expanded(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const CircularProgressIndicator(color: Colors.white);
                    },
                    errorBuilder: (context, error, stack) => const Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small expand-icon overlay button, matching MermaidView's affordance —
/// drop this into a Stack positioned top-right over an image.
class ExpandButton extends StatelessWidget {
  const ExpandButton({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 6,
      right: 6,
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.open_in_full, size: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}