import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../models/chat_message.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_tokens.dart';

class VoiceChat extends StatefulWidget {
  const VoiceChat({super.key});

  @override
  State<VoiceChat> createState() => _VoiceChatState();
}

class _VoiceChatState extends State<VoiceChat> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late ChatProvider _chatProvider;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatProvider = Provider.of<ChatProvider>(context, listen: false);
      _chatProvider.initialize();
      _chatProvider.addListener(_onChatProviderChanged);
    });
  }

  void _onChatProviderChanged() {
    _scrollToBottom();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scrollController.dispose();
    _textController.dispose();
    _chatProvider.removeListener(_onChatProviderChanged);
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _chatProvider.sendTextMessage(text);
    _textController.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<ChatProvider>(
      builder: (context, chat, _) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _buildAppBar(chat, isDark),
                if (chat.isTriageComplete) _buildAssessmentBanner(chat),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: chat.messages.length + (chat.isListening ? 1 : 0) + (chat.isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < chat.messages.length) {
                        final message = chat.messages[index];
                        return _ChatBubble(
                          message: message,
                          onSpeak: () => chat.speakMessage(message),
                          isSpeaking: chat.isSpeaking,
                          isDark: isDark,
                        );
                      } else if (chat.isListening && index == chat.messages.length) {
                        return _buildListeningIndicator(isDark);
                      } else {
                        return _TypingIndicator(isDark: isDark);
                      }
                    },
                  ),
                ),
                if (!chat.isTriageComplete) _buildBottomBar(chat, isDark),
                if (chat.isTriageComplete) _buildCompletionButton(chat),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(ChatProvider chat, bool isDark) {
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: AppSpacing.xs),

          // AI Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.primaryContainerDark
                  : AppColors.primaryLight,
              borderRadius: AppRadius.small,
            ),
            child: Icon(
              Icons.psychology_rounded,
              color: isDark ? const Color(0xFFBFDBFE) : AppColors.primary,
              size: AppIconSize.lg,
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'CareFlow AI Triage',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.section.copyWith(
                          color: textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                Text(
                  chat.isListening
                      ? 'Listening to your voice...'
                      : chat.isTyping
                          ? 'Analyzing symptoms...'
                          : 'Clinical Decision Support Assistant',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: chat.isListening ? AppColors.primary : textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentBanner(ChatProvider chat) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEmergency = chat.triageUrgency == 'red';
    final bannerBg = isEmergency
        ? (isDark ? AppColors.destructiveSoftDark : AppColors.destructiveLight)
        : (isDark ? AppColors.successSoftDark : AppColors.successLight);
    final borderColor = isEmergency
        ? (isDark ? const Color(0xFFF97066) : AppColors.destructive)
        : (isDark ? const Color(0xFF34D399) : AppColors.success);
    final textColor = isEmergency
        ? (isDark ? const Color(0xFFFECDCA) : AppColors.destructiveText)
        : (isDark ? const Color(0xFF6EE7B7) : AppColors.successText);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: bannerBg,
        border: Border(
          bottom: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isEmergency
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline_rounded,
            color: borderColor,
            size: AppIconSize.md,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEmergency
                      ? 'Urgent Medical Attention Advised'
                      : 'Clinical Assessment Complete',
                  style: AppTypography.label.copyWith(color: textColor),
                ),
                const SizedBox(height: 2),
                Text(
                  isEmergency
                      ? 'Please consult an emergency facility or doctor promptly.'
                      : 'Review triage recommendations below or book a consultation.',
                  style: AppTypography.caption.copyWith(
                    color: textColor.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListeningIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.xs,
        bottom: AppSpacing.xs,
        left: AppSpacing.xxxl,
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.primaryContainerDark
                : AppColors.primaryLight,
            borderRadius: AppRadius.medium,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.graphic_eq_rounded,
                size: AppIconSize.sm,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Listening...',
                style: AppTypography.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(ChatProvider chat, bool isDark) {
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Voice Mic Button
          Semantics(
            button: true,
            label: chat.isListening ? 'Stop listening' : 'Start voice input',
            child: InkWell(
              onTap:
                  chat.isListening ? chat.stopListening : chat.startListening,
              customBorder: const CircleBorder(),
              child: ScaleTransition(
                scale: chat.isListening
                    ? _pulseAnimation
                    : const AlwaysStoppedAnimation(1.0),
                child: Container(
                  width: AppMetrics.minTarget,
                  height: AppMetrics.minTarget,
                  decoration: BoxDecoration(
                    color: chat.isListening
                        ? AppColors.destructive
                        : AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    chat.isListening ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: AppIconSize.md,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Text Field
          Expanded(
            child: TextField(
              controller: _textController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendText(),
              minLines: 1,
              maxLines: 3,
              style: AppTypography.body.copyWith(color: textPrimary),
              decoration: const InputDecoration(
                hintText: 'Type symptom or question...',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Send Button
          IconButton.filled(
            tooltip: 'Send message',
            onPressed: _sendText,
            icon: const Icon(Icons.send_rounded, size: AppIconSize.md),
            style: IconButton.styleFrom(
              minimumSize: const Size(
                AppMetrics.minTarget,
                AppMetrics.minTarget,
              ),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionButton(ChatProvider chat) {
    final isEmergency = chat.triageUrgency == 'red';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            if (isEmergency) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Contact your local emergency hotline or visit nearest ER immediately.',
                  ),
                  backgroundColor: AppColors.destructive,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else {
              Navigator.pop(context);
            }
          },
          icon: Icon(
            isEmergency
                ? Icons.emergency_rounded
                : Icons.check_circle_outline_rounded,
            size: AppIconSize.sm,
          ),
          label: Text(
            isEmergency
                ? 'Emergency Guidance'
                : 'Complete Consultation & Return',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isEmergency ? AppColors.destructive : AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, AppMetrics.controlHeight),
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onSpeak;
  final bool isSpeaking;
  final bool isDark;

  const _ChatBubble({
    required this.message,
    required this.onSpeak,
    required this.isSpeaking,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return Padding(
      padding: EdgeInsets.only(
        top: AppSpacing.xs,
        bottom: AppSpacing.xs,
        left: isUser ? AppSpacing.xxxl : 0,
        right: isUser ? 0 : AppSpacing.xxxl,
      ),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.primaryContainerDark
                    : AppColors.primaryLight,
                borderRadius: AppRadius.small,
              ),
              alignment: Alignment.center,
              child: Text(
                'AI',
                style: AppTypography.caption.copyWith(
                  color: isDark ? const Color(0xFFBFDBFE) : AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.primary
                    : (isDark ? AppColors.cardDark : AppColors.cardLight),
                borderRadius: AppRadius.medium,
                border: Border.all(
                  color: isUser
                      ? AppColors.primary
                      : (isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight),
                ),
              ),
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: AppTypography.body.copyWith(
                      color: isUser ? Colors.white : textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: AppTypography.caption.copyWith(
                          fontSize: 10,
                          color: isUser
                              ? Colors.white.withValues(alpha: 0.8)
                              : (isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight),
                        ),
                      ),
                      if (!isUser) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Semantics(
                          button: true,
                          label: 'Speak message',
                          child: InkResponse(
                            onTap: onSpeak,
                            radius: 18,
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                isSpeaking
                                    ? Icons.volume_up_rounded
                                    : Icons.volume_up_outlined,
                                size: AppIconSize.sm,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _TypingIndicator extends StatefulWidget {
  final bool isDark;
  const _TypingIndicator({required this.isDark});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.xs,
        bottom: AppSpacing.xs,
        right: AppSpacing.xxxl,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: widget.isDark
                  ? AppColors.primaryContainerDark
                  : AppColors.primaryLight,
              borderRadius: AppRadius.small,
            ),
            alignment: Alignment.center,
            child: Text(
              'AI',
              style: AppTypography.caption.copyWith(
                color:
                    widget.isDark ? const Color(0xFFBFDBFE) : AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? AppColors.cardDark
                  : AppColors.cardLight,
              borderRadius: AppRadius.medium,
              border: Border.all(
                color: widget.isDark
                    ? AppColors.borderDark
                    : AppColors.borderLight,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) {
                    final progress = (_controller.value - (i * 0.2)) % 1.0;
                    final opacity =
                        (progress < 0.5 ? progress * 2 : (1.0 - progress) * 2)
                            .clamp(0.2, 1.0);
                    return Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: opacity),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
