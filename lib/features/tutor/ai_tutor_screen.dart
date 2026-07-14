import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/responsive_page.dart';

enum _Sender { ai, user }

class _ChatMessage {
  _ChatMessage({required this.sender, required this.text, required this.time});
  final _Sender sender;
  final String text;
  final DateTime time;
}

const _suggestedPrompts = [
  'Give me a mnemonic',
  'Create a summary',
  'Explain like I\'m new to nursing',
  'Quiz me on this',
];

class AiTutorScreen extends StatefulWidget {
  const AiTutorScreen({super.key, this.documentId});
  final String? documentId;

  @override
  State<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends State<AiTutorScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _isThinking = false;

  late final List<_ChatMessage> _messages = [
    _ChatMessage(
      sender: _Sender.ai,
      text: widget.documentId != null
          ? "I've analyzed your notes on Renal Health. How can I help you today?"
          : 'Hi! Ask me anything about your nursing coursework — I\'ll use your uploaded notes as context whenever relevant.',
      time: DateTime.now(),
    ),
  ];

  void _send([String? preset]) {
    final text = preset ?? _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(sender: _Sender.user, text: text, time: DateTime.now()));
      _isThinking = true;
      _controller.clear();
    });
    _scrollToBottom();

    // TODO: replace with a call to the `askTutor` Cloud Function, which
    // forwards to Gemini via Firebase AI Logic with the document's extracted
    // text (and prior chat turns) as context.
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _isThinking = false;
        _messages.add(_ChatMessage(
          sender: _Sender.ai,
          text: _mockResponseFor(text),
          time: DateTime.now(),
        ));
      });
      _scrollToBottom();
    });
  }

  String _mockResponseFor(String prompt) {
    if (prompt.toLowerCase().contains('mnemonic')) {
      return 'Sure — for cranial nerves, try: "Oh Oh Oh To Touch And Feel Very Green Vegetables AH!" (Olfactory, Optic, Oculomotor, Trochlear, Trigeminal, Abducens, Facial, Vestibulocochlear, Glossopharyngeal, Vagus, Accessory, Hypoglossal).';
    }
    return "Glomerular filtration rate (GFR) is essentially how fast your kidneys filter blood. Think of it as a speedometer for kidney function — a normal GFR sits around 90-120 mL/min. When it drops below 60 for 3+ months, that's a signal of chronic kidney disease.";
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Symbols.arrow_back), onPressed: () => context.pop()),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI Tutor'),
            Text('Your 24/7 Clinical Knowledge Partner',
                style: AppTextStyles.bodySm(color: AppColors.onSurfaceVariant)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.containerMargin, vertical: AppSpacing.md),
                itemCount: _messages.length + (_isThinking ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == _messages.length) return const _TypingBubble();
                  return _MessageBubble(message: _messages[i]);
                },
              ),
            ),
            if (widget.documentId != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    avatar: const Icon(Symbols.description, size: 16),
                    label: Text('Context: ${widget.documentId}',
                        style: AppTextStyles.bodySm()),
                  ),
                ),
              ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin),
                scrollDirection: Axis.horizontal,
                itemCount: _suggestedPrompts.length,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
                itemBuilder: (context, i) => OutlinedButton(
                  onPressed: () => _send(_suggestedPrompts[i]),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Text(_suggestedPrompts[i], style: AppTextStyles.bodySm(color: AppColors.primary)),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ResponsivePage(
              padTop: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask your tutor…',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filled(
                    onPressed: () => _send(),
                    icon: const Icon(Symbols.send),
                    style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isAi = message.sender == _Sender.ai;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isAi) const _Avatar(isAi: true),
          if (isAi) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: isAi
                    ? AppColors.tertiary.withValues(alpha: 0.12)
                    : AppColors.secondaryContainer,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isAi ? 4 : 16),
                  bottomRight: Radius.circular(isAi ? 16 : 4),
                ),
              ),
              child: Text(message.text, style: AppTextStyles.bodyMd(color: AppColors.onSurface)),
            ),
          ),
          if (!isAi) const SizedBox(width: 8),
          if (!isAi) const _Avatar(isAi: false),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.isAi});
  final bool isAi;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isAi ? AppColors.tertiary : AppColors.secondary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(isAi ? Symbols.bolt : Symbols.person, color: Colors.white, size: 16),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          const _Avatar(isAi: true),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('•••'),
          ),
        ],
      ),
    );
  }
}
