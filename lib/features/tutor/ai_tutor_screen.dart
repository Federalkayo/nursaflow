import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/mermaid_view.dart';
import '../../core/widgets/responsive_page.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/zoomable_image_view.dart';
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

  // Text-to-speech: one shared FlutterTts instance for the whole screen.
  // Tracks which message (by id) is currently being read aloud so the
  // speaker icon on that bubble can flip to a "stop" state, and so tapping
  // a different message's speaker button stops the previous one first
  // rather than overlapping audio.
  final FlutterTts _tts = FlutterTts();
  String? _speakingMessageId;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speakingMessageId = null);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _speakingMessageId = null);
    });
    _tts.setErrorHandler((msg) {
      if (mounted) setState(() => _speakingMessageId = null);
    });
  }

  Future<void> _toggleSpeak(TutorChatMessage message, String textToSpeak) async {
    if (_speakingMessageId == message.id) {
      await _tts.stop();
      setState(() => _speakingMessageId = null);
      return;
    }
    // Stop whatever's currently playing before starting the new one —
    // flutter_tts queues by default rather than interrupting, which would
    // otherwise let two replies overlap if tapped in quick succession.
    await _tts.stop();
    setState(() => _speakingMessageId = message.id);
    await _tts.speak(textToSpeak);
  }

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

      // 2. Call the askTutor Cloud Function. It reads document context +
      // recent chat history, calls Gemini, and writes the AI's reply
      // directly to Firestore — our stream listener (tutorMessagesProvider)
      // picks up the new message automatically, so we don't need to write
      // anything here on success.
      try {
        await FirebaseFunctions.instance.httpsCallable('askTutor').call({
          'documentId': widget.documentId,
          'message': text,
        });
      } catch (e) {
        final isLimitReached =
            e is FirebaseFunctionsException && e.code == 'resource-exhausted';

        // If the function call itself fails (network issue, cold start
        // timeout, etc.), surface a friendly message directly rather than
        // leaving the student staring at a stuck typing indicator forever.
        // The free-plan limit is a distinct, expected case — worth a
        // specific message + an actual way to fix it, not the generic
        // "try again" text, which would just fail identically on retry.
        await chatCollection.add({
          'sender': TutorSender.ai.name,
          'text': isLimitReached
              ? (e as FirebaseFunctionsException).message ??
                  "You've reached the free plan's AI Tutor limit for this month."
              : "Sorry, I'm having trouble connecting right now. Please try again.",
          'timestamp': FieldValue.serverTimestamp(),
        });

        if (isLimitReached && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('AI Tutor limit reached for this month'),
              action: SnackBarAction(
                label: 'Upgrade',
                onPressed: () => context.push('/subscription'),
              ),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isThinking = false;
          });
          _scrollToBottom();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isThinking = false;
        });
      }
    }
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
    _tts.stop();
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
                      final msg = messages[i];
                      return _MessageBubble(
                        message: msg,
                        isSpeaking: _speakingMessageId == msg.id,
                        onToggleSpeak: (textToSpeak) => _toggleSpeak(msg, textToSpeak),
                      );
                    },
                  );
                },
                loading: () => const SkeletonChat(),
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

/// Resolves a Storage path to a download URL client-side (respecting
/// Storage security rules) and displays it, with a loading skeleton and
/// silent fail-through if the image can't be loaded. Tappable — opens the
/// shared ZoomableImageView for pinch-to-zoom, same as the document
/// illustration on the summary screen.
class _ChatImage extends StatelessWidget {
  const _ChatImage({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: FirebaseStorage.instance.ref(path).getDownloadURL(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: 220,
            height: 220,
            color: AppColors.surfaceContainerLow,
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          );
        }
        if (!snapshot.hasData) return const SizedBox.shrink();

        final url = snapshot.data!;
        return GestureDetector(
          onTap: () => ZoomableImageView.open(context, url),
          child: Stack(
            children: [
              Image.network(
                url,
                width: 220,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => const SizedBox.shrink(),
              ),
              ExpandButton(onTap: () => ZoomableImageView.open(context, url)),
            ],
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    this.isSpeaking = false,
    this.onToggleSpeak,
  });
  final TutorChatMessage message;
  final bool isSpeaking;
  final ValueChanged<String>? onToggleSpeak;

  // Extracts a ```mermaid ... ``` fenced block from the message text, if
  // present, returning (diagramSyntax, remainingText). The AI Tutor is
  // instructed to only include this fence for process/mechanism questions
  // (see buildTutorPrompt in the Cloud Function).
  ({String? diagram, String text}) _parseMermaid(String raw) {
    final match = RegExp(r'```mermaid\s*([\s\S]*?)```').firstMatch(raw);
    if (match == null) return (diagram: null, text: raw);
    final diagram = match.group(1)?.trim();
    final remaining = raw.replaceRange(match.start, match.end, '').trim();
    return (diagram: diagram, text: remaining);
  }

  @override
  Widget build(BuildContext context) {
    final isAi = message.sender == TutorSender.ai;
    final parsed = isAi ? _parseMermaid(message.text) : (diagram: null, text: message.text);
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (parsed.diagram != null && parsed.diagram!.isNotEmpty) ...[
                    MermaidView(diagram: parsed.diagram!, height: 300),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  if (message.imagePath != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _ChatImage(path: message.imagePath!),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  if (parsed.text.isNotEmpty)
                    Text(parsed.text, style: AppTextStyles.bodyMd(color: AppColors.onSurface)),
                  // Read-aloud button — AI messages only, and only when
                  // there's actual text to speak (a pure diagram/image
                  // message has nothing worth narrating).
                  if (isAi && parsed.text.isNotEmpty && onToggleSpeak != null) ...[
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => onToggleSpeak!(parsed.text),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSpeaking ? Symbols.stop_circle : Symbols.volume_up,
                              size: 16,
                              color: AppColors.tertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isSpeaking ? 'Stop' : 'Listen',
                              style: AppTextStyles.bodySm(color: AppColors.tertiary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
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