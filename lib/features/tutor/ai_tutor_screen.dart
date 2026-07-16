import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/mermaid_view.dart';
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
        // If the function call itself fails (network issue, cold start
        // timeout, etc.), surface a friendly message directly rather than
        // leaving the student staring at a stuck typing indicator forever.
        await chatCollection.add({
          'sender': TutorSender.ai.name,
          'text': "Sorry, I'm having trouble connecting right now. Please try again.",
          'timestamp': FieldValue.serverTimestamp(),
        });
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

/// Resolves a Storage path to a download URL client-side (respecting
/// Storage security rules) and displays it, with a loading skeleton and
/// silent fail-through if the image can't be loaded.
///
/// Tappable — opens a fullscreen pinch-to-zoom view (InteractiveViewer),
/// mirroring the expand affordance already used on Mermaid diagrams, but
/// with pinch/pan gestures instead of a static larger view since that's
/// the natural interaction for a photo/illustration.
class _ChatImage extends StatelessWidget {
  const _ChatImage({required this.path});
  final String path;

  void _openFullscreen(BuildContext context, String url) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, _, __) => _ImageFullscreenView(imageUrl: url),
      ),
    );
  }

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
          onTap: () => _openFullscreen(context, url),
          child: Stack(
            children: [
              Image.network(
                url,
                width: 220,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => const SizedBox.shrink(),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.open_in_full, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Fullscreen pinch-to-zoom view for a chat image. Pinch/drag to zoom and
/// pan, double-tap to reset — standard InteractiveViewer gesture set, same
/// pattern used by most chat apps for image previews.
class _ImageFullscreenView extends StatefulWidget {
  const _ImageFullscreenView({required this.imageUrl});
  final String imageUrl;

  @override
  State<_ImageFullscreenView> createState() => _ImageFullscreenViewState();
}

class _ImageFullscreenViewState extends State<_ImageFullscreenView> {
  final TransformationController _transformController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  void _handleDoubleTap() {
    if (_transformController.value != Matrix4.identity()) {
      _transformController.value = Matrix4.identity();
      return;
    }
    final position = _doubleTapDetails?.localPosition ?? Offset.zero;
    _transformController.value = Matrix4.identity()
      ..translate(-position.dx * 2, -position.dy * 2)
      ..scale(3.0);
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Expanded(
            child: GestureDetector(
              onDoubleTapDown: (details) => _doubleTapDetails = details,
              onDoubleTap: _handleDoubleTap,
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: Image.network(
                    widget.imageUrl,
                    errorBuilder: (context, error, stack) => const Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final TutorChatMessage message;

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
                    MermaidView(diagram: parsed.diagram!, height: 260),
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