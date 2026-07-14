import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/responsive_page.dart';
import '../home/models/flashcard.dart';

class FlashcardsScreen extends ConsumerStatefulWidget {
  const FlashcardsScreen({super.key, required this.documentId});
  final String documentId;

  @override
  ConsumerState<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends ConsumerState<FlashcardsScreen>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  bool _showAnswer = false;
  late final AnimationController _flipController;

  @override
  void initState() {
    super.initState();
    _flipController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _flip() {
    if (_showAnswer) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() => _showAnswer = !_showAnswer);
  }

  void _next(List<StudyFlashcard> cards, {bool known = true}) {
    if (_index >= cards.length - 1) {
      _updateProgress(1.0);
      context.pop();
      return;
    }
    final prog = (_index + 1) / cards.length;
    _updateProgress(prog);

    setState(() {
      _index++;
      _showAnswer = false;
    });
    _flipController.value = 0;
  }

  Future<void> _updateProgress(double progress) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('documents')
          .doc(widget.documentId)
          .update({'progress': progress});
    } catch (_) {}
  }

  void _previous() {
    if (_index == 0) return;
    setState(() {
      _index--;
      _showAnswer = false;
    });
    _flipController.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    final flashcardsAsync = ref.watch(documentFlashcardsProvider(widget.documentId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.close),
          onPressed: () => context.pop(),
        ),
        title: const Text('NursaFlow Study'),
      ),
      body: SafeArea(
        child: ResponsivePage(
          child: flashcardsAsync.when(
            data: (firestoreCards) {
              final cards = firestoreCards.isNotEmpty
                  ? firestoreCards
                  : const [
                      StudyFlashcard(
                        id: 'mock-f1',
                        question: 'What is the primary sign of hypovolemia?',
                        answer: 'Tachycardia & Hypotension',
                        explanation: 'A rapid pulse is typically the earliest sign as the heart compensates for low fluid volume.',
                      ),
                      StudyFlashcard(
                        id: 'mock-f2',
                        question: 'What are the stages of wound healing?',
                        answer: 'Hemostasis, Inflammation, Proliferation, and Maturation.',
                        explanation: 'Each stage overlaps but follows this general sequence in normal healing.',
                      ),
                      StudyFlashcard(
                        id: 'mock-f3',
                        question: 'Normal adult respiratory rate range?',
                        answer: '12–20 breaths per minute',
                        explanation: 'Rates outside this range should prompt further respiratory assessment.',
                      ),
                    ];

              if (_index >= cards.length) {
                _index = cards.length - 1;
              }
              final card = cards[_index];

              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Card ${_index + 1} of ${cards.length}',
                            style: AppTextStyles.labelLg()),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Anatomy & Physiology',
                            style: AppTextStyles.bodySm(),
                            textAlign: TextAlign.end,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_index + 1) / cards.length,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Swipe right if you know it, left to review again.',
                      style: AppTextStyles.bodySm(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    Expanded(
                      child: GestureDetector(
                        onHorizontalDragEnd: (details) {
                          final v = details.primaryVelocity ?? 0;
                          if (v > 200) {
                            _next(cards, known: true);
                          } else if (v < -200) {
                            _next(cards, known: false);
                          }
                        },
                        onTap: _flip,
                        child: AnimatedBuilder(
                          animation: _flipController,
                          builder: (context, child) {
                            final angle = _flipController.value * math.pi;
                            final isBack = angle > math.pi / 2;
                            return Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.001)
                                ..rotateY(angle),
                              child: isBack
                                  ? Transform(
                                      alignment: Alignment.center,
                                      transform: Matrix4.identity()..rotateY(math.pi),
                                      child: _CardFace(
                                        label: 'ANSWER',
                                        labelColor: AppColors.tertiary,
                                        title: card.answer,
                                        subtitle: card.explanation,
                                        icon: Symbols.check_circle,
                                      ),
                                    )
                                  : _CardFace(
                                      label: 'QUESTION',
                                      labelColor: AppColors.primary,
                                      title: card.question,
                                      icon: Symbols.help,
                                    ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    if (_showAnswer)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _next(cards, known: false),
                              icon: const Icon(Symbols.replay, size: 18),
                              label: const Text('Review Again'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _next(cards, known: true),
                              icon: const Icon(Symbols.check, size: 18),
                              label: const Text('Got It'),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: AppSpacing.md),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _NavButton(icon: Symbols.chevron_left, label: 'Previous', onTap: _previous),
                        ElevatedButton.icon(
                          onPressed: _flip,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          icon: const Icon(Symbols.flip_camera_android, size: 18),
                          label: const Text('Flip'),
                        ),
                        _NavButton(
                            icon: Symbols.chevron_right, label: 'Next', onTap: () => _next(cards)),
                      ],
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.label,
    required this.labelColor,
    required this.title,
    required this.icon,
    this.subtitle,
  });

  final String label;
  final Color labelColor;
  final String title;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: labelColor, size: 32),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.headlineMd(),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(subtitle!, textAlign: TextAlign.center, style: AppTextStyles.bodyMd()),
          ],
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: labelColor),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(label, style: AppTextStyles.labelSm(color: labelColor)),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Icon(icon, color: AppColors.onSurfaceVariant),
            Text(label, style: AppTextStyles.bodySm()),
          ],
        ),
      ),
    );
  }
}
