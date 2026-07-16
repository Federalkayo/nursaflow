import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Wraps [child] in the app's standard shimmer sweep. Put a stack of
/// [SkeletonBox]/[SkeletonLine] placeholders inside while real content
/// loads, instead of a bare [CircularProgressIndicator].
class AppShimmer extends StatelessWidget {
  const AppShimmer({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceContainerHigh,
      highlightColor: AppColors.surfaceContainerLowest,
      period: const Duration(milliseconds: 1400),
      child: child,
    );
  }
}

/// A solid placeholder block. Size it to roughly match the real content
/// it's standing in for (a line of text, a thumbnail, a card, etc).
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = 6,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Shorthand for a single line of skeleton text.
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({super.key, this.width, this.height = 14});
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) =>
      SkeletonBox(width: width, height: height, borderRadius: 4);
}

/// Skeleton for a single list row: square thumbnail + two lines of text.
/// Matches the shape of document/resource/task list items across the app.
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({
    super.key,
    this.thumbnailSize = 56,
    this.showThumbnail = true,
  });

  final double thumbnailSize;
  final bool showThumbnail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          if (showThumbnail) ...[
            SkeletonBox(width: thumbnailSize, height: thumbnailSize, borderRadius: 12),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLine(width: double.infinity),
                const SizedBox(height: 8),
                SkeletonLine(width: thumbnailSize + 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A shimmering vertical list of [SkeletonListTile]s — drop-in replacement
/// for `Center(child: CircularProgressIndicator())` on any screen whose
/// `data` case renders a list of rows.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.itemCount = 6,
    this.thumbnailSize = 56,
    this.showThumbnail = true,
  });

  final int itemCount;
  final double thumbnailSize;
  final bool showThumbnail;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Column(
        children: List.generate(
          itemCount,
          (_) => SkeletonListTile(
            thumbnailSize: thumbnailSize,
            showThumbnail: showThumbnail,
          ),
        ),
      ),
    );
  }
}

/// A shimmering grid of card-shaped placeholders — for the Library grid and
/// similar card layouts.
class SkeletonGrid extends StatelessWidget {
  const SkeletonGrid({
    super.key,
    this.itemCount = 6,
    this.maxCrossAxisExtent = 260,
    this.childAspectRatio = 0.85,
  });

  final int itemCount;
  final double maxCrossAxisExtent;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: maxCrossAxisExtent,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: itemCount,
        itemBuilder: (_, __) => SkeletonBox(
          width: double.infinity,
          height: double.infinity,
          borderRadius: 16,
        ),
      ),
    );
  }
}

/// A shimmering horizontal row of card-shaped placeholders — for horizontal
/// "continue studying" style carousels.
class SkeletonRow extends StatelessWidget {
  const SkeletonRow({
    super.key,
    this.itemCount = 3,
    this.itemWidth = 220,
    this.height = 200,
  });

  final int itemCount;
  final double itemWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (_, __) => SkeletonBox(
            width: itemWidth,
            height: height,
            borderRadius: 16,
          ),
        ),
      ),
    );
  }
}

/// A single big card placeholder — for one-item-at-a-time views like a
/// flashcard or quiz question.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.height = 280});
  final double height;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: SkeletonBox(width: double.infinity, height: height, borderRadius: 20),
    );
  }
}

/// Skeleton for a chat screen: alternating left/right message bubbles.
class SkeletonChat extends StatelessWidget {
  const SkeletonChat({super.key, this.itemCount = 4});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.containerMargin,
          vertical: AppSpacing.md,
        ),
        child: Column(
          children: List.generate(itemCount, (i) {
            final fromUser = i.isOdd;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Align(
                alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
                child: SkeletonBox(
                  width: fromUser ? 160 : 220,
                  height: 44,
                  borderRadius: 16,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}