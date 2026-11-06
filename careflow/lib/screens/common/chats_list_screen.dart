import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/database_service.dart';
import '../../models/user.dart';
import '../../utils/constants.dart';
import 'chat_screen.dart';

class ChatsListScreen extends StatelessWidget {
  const ChatsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.black,
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null, // إخفاء زر الرجوع إذا كانت هذه الشاشة الجذر
        automaticallyImplyLeading: false, // منع Flutter من إضافة زر رجوع تلقائي
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: currentUser?.uid != null
            ? FirebaseFirestore.instance
                .collection('chats') // الاستماع لمجموعة المحادثات في Firestore
                .where('participants',
                    arrayContains: currentUser!
                        .uid) // جلب المحادثات التي يشارك فيها المستخدم الحالي فقط
                .orderBy('lastMessageTime',
                    descending: true) // ترتيب المحادثات من الأحدث للأقدم
                .snapshots()
            : null,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text(
                    'Error: ${snapshot.error}')); // عرض رسالة خطأ إذا فشل التحميل
          }
          if (!snapshot.hasData) {
            return const Center(
                child:
                    CircularProgressIndicator()); // مؤشر تحميل أثناء جلب البيانات
          }

          final docs =
              snapshot.data!.docs; // قائمة وثائق المحادثات من Firestore

          if (docs.isEmpty) {
            // عرض رسالة عندما لا توجد محادثات بعد
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No messages yet',
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length, // عدد المحادثات
            itemBuilder: (context, index) {
              final chatData =
                  docs[index].data() as Map<String, dynamic>; // بيانات المحادثة
              final List participants =
                  chatData['participants']; // قائمة المشاركين في المحادثة
              final String otherUserId = participants.firstWhere(
                (id) =>
                    id !=
                    currentUser
                        ?.uid, // إيجاد معرف الشخص الآخر (ليس المستخدم الحالي)
                orElse: () => '', // إذا لم يُوجد يُعطى قيمة فارغة
              );

              if (otherUserId.isEmpty)
                return const SizedBox(); // تخطي المحادثة إذا لم يوجد مستخدم آخر

              return FutureBuilder<UserModel?>(
                future: db.getUserById(
                    otherUserId), // جلب بيانات المستخدم الآخر من Firestore
                builder: (context, userSnap) {
                  if (!userSnap.hasData) {
                    // عرض مربع رمادي كـ placeholder أثناء تحميل بيانات المستخدم
                    return Container(
                      height: 80,
                      margin: const EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    );
                  }

                  if (userSnap.data == null)
                    return const SizedBox
                        .shrink(); // إخفاء العنصر إذا لم يُوجد المستخدم

                  final String name = userSnap.data!.name; // اسم المستخدم الآخر

                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => ChatScreen(
                          receiverId:
                              otherUserId, // تمرير معرف المستخدم الآخر كـ receiverId
                          receiverName:
                              name, // تمرير اسم المستخدم الآخر لعرضه في شاشة الدردشة
                        ),
                      ),
                    ),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: Colors.grey.shade300, width: 2.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: kPrimaryBlue.withValues(
                                alpha: 0.1), // خلفية زرقاء فاتحة لصورة المستخدم
                            child: Icon(
                              Icons.person,
                              color: kPrimaryBlue,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name, // اسم المستخدم الآخر
                                        maxLines: 1,
                                        overflow: TextOverflow
                                            .ellipsis, // اختصار الاسم إذا كان طويلاً
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        chatData['lastMessage'] ??
                                            'Start chatting...', // عرض آخر رسالة أو نص افتراضي إذا لم توجد
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (chatData['lastMessageSenderId'] !=
                                        currentUser
                                            ?.uid && // إذا كانت آخر رسالة من الشخص الآخر
                                    chatData['isRead'] ==
                                        false) // وكانت غير مقروءة
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF407CE2),
                                      shape: BoxShape
                                          .circle, // نقطة زرقاء تشير إلى وجود رسالة غير مقروءة
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
    );
  }
}
