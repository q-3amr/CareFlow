import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/database_service.dart';
import '../../services/message.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_tokens.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_empty_state.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _db = DatabaseService();
  final TextEditingController _messageController = TextEditingController();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final MessageServices _messageServices = MessageServices();

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _markAsRead() async {
    final chatRoomId = _chatRoomId(_currentUserId, widget.receiverId);
    await _db.updateChatRoom(chatRoomId, {
      'isRead': true,
    });
  }

  String _chatRoomId(String user1, String user2) =>
      user1.compareTo(user2) > 0 ? '${user1}_$user2' : '${user2}_$user1';

  void _sendMessage() async {
    final msg = _messageController.text.trim();
    if (msg.isEmpty) return;

    _messageController.clear();

    final chatRoomId = _chatRoomId(_currentUserId, widget.receiverId);
    final now = Timestamp.now();

    await _db.sendMessage(chatRoomId, {
      'senderId': _currentUserId,
      'receiverId': widget.receiverId,
      'message': msg,
      'timestamp': now,
    });

    await _db.updateChatRoom(chatRoomId, {
      'participants': [_currentUserId, widget.receiverId],
      'lastMessage': msg,
      'lastMessageTime': now,
      'users': {_currentUserId: true, widget.receiverId: true},
      'lastMessageSenderId': _currentUserId,
      'isRead': false,
    });

    final senderUser = await _db.getUserById(_currentUserId);
    final senderName = senderUser?.name ?? 'Someone';

    final token = await _db.getToken(widget.receiverId);
    if (token.isNotEmpty) {
      await _messageServices.sendNotificationToUser(
        fcmToken: token,
        title: 'New Message from $senderName',
        body: msg,
        type: 'chat',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final chatRoomId = _chatRoomId(_currentUserId, widget.receiverId);

    final initials = widget.receiverName.isNotEmpty
        ? widget.receiverName
            .trim()
            .split(' ')
            .map((n) => n.isNotEmpty ? n[0] : '')
            .take(2)
            .join()
        : 'US';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            AppAvatar(initials: initials, size: 36),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.receiverName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.section.copyWith(color: textPrimary),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 11,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          'Encrypted Consultation',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            fontSize: 10,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<dynamic>(
              stream: _db.streamMessages(chatRoomId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return AppEmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load messages',
                    message: 'Check your connection and try again.',
                    compact: true,
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'No messages yet',
                    message: 'Send a message to start the consultation.',
                    compact: true,
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == _currentUserId;
                    return _buildChatBubble(data, isMe, textPrimary);
                  },
                );
              },
            ),
          ),
          _buildInputArea(textPrimary),
        ],
      ),
    );
  }

  Widget _buildChatBubble(
      Map<String, dynamic> data, bool isMe, Color textPrimary) {
    final text = data['message'] ?? '';
    final timestamp = data['timestamp'];
    String timeStr = '';
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      timeStr = '$h:$m $ampm';
    }

    return Padding(
      padding: EdgeInsets.only(
        top: AppSpacing.xs,
        bottom: AppSpacing.xs,
        left: isMe ? AppSpacing.xxxl : 0,
        right: isMe ? 0 : AppSpacing.xxxl,
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isMe
                ? AppColors.primary
                : (Theme.of(context).brightness == Brightness.dark
                    ? AppColors.cardDark
                    : AppColors.cardLight),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppRadius.md),
              topRight: const Radius.circular(AppRadius.md),
              bottomLeft: Radius.circular(isMe ? AppRadius.md : AppRadius.sm),
              bottomRight: Radius.circular(isMe ? AppRadius.sm : AppRadius.md),
            ),
            border: Border.all(
              color: isMe
                  ? AppColors.primary
                  : (Theme.of(context).brightness == Brightness.dark
                      ? AppColors.borderDark
                      : AppColors.borderLight),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: AppTypography.body.copyWith(
                  color: isMe ? Colors.white : textPrimary,
                ),
              ),
              if (timeStr.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  timeStr,
                  style: AppTypography.caption.copyWith(
                    fontSize: 10,
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.8)
                        : (Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(Color textPrimary) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                minLines: 1,
                maxLines: 3,
                style: AppTypography.body.copyWith(color: textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Type your message...',
                  fillColor: AppColors.surfaceSunken,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              tooltip: 'Send message',
              onPressed: _sendMessage,
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
      ),
    );
  }
}
