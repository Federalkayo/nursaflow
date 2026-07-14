import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// The 🔥 N Day Streak chip that appears in the header of nearly every
/// screen in the Stitch export.
class StreakChip extends StatelessWidget {
  const StreakChip({super.key, required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text('$days Day Streak',
              style: AppTextStyles.labelSm(color: AppColors.onSecondaryContainer)),
        ],
      ),
    );
  }
}
