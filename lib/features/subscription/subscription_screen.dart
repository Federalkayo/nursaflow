import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:webview_flutter/webview_flutter.dart';
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

  static const monthlyPrice = 2000; // NGN
  static const annualPrice = 16000; // NGN (33% off vs paying monthly × 12)
}

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  BillingCycle _cycle = BillingCycle.monthly;
  bool _isProcessing = false;

  Future<void> _upgrade() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isProcessing = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('initializePaystackTransaction');
      final result = await callable.call<Map<String, dynamic>>({
        'cycle': _cycle == BillingCycle.monthly ? 'monthly' : 'annual',
      });
      final authorizationUrl = result.data['authorizationUrl'] as String?;
      if (authorizationUrl == null) {
        throw Exception('No checkout URL returned');
      }

      if (!mounted) return;
      setState(() => _isProcessing = false);

      final success = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => _PaystackCheckoutPage(url: authorizationUrl, uid: uid),
        ),
      );

      if (!mounted || success != true) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment successful — Premium is now active!')),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Checkout failed. Please try again.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checkout failed. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
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
                    final uid = FirebaseAuth.instance.currentUser?.uid;

                    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: uid == null
                          ? null
                          : FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                      builder: (context, snapshot) {
                        final sub = snapshot.data?.data()?['subscription'] as Map<String, dynamic>?;
                        final renewsAt = (sub?['renewsAt'] as Timestamp?)?.toDate();
                        final isActive = sub?['status'] == 'active' &&
                            renewsAt != null &&
                            renewsAt.isAfter(DateTime.now());
                        final activePlan = sub?['plan'] as String?; // 'monthly' | 'annual'

                        final free = _PlanCard(
                          title: 'Free',
                          price: '₦0',
                          period: 'forever',
                          features: PlanCatalog.freeFeatures,
                          isPrimary: false,
                          ctaLabel: isActive ? 'Included in Premium' : 'Current Plan',
                          onTap: null,
                        );
                        final premium = _PlanCard(
                          title: 'Premium',
                          price: '₦${_formatNaira(price)}',
                          period:
                              '/month${_cycle == BillingCycle.annual ? ', billed yearly' : ''}',
                          subCaption: _cycle == BillingCycle.annual
                              ? '₦${_formatNaira(PlanCatalog.annualPrice)} charged once a year'
                              : null,
                          features: PlanCatalog.premiumFeatures,
                          isPrimary: true,
                          ctaLabel: isActive
                              ? (activePlan == (_cycle == BillingCycle.monthly ? 'monthly' : 'annual')
                                  ? 'Current Plan'
                                  : 'Switch to this plan')
                              : 'Upgrade to Premium',
                          isLoading: _isProcessing,
                          onTap: isActive &&
                                  activePlan == (_cycle == BillingCycle.monthly ? 'monthly' : 'annual')
                              ? null
                              : _upgrade,
                          badge: isActive
                              ? 'ACTIVE'
                              : (_cycle == BillingCycle.annual ? 'BEST VALUE' : null),
                        );

                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: free),
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
    this.subCaption,
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
  // Shown directly under the price — used to spell out the total amount
  // actually charged (e.g. "₦16,000 billed once a year") next to the
  // per-month figure above, so the per-month number can't be mistaken for
  // what gets charged today.
  final String? subCaption;

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
          if (subCaption != null) ...[
            const SizedBox(height: 2),
            Text(subCaption!,
                style: AppTextStyles.bodySm(
                        color: isPrimary ? Colors.white70 : AppColors.onSurfaceVariant)
                    .copyWith(fontWeight: FontWeight.bold)),
          ],
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

/// Hosts the Paystack checkout page in a WebView and watches Firestore for
/// the webhook (functions/src/paystackWebhook.js) to flip
/// `subscription.status` to 'active' — rather than trying to parse
/// Paystack's post-payment redirect URL, which would need a hosted
/// callback page this app doesn't have. Pops with `true` on success so the
/// caller can show a confirmation snackbar.
class _PaystackCheckoutPage extends StatefulWidget {
  const _PaystackCheckoutPage({required this.url, required this.uid});
  final String url;
  final String uid;

  @override
  State<_PaystackCheckoutPage> createState() => _PaystackCheckoutPageState();
}

class _PaystackCheckoutPageState extends State<_PaystackCheckoutPage> {
  late final WebViewController _controller;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url));

    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .snapshots()
        .listen((doc) {
      final status = doc.data()?['subscription']?['status'];
      if (status == 'active' && !_closed && mounted) {
        _closed = true;
        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete payment'),
        leading: IconButton(
          icon: const Icon(Symbols.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}