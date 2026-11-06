import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../models/chat_message.dart';
import '../../utils/constants.dart';

class VoiceChat extends StatefulWidget {
  const VoiceChat({super.key});

  @override
  State<VoiceChat> createState() => _VoiceChatState();
}

class _VoiceChatState extends State<VoiceChat> with TickerProviderStateMixin {
  // المتغيرات للتحكم في التمرير، النص، والرسوم المتحركة
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late ChatProvider _chatProvider;

// تهيئة الرسوم المتحركة والاستماع لتغييرات المزود بعد بناء الواجهة
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.22).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatProvider = context.read<ChatProvider>();
      _chatProvider.addListener(_onProviderChange);
      _chatProvider.initialize();
      _scrollToBottom();
    });
  }

  // تنظيف الموارد وإلغاء الاستماع عند التخلص من الواجهة

  @override
  void dispose() {
    _chatProvider.removeListener(_onProviderChange);
    _pulseController.dispose();
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  // التعامل مع تغييرات المزود لعرض رسائل الخطأ أو تحديث الواجهة

  void _onProviderChange() {
    if (_chatProvider.hasConnectionError && mounted) {
      _showConnectionError();
    }
  }

// تمرير القائمة إلى الأسفل عند إضافة رسالة جديدة أو عند بدء/إيقاف التسجيل
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // إرسال رسالة نصية عند الضغط على زر الإرسال أو عند الضغط على "Enter"

  void _sendText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    context.read<ChatProvider>().sendTextMessage(text);
    _textController.clear();
    _scrollToBottom();
  }

  // عرض رسالة خطأ عند وجود مشكلة في الاتصال

  void _showConnectionError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
            'Connection error, check your connection and try again!'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      // إعادة بناء الواجهة عند تغير حالة المزود
      builder: (context, chat, _) {
        if (chat.messages.isNotEmpty)
          _scrollToBottom(); // تمرير القائمة إلى الأسفل عند إضافة رسالة جديدة
        return Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: const Color(0xFFF5F7FA),
          body: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _buildAppBar(chat), // شريط العنوان مع حالة التسجيل/التحدث
                Expanded(
                    child: _buildMessageList(
                        chat)), // قائمة الرسائل مع مؤشرات التسجيل والكتابة
                chat.isTriageComplete
                    ? _buildCompletionButton(
                        chat) // زر إكمال التقييم بناءً على حالة التقييم
                    : _buildInputBar(
                        chat), // شريط الإدخال أو زر إكمال التقييم بناءً على حالة التقييم
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(ChatProvider chat) {
    // شريط العنوان مع حالة التسجيل/التحدث
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFF0F2F5),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF2C2C2C),
                size: 16,
              ),
            ),
          ),
          SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kPrimaryBlue,
            ),
            child: Center(
              child: Text(
                'AI',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Chat',
                  style: TextStyle(
                    color: Color(0xFF1A1A2E),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (chat.isListening || chat.isSpeaking)
                  Text(
                    chat.isListening ? 'Recording...' : 'Playing...',
                    style: TextStyle(
                      color: kPrimaryBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(ChatProvider chat) {
    // قائمة الرسائل مع مؤشرات التسجيل والكتابة
    final bool showIndicator = chat.isListening || chat.isTyping;
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: chat.messages.length + (showIndicator ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == chat.messages.length) {
          if (chat.isListening) return _buildListeningIndicator();
          return const _TypingIndicator();
        }
        final message = chat.messages[index];
        return _ChatBubble(
          message: message,
          onSpeak: () => chat.speakMessage(message),
          isSpeaking: chat.isSpeaking,
        );
      },
    );
  }

  Widget _buildListeningIndicator() {
    // مؤشر التسجيل الصوتي أثناء تسجيل رسالة المستخدم
    return Padding(
      padding: const EdgeInsets.only(top: 3, bottom: 3, left: 52, right: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: kPrimaryBlue.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(4),
              ),
              border: Border.all(
                color: kPrimaryBlue.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mic, color: kPrimaryBlue, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Recording your message...',
                  style: TextStyle(
                    color: kPrimaryBlue,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(ChatProvider chat) {
    // شريط الإدخال مع زر التسجيل الصوتي وزر الإرسال
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      maxLines: null,
                      style: TextStyle(
                        color: Color(0xFF1A1A2E),
                        fontSize: 14.5,
                        height: 1.4,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                          color: Color(0xFFAAAAAA),
                          fontSize: 14.5,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => _sendText(),
                    ),
                  ),
                  SizedBox(width: 8),
                ],
              ),
            ),
          ),
          SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              if (chat.isListening) {
                // إذا كان في وضع التسجيل، إيقاف التسجيل، وإلا بدء التسجيل
                chat.stopListening();
              } else {
                chat.startListening();
              }
            },
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) => Transform.scale(
                scale: chat.isListening ? _pulseAnimation.value : 1.0,
                child: child,
              ),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: chat.isListening ? kPrimaryBlue : Color(0xFFF0F2F5),
                  boxShadow: chat.isListening
                      ? [
                          BoxShadow(
                            color: kPrimaryBlue.withValues(alpha: 0.35),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  chat.isListening
                      ? Icons.stop_rounded
                      : Icons.mic_none_rounded,
                  color: chat.isListening ? Colors.white : kPrimaryBlue,
                  size: 22,
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          GestureDetector(
            onTap: _sendText,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kPrimaryBlue,
                boxShadow: [
                  BoxShadow(
                    color: kPrimaryBlue.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionButton(ChatProvider chat) {
    // زر إكمال التقييم بناءً على حالة التقييم
    final Color backgroundColor;
    final IconData icon;
    final String label;
    final VoidCallback onPressed;

    switch (chat.triageUrgency) {
      case 'red':
        backgroundColor = Colors.red;
        icon = Icons.warning_amber_rounded;
        label = 'EMERGENCY: Call Ambulance';
        onPressed = () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Go to the Emergency Room immediately or call your local emergency number!',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        };
        break;

      case 'green':
      default:
        backgroundColor = Colors.green;
        icon = Icons.home_rounded;
        label = 'Understood, Back to Home';
        onPressed = () => Navigator.pop(context);
        break;
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white),
          label: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 3,
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  // فقاعة الدردشة لكل رسالة مع زر الاستماع إذا كانت رسالة AI
  final ChatMessage message;
  final VoidCallback onSpeak;
  final bool isSpeaking;

  const _ChatBubble({
    required this.message,
    required this.onSpeak,
    required this.isSpeaking,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: EdgeInsets.only(
        top: 3,
        bottom: 3,
        left: isUser ? 52 : 0,
        right: isUser ? 0 : 52,
      ),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser)
            Container(
              width: 30,
              height: 30,
              margin: EdgeInsets.only(right: 6, bottom: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kPrimaryBlue,
              ),
              child: Center(
                child: Text(
                  'AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          Flexible(
            child: Row(
              mainAxisAlignment:
                  isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isUser ? kPrimaryBlue : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(isUser ? 18 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: isUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.text,
                          style: TextStyle(
                            color: isUser ? Colors.white : Color(0xFF1A1A2E),
                            fontSize: 14.5,
                            height: 1.45,
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(message.timestamp),
                              style: TextStyle(
                                color: isUser
                                    ? Colors.white.withValues(alpha: 0.5)
                                    : Color(0xFFAAAAAA),
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isUser) ...[SizedBox(width: 5), _buildVoiceBtn()],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceBtn() {
    // زر الاستماع لرسائل AI، يظهر فقط إذا كانت الرسالة ليست من المستخدم
    return GestureDetector(
      onTap: onSpeak,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.volume_up_outlined,
          size: 14,
          color: Color(0xFF6C63FF),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    // تنسيق الوقت لعرضه بجانب كل رسالة
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _TypingIndicator extends StatefulWidget {
  // مؤشر الكتابة مع ثلاث نقاط متحركة يظهر عندما يكون AI يكتب ردًا
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
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
      padding: const EdgeInsets.only(top: 3, bottom: 3, left: 0, right: 52),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(right: 6, bottom: 2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF407CE2),
            ),
            child: const Center(
              child: Text(
                'AI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                // ثلاث نقاط متحركة مع تأخير زمني لإنشاء تأثير النبض أثناء الكتابة
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) {
                    final delay = i *
                        0.3; // تأخير زمني لكل نقطة لإنشاء تأثير النبض المتتالي
                    final t = (_controller.value + delay) %
                        1.0; // قيمة بين 0 و 1 مع تأخير لكل نقطة
                    final scale = 0.6 +
                        0.4 *
                            (t < 0.5
                                ? t * 2
                                : (1 - t) *
                                    2); // مقياس يتراوح بين 0.6 و 1.0 لإنشاء تأثير النبض
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 8 * scale,
                      height: 8 * scale,
                      decoration: BoxDecoration(
                        color: const Color(0xFF407CE2).withValues(alpha: 0.7),
                        shape: BoxShape.circle,
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
