import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/responsive_page.dart';

class _OnboardPage {
  const _OnboardPage({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;
}

const _pages = [
  _OnboardPage(
    icon: Symbols.upload_file,
    title: 'Master Nursing with AI.',
    body: 'Upload notes to get summaries, flashcards, and quizzes in minutes.',
  ),
  _OnboardPage(
    icon: Symbols.psychology,
    title: 'Your 24/7 Study Partner.',
    body: 'Ask questions about your lecture material and get answers grounded in your own notes.',
  ),
  _OnboardPage(
    icon: Symbols.calendar_month,
    title: 'Stay On Top of Exams.',
    body: 'A simple study plan built around your courses and exam dates keeps you consistent.',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  void _next() {
    if (_index == _pages.length - 1) {
      context.go('/auth');
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ResponsivePage(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => context.go('/auth'),
                    child: const Text('Skip'),
                  ),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final page = _pages[i];
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(page.icon, size: 96, color: AppColors.primary),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            page.title,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.headlineLgMobile(),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            page.body,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMd(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index
                            ? AppColors.primary
                            : AppColors.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: _index == _pages.length - 1 ? 'Get Started' : 'Continue',
                icon: Symbols.arrow_forward,
                onPressed: _next,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
