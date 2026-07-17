import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/responsive_page.dart';
import '../../core/widgets/skeleton.dart';
import 'models/resource.dart';
import 'youtube_player_screen.dart';

class ResourcesScreen extends ConsumerWidget {
  const ResourcesScreen({super.key, required this.documentId});
  final String documentId;

  Future<void> _open(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _playInApp(BuildContext context, YoutubeResource video) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => YoutubePlayerScreen(video: video)),
    );
  }

  void _handleYoutubeTap(BuildContext context, YoutubeResource video) {
    if (video.embeddable) {
      _playInApp(context, video);
    } else {
      _open(video.watchUrl);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resourcesAsync = ref.watch(documentResourcesProvider(documentId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Resources'),
      ),
      body: SafeArea(
        child: resourcesAsync.when(
          data: (resources) {
            if (resources.isEmpty) {
              return _EmptyState(
                onRetry: () => ref.invalidate(documentResourcesProvider(documentId)),
              );
            }
            return ListView(
              children: [
                ResponsivePage(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (resources.youtube.isNotEmpty) ...[
                        _SectionHeader(
                          icon: Symbols.play_circle,
                          title: 'YouTube Lectures (${resources.youtube.length})',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final (i, v) in resources.youtube.indexed)
                          _YoutubeCard(
                            video: v,
                            isRecommended: i == 0,
                            onTap: () => _handleYoutubeTap(context, v),
                          ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      if (resources.books.isNotEmpty) ...[
                        _SectionHeader(
                          icon: Symbols.menu_book,
                          title: 'Google Books (${resources.books.length})',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          height: 190,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: resources.books.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: AppSpacing.sm),
                            itemBuilder: (context, i) {
                              final b = resources.books[i];
                              return _BookCard(book: b, onTap: () => _open(b.infoLink));
                            },
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      if (resources.medline.isNotEmpty) ...[
                        _SectionHeader(
                          icon: Symbols.medical_information,
                          title: 'MedlinePlus (${resources.medline.length})',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final m in resources.medline)
                          _MedlineCard(item: m, onTap: () => _open(m.url)),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: SkeletonList(itemCount: 5, thumbnailSize: 64),
          ),
          error: (err, stack) => _EmptyState(
            message: "Couldn't load resources. Check your connection and try again.",
            onRetry: () => ref.invalidate(documentResourcesProvider(documentId)),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(title, style: AppTextStyles.headlineMd()),
      ],
    );
  }
}

class _YoutubeCard extends StatelessWidget {
  const _YoutubeCard({
    required this.video,
    required this.onTap,
    this.isRecommended = false,
  });
  final YoutubeResource video;
  final VoidCallback onTap;
  final bool isRecommended;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: video.thumbnailUrl.isNotEmpty
                  ? Image.network(
                      video.thumbnailUrl,
                      width: 100,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumbFallback(),
                    )
                  : _thumbFallback(),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isRecommended) ...[
                    Row(
                      children: [
                        const Icon(Symbols.star, color: AppColors.secondary, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          'Recommended',
                          style: AppTextStyles.bodySm().copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelLg(),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          video.channelTitle,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySm(),
                        ),
                      ),
                      if (video.duration.isNotEmpty) ...[
                        Text(' · ', style: AppTextStyles.bodySm()),
                        Icon(Symbols.schedule, size: 12, color: AppColors.onSurfaceVariant),
                        const SizedBox(width: 2),
                        Text(video.duration, style: AppTextStyles.bodySm()),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  video.embeddable ? Symbols.play_circle : Symbols.open_in_new,
                  color: AppColors.primary,
                  size: 28,
                ),
                if (!video.embeddable) ...[
                  const SizedBox(height: 2),
                  Text('YouTube', style: AppTextStyles.bodySm()),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbFallback() => Container(
        width: 100,
        height: 64,
        color: AppColors.surfaceContainerLow,
        child: const Icon(Symbols.play_circle, color: AppColors.onSurfaceVariant),
      );
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book, required this.onTap});
  final BookResource book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: book.thumbnailUrl.isNotEmpty
                  ? Image.network(
                      book.thumbnailUrl,
                      height: 100,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumbFallback(),
                    )
                  : _thumbFallback(),
            ),
            const SizedBox(height: 6),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSm(),
            ),
            if (book.authors.isNotEmpty)
              Text(
                book.authors,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySm(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _thumbFallback() => Container(
        height: 100,
        width: double.infinity,
        color: AppColors.surfaceContainerLow,
        child: const Icon(Symbols.menu_book, color: AppColors.onSurfaceVariant),
      );
}

class _MedlineCard extends StatelessWidget {
  const _MedlineCard({required this.item, required this.onTap});
  final MedlineResource item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.title, style: AppTextStyles.labelLg()),
            if (item.snippet.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.snippet,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySm(),
              ),
            ],
            const SizedBox(height: 4),
            Text('medlineplus.gov', style: AppTextStyles.bodySm(color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.message, required this.onRetry});
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.search_off, size: 48, color: AppColors.onSurfaceVariant),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message ?? 'No extra resources found for this topic yet.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMd(),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}