import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/responsive_page.dart';

class _QuizQuestion {
  const _QuizQuestion({
    required this.tag,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
  final String tag;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
}

// TODO: replace with AI-generated questions for this document via Cloud Function
const _questions = [
  _QuizQuestion(
    tag: 'ETHICS & LAW',
    question:
        "A nurse is caring for a patient who refuses a life-saving blood transfusion due to religious beliefs. What is the most appropriate ethical action?",
    options: [
      'Administer the transfusion anyway, as preserving life is the primary duty of the healthcare team.',
      "Respect the patient's autonomy and document the refusal after ensuring they are fully informed of the risks.",
      "Ask the family to override the patient's decision if the patient is unable to justify their choice rationally.",
      'Seek a court order immediately to mandate the transfusion under the principle of non-maleficence.',
    ],
    correctIndex: 1,
    explanation:
        "Respecting patient autonomy is a core ethical principle — competent adults have the right to refuse treatment, even life-saving treatment, once fully informed.",
  ),
  _QuizQuestion(
    tag: 'PHARMACOLOGY',
    question: 'Which vital sign should a nurse check first before administering digoxin?',
    options: ['Blood pressure', 'Apical heart rate', 'Respiratory rate', 'Temperature'],
    correctIndex: 1,
    explanation:
        'Digoxin can cause bradycardia; apical pulse should be checked for a full minute before administration and withheld if under 60 bpm.',
  ),
];

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.documentId});
  final String documentId;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _index = 0;
  int? _selected;
  bool _submitted = false;
  int _score = 0;
  bool _finished = false;

  void _submit() {
    if (_selected == null) return;
    setState(() {
      _submitted = true;
      if (_selected == _questions[_index].correctIndex) _score++;
    });
  }

  void _next() {
    if (_index == _questions.length - 1) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _index++;
      _selected = null;
      _submitted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return _ResultsView(score: _score, total: _questions.length);

    final q = _questions[_index];
    final progress = (_index + 1) / _questions.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Practice Quiz')),
      body: SafeArea(
        child: ResponsivePage(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Question ${_index + 1} of ${_questions.length}',
                        style: AppTextStyles.labelLg()),
                    Text('${(progress * 100).round()}% Completed',
                        style: AppTextStyles.labelLg(color: AppColors.secondary)),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: progress, minHeight: 6),
                ),
                const SizedBox(height: AppSpacing.md),

                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.primary),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(q.tag,
                            style: AppTextStyles.labelSm(color: AppColors.primary)),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(q.question, style: AppTextStyles.headlineMd()),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                for (int i = 0; i < q.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _OptionTile(
                      letter: String.fromCharCode(65 + i),
                      text: q.options[i],
                      selected: _selected == i,
                      submitted: _submitted,
                      isCorrect: i == q.correctIndex,
                      onTap: _submitted ? null : () => setState(() => _selected = i),
                    ),
                  ),

                if (_submitted) ...[
                  AppCard(
                    color: (_selected == q.correctIndex
                            ? AppColors.tertiary
                            : AppColors.error)
                        .withValues(alpha: 0.08),
                    elevated: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _selected == q.correctIndex
                                  ? Symbols.check_circle
                                  : Symbols.cancel,
                              color: _selected == q.correctIndex
                                  ? AppColors.tertiary
                                  : AppColors.error,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _selected == q.correctIndex ? 'Correct!' : 'Not quite',
                              style: AppTextStyles.labelLg(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(q.explanation, style: AppTextStyles.bodyMd()),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                PrimaryButton(
                  label: _submitted
                      ? (_index == _questions.length - 1 ? 'See Results' : 'Next Question')
                      : 'Submit Answer',
                  icon: _submitted ? Symbols.arrow_forward : null,
                  onPressed: _submitted ? _next : (_selected == null ? null : _submit),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.letter,
    required this.text,
    required this.selected,
    required this.submitted,
    required this.isCorrect,
    required this.onTap,
  });

  final String letter;
  final String text;
  final bool selected;
  final bool submitted;
  final bool isCorrect;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Color borderColor = AppColors.outlineVariant;
    Color bg = AppColors.surfaceContainerLowest;
    if (submitted) {
      if (isCorrect) {
        borderColor = AppColors.tertiary;
        bg = AppColors.tertiary.withValues(alpha: 0.06);
      } else if (selected) {
        borderColor = AppColors.error;
        bg = AppColors.error.withValues(alpha: 0.06);
      }
    } else if (selected) {
      borderColor = AppColors.primary;
      bg = AppColors.primary.withValues(alpha: 0.05);
    }

    return AppCard(
      onTap: onTap,
      elevated: false,
      color: bg,
      border: Border.all(color: borderColor, width: selected || (submitted && isCorrect) ? 2 : 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: borderColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(letter, style: AppTextStyles.labelLg(color: borderColor)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTextStyles.bodyMd(color: AppColors.onSurface))),
        ],
      ),
    );
  }
}

class _ResultsView extends StatelessWidget {
  const _ResultsView({required this.score, required this.total});
  final int score;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = (score / total * 100).round();
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Results')),
      body: SafeArea(
        child: ResponsivePage(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.08),
                    ),
                    child: Text('$pct%', style: AppTextStyles.display(color: AppColors.primary)),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('You scored $score out of $total', style: AppTextStyles.headlineMd()),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    pct >= 80
                        ? "Excellent work — you're exam ready on this topic."
                        : 'Review the explanations below and try again to improve mastery.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMd(),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(label: 'Back to Document', onPressed: () => context.pop()),
                  const SizedBox(height: AppSpacing.sm),
                  SecondaryButton(label: 'Retry Quiz', onPressed: () => context.pop()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
