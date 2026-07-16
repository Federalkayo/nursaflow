import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Renders Mermaid diagram syntax using the official Mermaid.js library
/// loaded from a CDN inside a lightweight embedded WebView. This is the
/// standard approach for Flutter since there's no mature native Mermaid
/// renderer package — the WebView just displays static SVG output, no
/// navigation or interaction needed.
///
/// Expects raw Mermaid syntax, e.g.:
///   flowchart LR
///   A[Right Atrium] --> B[Right Ventricle]
class MermaidView extends StatefulWidget {
  const MermaidView({
    super.key,
    required this.diagram,
    this.height = 280,
    this.expandable = true,
  });

  final String diagram;
  final double height;

  /// Shows a small expand button (top-right) that opens a full-screen,
  /// larger version of the same diagram — mirrors the "expand" affordance
  /// ChatGPT and similar tools use for embedded diagrams.
  final bool expandable;

  @override
  State<MermaidView> createState() => _MermaidViewState();
}

class _MermaidViewState extends State<MermaidView> {
  late final WebViewController _controller;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _controller = _buildController(widget.diagram, onLoaded: () {
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  void didUpdateWidget(covariant MermaidView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.diagram != widget.diagram) {
      _loaded = false;
      _controller.loadHtmlString(_buildHtml(widget.diagram));
    }
  }

  void _openFullscreen() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, _, __) => _MermaidFullscreenView(diagram: widget.diagram),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              color: Colors.white,
              child: WebViewWidget(controller: _controller),
            ),
            if (!_loaded)
              Container(
                color: AppColors.surfaceContainerLow,
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ),
            if (widget.expandable && _loaded)
              Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _openFullscreen,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.open_in_full, size: 16, color: Colors.white),
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

class _MermaidFullscreenView extends StatefulWidget {
  const _MermaidFullscreenView({required this.diagram});
  final String diagram;

  @override
  State<_MermaidFullscreenView> createState() => _MermaidFullscreenViewState();
}

class _MermaidFullscreenViewState extends State<_MermaidFullscreenView> {
  late final WebViewController _controller;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _controller = _buildController(widget.diagram, onLoaded: () {
      if (mounted) setState(() => _loaded = true);
    });
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: Stack(
                  children: [
                    Container(color: Colors.white, child: WebViewWidget(controller: _controller)),
                    if (!_loaded)
                      Container(
                        color: AppColors.surfaceContainerLow,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

WebViewController _buildController(String diagram, {required VoidCallback onLoaded}) {
  return WebViewController()
    ..setBackgroundColor(Colors.transparent)
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setNavigationDelegate(
      NavigationDelegate(onPageFinished: (_) => onLoaded()),
    )
    ..loadHtmlString(_buildHtml(diagram));
}

String _buildHtml(String diagram) {
  // Mermaid syntax is embedded as-is inside a <pre class="mermaid"> block.
  // Escaping only what's needed to stay valid inside the HTML tag.
  final escaped = diagram
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=yes">
  <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
  <style>
    html, body {
      margin: 0;
      padding: 12px;
      background: transparent;
      display: flex;
      justify-content: center;
      align-items: center;
      overflow: auto;
      width: 100%;
      height: 100%;
      box-sizing: border-box;
    }
    .mermaid { font-family: -apple-system, Roboto, sans-serif; width: 100%; }
    /* Mermaid renders its SVG at a small fixed pixel size by default —
       force it to stretch to fill the available container instead, which
       is what actually fixes the "diagram is tiny" problem. */
    .mermaid svg {
      width: 100% !important;
      height: auto !important;
      max-width: none !important;
    }
  </style>
</head>
<body>
  <pre class="mermaid">
$escaped
  </pre>
  <script>
    mermaid.initialize({
      startOnLoad: true,
      theme: 'neutral',
      securityLevel: 'loose',
      // Bumped from 20px -> 28px: node labels were hard to read at the
      // small size the chat bubble renders the diagram at.
      themeVariables: { fontSize: '28px' },
      flowchart: { useMaxWidth: true, htmlLabels: true }
    });
  </script>
</body>
</html>
''';
}