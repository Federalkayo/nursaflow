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
  const _EmbedBlockedFallback({required this.video});
  final YoutubeResource video;

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
        // Explicit origin avoids a common mobile-WebView false positive
        // (error 152 / "video unavailable") caused by a missing referrer.
        origin: 'https://www.youtube.com',
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
                  return _EmbedBlockedFallback(video: widget.video);
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