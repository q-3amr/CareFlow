import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/database_service.dart';
import '../../models/user.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_tokens.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_empty_state.dart';
import 'chat_screen.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  final db = DatabaseService();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  String _searchFilter = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Consultation Messages',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: Column(
        children: [
          // Search Input Header
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(
                  () => _searchFilter = val.trim().toLowerCase()),
              textInputAction: TextInputAction.search,
              style: AppTypography.body.copyWith(color: textPrimary),
              decoration: InputDecoration(
                hintText: 'Search conversations...',
                fillColor: AppColors.surfaceSunken,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchFilter.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchFilter = '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Messages Stream
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: currentUser?.uid != null
                  ? FirebaseFirestore.instance
                      .collection('chats')
                      .where('participants', arrayContains: currentUser!.uid)
                      .orderBy('lastMessageTime', descending: true)
                      .snapshots()
                  : null,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final chatData =
                        docs[index].data() as Map<String, dynamic>;
                    final List participants = chatData['participants'] ?? [];
                    final String otherUserId = participants.firstWhere(
                      (id) => id != currentUser?.uid,
                      orElse: () => '',
                    );

                    if (otherUserId.isEmpty) return const SizedBox.shrink();

                    return FutureBuilder<UserModel?>(
                      future: db.getUserById(otherUserId),
                      builder: (context, userSnap) {
                        if (!userSnap.hasData || userSnap.data == null) {
                          return const SizedBox.shrink();
                        }

                        final userModel = userSnap.data!;
                        final String name = userModel.name;

                        if (_searchFilter.isNotEmpty &&
                            !name.toLowerCase().contains(_searchFilter)) {
                          return const SizedBox.shrink();
                        }

                        final bool isUnread = chatData['isRead'] == false &&
                            chatData['lastMessageSenderId'] !=
                                currentUser?.uid;

                        final initials = name.isNotEmpty
                            ? name
                                .trim()
                                .split(' ')
                                .map((n) => n.isNotEmpty ? n[0] : '')
                                .take(2)
                                .join()
                            : 'US';

                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: AppCard(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (c) => ChatScreen(
                                  receiverId: otherUserId,
                                  receiverName: name,
                                ),
                              ),
                            ),
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Row(
                              children: [
                                // Avatar with unread indicator
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    AppAvatar(initials: initials, size: 48),
                                    if (isUnread)
                                      Positioned(
                                        right: -2,
                                        top: -2,
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Theme.of(context)
                                                  .cardColor,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: AppSpacing.md),

                                // Chat preview
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              userModel.isDoctor
                                                  ? 'Dr. $name'
                                                  : name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.label
                                                  .copyWith(
                                                color: textPrimary,
                                                fontWeight: isUnread
                                                    ? FontWeight.w700
                                                    : FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          if (chatData['lastMessageTime'] !=
                                              null) ...[
                                            const SizedBox(
                                                width: AppSpacing.sm),
                                            Text(
                                              _formatLastTime(
                                                  chatData['lastMessageTime']),
                                              style: AppTypography.caption
                                                  .copyWith(
                                                fontSize: 11,
                                                color: isUnread
                                                    ? AppColors.primary
                                                    : textSecondary,
                                                fontWeight: isUnread
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        chatData['lastMessage'] ??
                                            'Start chatting...',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.body.copyWith(
                                          color: isUnread
                                              ? textPrimary
                                              : textSecondary,
                                          fontWeight: isUnread
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastTime(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      final now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
        final m = dt.minute.toString().padLeft(2, '0');
        final ampm = dt.hour >= 12 ? 'PM' : 'AM';
        return '$h:$m $ampm';
      }
      return '${dt.day}/${dt.month}';
    }
    return '';
  }

  Widget _buildEmptyState() {
    return const AppEmptyState(
      icon: Icons.chat_bubble_outline_rounded,
      title: 'No Messages Yet',
      message:
          'Direct messages with your doctors or patients will appear here.',
    );
  }
}
