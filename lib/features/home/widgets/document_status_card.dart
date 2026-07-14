import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../models/document.dart';

class DocumentStatusCard extends StatelessWidget {
  const DocumentStatusCard({super.key, required this.document});
  final StudyDocument document;

  @override
  Widget build(BuildContext context) {
    final isReady = document.status == DocumentStatus.ready;

    return AppCard(
      onTap: isReady ? () => context.push('/document/${document.id}/summary') : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Symbols.description,
                    color: AppColors.primary, size: 18),
              ),
              const Spacer(),
              _StatusPill(isReady: isReady),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            document.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelLg(),
          ),
          const SizedBox(height: 2),
          Text(document.course, style: AppTextStyles.bodySm(), maxLines: 1, overflow: TextOverflow.ellipsis),
          const Spacer(),
          if (isReady) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: document.progress,
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${(document.progress * 100).round()}% mastered',
                    style: AppTextStyles.labelSm(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Row(
                  children: [
                    _QuickIcon(
                      icon: Symbols.style,
                      onTap: () => context.push('/document/${document.id}/flashcards'),
                    ),
                    _QuickIcon(
                      icon: Symbols.quiz,
                      onTap: () => context.push('/document/${document.id}/quiz'),
                    ),
                  ],
                ),
              ],
            ),
          ] else
            Text('Analyzing document…', style: AppTextStyles.bodySm(color: AppColors.secondary)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isReady});
  final bool isReady;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isReady
            ? AppColors.tertiary.withValues(alpha: 0.10)
            : AppColors.secondary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isReady ? 'Ready' : 'Processing',
        style: AppTextStyles.labelSm(
          color: isReady ? AppColors.tertiary : AppColors.secondary,
        ),
      ),
    );
  }
}

class _QuickIcon extends StatelessWidget {
  const _QuickIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
    );
  }
}
