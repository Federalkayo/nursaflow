import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'models/resource.dart';

/// Plays a YoutubeResource in-app instead of handing off to the YouTube app
/// or an external browser tab.
class YoutubePlayerScreen extends StatefulWidget {
  const YoutubePlayerScreen({super.key, required this.video});
  final YoutubeResource video;

  @override
  State<YoutubePlayerScreen> createState() => _YoutubePlayerScreenState();
}

/// Shown when YouTube rejects the embed (owner-restricted video, or a
/// referrer/origin mismatch some videos are stricter about). Rather than
/// leaving YouTube's broken-looking error screen on display, we hand off
/// to the YouTube app / browser, which always works.
class _EmbedBlockedFallback extends StatelessWidget {
  const _EmbedBlockedFallback({required this.video, required this.error});
  final YoutubeResource video;
  final YoutubeError error;

  String get _debugLabel => switch (error.code) {
        0 => '',
        2 => 'Invalid video ID (code 2)',
        5 => 'HTML5/WebView player error (code 5)',
        100 || 105 => 'Video not found (code ${error.code})',
        101 || 150 || 152 => 'Owner disabled embedding (code ${error.code})',
        final c => 'Unrecognised error code $c',
      };

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Colors.black,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Symbols.error, color: Colors.white70, size: 36),
            const SizedBox(height: 12),
            const Text(
              "This video can't be played in-app",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            // TEMPORARY — remove once we've confirmed the real cause from a
            // test device. Not gated behind kDebugMode on purpose so it
            // shows in your release-mode Infinix test build too.
            const SizedBox(height: 4),
            Text(
              _debugLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                final uri = Uri.tryParse(video.watchUrl);
                if (uri != null) {
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Symbols.open_in_new),
              label: const Text('Watch on YouTube'),
            ),
          ],
        ),
      ),
    );
  }
}

class _YoutubePlayerScreenState extends State<YoutubePlayerScreen> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        strictRelatedVideos: true,
        // Deliberately not setting `origin` here. It's documented as "your
        // domain" — on mobile it becomes the WebView's actual baseUrl, so
        // setting it to youtube.com (as this used to) told the WebView to
        // pretend it was being served FROM youtube.com, which broke the
        // JS<->Dart postMessage bridge for every video regardless of that
        // video's own embed permissions. Leaving it unset lets the package
        // fall back to its own documented `host` default instead.
      ),
    )..loadVideoById(videoId: widget.video.videoId);
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.video.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            YoutubeValueBuilder(
              controller: _controller,
              builder: (context, value) {
                if (value.hasError) {
                  return _EmbedBlockedFallback(video: widget.video, error: value.error);
                }
                return YoutubePlayer(
                  controller: _controller,
                  aspectRatio: 16 / 9,
                );
              },
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.video.title,
                      style: AppTextStyles.headlineMd(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.video.channelTitle,
                      style: AppTextStyles.bodySm(color: AppColors.onSurfaceVariant),
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