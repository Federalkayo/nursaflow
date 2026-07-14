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
import 'models/chat_message.dart';

const _suggestedPrompts = [
  'Give me a mnemonic',
  'Create a summary',
  'Explain like I\'m new to nursing',
  'Quiz me on this',
];

class AiTutorScreen extends ConsumerStatefulWidget {
  const AiTutorScreen({super.key, this.documentId});
  final String? documentId;

  @override
  ConsumerState<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends ConsumerState<AiTutorScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _isThinking = false;

  Future<void> _send([String? preset]) async {
    final text = preset ?? _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() {
      _isThinking = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final chatCollection = widget.documentId != null
        ? docRef.collection('documents').doc(widget.documentId!).collection('messages')
        : docRef.collection('general_messages');

    try {
      // 1. Save user message to Firestore
      await chatCollection.add({
        'sender': TutorSender.user.name,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _scrollToBottom();

      // 2. Generate simulated response after a small delay
      Future.delayed(const Duration(milliseconds: 1000), () async {
        final responseText = _mockResponseFor(text);
        await chatCollection.add({
          'sender': TutorSender.ai.name,
          'text': responseText,
          'timestamp': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          setState(() {
            _isThinking = false;
          });
          _scrollToBottom();
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isThinking = false;
        });
      }
    }
  }

  String _mockResponseFor(String prompt) {
    final p = prompt.toLowerCase();
    if (p.contains('mnemonic')) {
      return 'Sure — for cranial nerves, try: "Oh Oh Oh To Touch And Feel Very Green Vegetables AH!" (Olfactory, Optic, Oculomotor, Trochlear, Trigeminal, Abducens, Facial, Vestibulocochlear, Glossopharyngeal, Vagus, Accessory, Hypoglossal).';
    } else if (p.contains('summary')) {
      return 'Here is a high-level summary of Renal Function: \n- Glomerular Filtration: Filters waste and excess water from blood.\n- Tubular Reabsorption: Returns essential substances (water, glucose, electrolytes) to blood.\n- Tubular Secretion: Secretes ions and waste products into filtrate.';
    } else if (p.contains('quiz')) {
      return 'Quick Quiz: Which hormone regulates water reabsorption in the collecting ducts? (A) Aldosterone, (B) ADH, (C) Renin. Reply with your choice!';
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
    final messagesAsync = ref.watch(tutorMessagesProvider(widget.documentId));

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
              child: messagesAsync.when(
                data: (firestoreMessages) {
                  final messages = firestoreMessages.isNotEmpty
                      ? firestoreMessages
                      : [
                          TutorChatMessage(
                            id: 'welcome',
                            sender: TutorSender.ai,
                            text: widget.documentId != null
                                ? "I've analyzed your notes. How can I help you today?"
                                : 'Hi! Ask me anything about your nursing coursework — I\'ll use your uploaded notes as context whenever relevant.',
                            timestamp: DateTime.now(),
                          )
                        ];

                  // Trigger scroll after build
                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.containerMargin, vertical: AppSpacing.md),
                    itemCount: messages.length + (_isThinking ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == messages.length) return const _TypingBubble();
                      return _MessageBubble(message: messages[i]);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error loading chat history: $err')),
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
  final TutorChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isAi = message.sender == TutorSender.ai;
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
