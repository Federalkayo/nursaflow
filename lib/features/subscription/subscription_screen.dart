import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/responsive_page.dart';

enum BillingCycle { monthly, annual }

/// Pricing tiers. Kept intentionally simple for MVP — two tiers only.
/// Naira pricing assumes a Nigerian-first market per Caleb's product notes;
/// swap PlanCatalog values or wire to remote config for other currencies.
class PlanCatalog {
  static const freeFeatures = [
    '3 document uploads / month',
    'AI summaries & flashcards',
    '5 AI Tutor messages / day',
    '1 active course in Planner',
  ];

  static const premiumFeatures = [
    'Unlimited document uploads',
    'Unlimited flashcards & quizzes',
    'Unlimited AI Tutor conversations',
    'Unlimited courses & exam planning',
    'Priority AI processing (faster results)',
    'Offline flashcard review',
  ];

  static const monthlyPrice = 2500; // NGN
  static const annualPrice = 20000; // NGN (≈ 2 months free vs monthly)
}

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  BillingCycle _cycle = BillingCycle.annual;
  bool _isProcessing = false;

  Future<void> _upgrade() async {
    setState(() => _isProcessing = true);
    // TODO: call the `paystack-initialize` Edge/Cloud Function with the
    // selected plan + billing cycle, then launch the returned authorization_url
    // (e.g. via url_launcher or an in-app WebView). On successful webhook
    // confirmation, the backend flips `users/{uid}.subscription.status` to
    // 'active' and the app should react to that via a Firestore stream.
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _isProcessing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Paystack checkout would open here.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final price = _cycle == BillingCycle.monthly
        ? PlanCatalog.monthlyPrice
        : (PlanCatalog.annualPrice / 12).round();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Symbols.close), onPressed: () => context.pop()),
        title: const Text('NursaFlow Premium'),
      ),
      body: SafeArea(
        child: ResponsivePage(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.secondaryContainer,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Symbols.workspace_premium,
                            color: AppColors.onSecondaryContainer, size: 32),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Study without limits', style: AppTextStyles.headlineLg(), textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      Text(
                        'Unlock unlimited uploads, quizzes, and AI tutoring for exam season.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMd(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Billing toggle
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CycleTab(
                          label: 'Monthly',
                          selected: _cycle == BillingCycle.monthly,
                          onTap: () => setState(() => _cycle = BillingCycle.monthly),
                        ),
                        _CycleTab(
                          label: 'Annual · Save 33%',
                          selected: _cycle == BillingCycle.annual,
                          onTap: () => setState(() => _cycle = BillingCycle.annual),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 640;
                    const free = _PlanCard(
                      title: 'Free',
                      price: '₦0',
                      period: 'forever',
                      features: PlanCatalog.freeFeatures,
                      isPrimary: false,
                      ctaLabel: 'Current Plan',
                      onTap: null,
                    );
                    final premium = _PlanCard(
                      title: 'Premium',
                      price: '₦${_formatNaira(price)}',
                      period: '/month${_cycle == BillingCycle.annual ? ', billed yearly' : ''}',
                      features: PlanCatalog.premiumFeatures,
                      isPrimary: true,
                      ctaLabel: 'Upgrade to Premium',
                      isLoading: _isProcessing,
                      onTap: _upgrade,
                      badge: _cycle == BillingCycle.annual ? 'BEST VALUE' : null,
                    );

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(child: free),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: premium),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        premium,
                        const SizedBox(height: AppSpacing.md),
                        free,
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                Text('Frequently Asked', style: AppTextStyles.headlineMd()),
                const SizedBox(height: AppSpacing.sm),
                const _FaqTile(
                  question: 'Can I cancel anytime?',
                  answer:
                      "Yes. You'll keep Premium access until the end of your current billing period.",
                ),
                const _FaqTile(
                  question: 'What payment methods are supported?',
                  answer:
                      'Card, bank transfer, and USSD via Paystack — all major Nigerian banks are supported.',
                ),
                const _FaqTile(
                  question: 'Do unused uploads roll over on the Free plan?',
                  answer: 'No, the 3 monthly uploads reset at the start of each calendar month.',
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatNaira(int amount) {
    final s = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }
}

class _CycleTab extends StatelessWidget {
  const _CycleTab({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSm(
            color: selected ? Colors.white : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    required this.features,
    required this.isPrimary,
    required this.ctaLabel,
    required this.onTap,
    this.isLoading = false,
    this.badge,
  });

  final String title;
  final String price;
  final String period;
  final List<String> features;
  final bool isPrimary;
  final String ctaLabel;
  final VoidCallback? onTap;
  final bool isLoading;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: isPrimary ? AppColors.primary : AppColors.surfaceContainerLowest,
      border: isPrimary ? null : Border.all(color: AppColors.outlineVariant),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: AppTextStyles.headlineMd(
                      color: isPrimary ? Colors.white : AppColors.onSurface)),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.coral,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(badge!,
                      style: AppTextStyles.labelSm(color: Colors.white)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(price,
                  style: AppTextStyles.display(
                      color: isPrimary ? Colors.white : AppColors.onSurface)),
              const SizedBox(width: 4),
              Text(period,
                  style: AppTextStyles.bodySm(
                      color: isPrimary ? Colors.white70 : AppColors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Symbols.check_circle,
                      size: 18,
                      color: isPrimary ? Colors.white : AppColors.tertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f,
                      style: AppTextStyles.bodyMd(
                          color: isPrimary ? Colors.white.withValues(alpha: 0.9) : AppColors.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          if (isPrimary)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(ctaLabel),
              ),
            )
          else
            SecondaryButton(label: ctaLabel, onPressed: onTap),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});
  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(question, style: AppTextStyles.labelLg()),
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
        expandedAlignment: Alignment.centerLeft,
        children: [Text(answer, style: AppTextStyles.bodyMd())],
      ),
    );
  }
}
