import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/database_service.dart';
import '../../services/message.dart';
import '../../utils/constants.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId; // معرف المستخدم المستقبِل للرسائل
  final String receiverName; // اسم المستخدم المستقبِل لعرضه في شريط العنوان

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  void initState() {
    super.initState();
    _markAsRead(); // تعليم الرسائل كمقروءة عند فتح الشاشة
  }

  // دالة لتعليم المحادثة كمقروءة في Firestore عند فتح الشاشة
  void _markAsRead() async {
    final chatRoomId = _chatRoomId(
        _currentUserId, widget.receiverId); // الحصول على معرف غرفة الدردشة
    await _db.updateChatRoom(chatRoomId, {
      'isRead': true, // تحديث حالة القراءة إلى "مقروء"
    });
  }

  final _db = DatabaseService(); // كائن للتعامل مع Firestore
  final TextEditingController _messageController =
      TextEditingController(); // متحكم في حقل كتابة الرسالة
  final String _currentUserId = FirebaseAuth
      .instance.currentUser!.uid; // معرف المستخدم الحالي المسجل دخوله
  final MessageServices _messageServices =
      MessageServices(); // كائن لإرسال إشعارات الرسائل

  // دالة لتوليد معرف فريد لغرفة الدردشة بين مستخدمَين (مرتب أبجدياً لضمان التفرد)
  String _chatRoomId(String user1, String user2) =>
      user1.compareTo(user2) > 0 ? '${user1}_$user2' : '${user2}_$user1';

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return; // لا ترسل رسالة فارغة

    final msg = _messageController.text.trim(); // نص الرسالة بعد إزالة المسافات
    _messageController.clear(); // مسح حقل الإدخال بعد الإرسال

    final chatRoomId =
        _chatRoomId(_currentUserId, widget.receiverId); // معرف غرفة الدردشة
    final now = Timestamp.now(); // الوقت الحالي لتسجيل وقت الرسالة

    // حفظ الرسالة في مجموعة messages داخل غرفة الدردشة في Firestore
    await _db.sendMessage(chatRoomId, {
      'senderId': _currentUserId, // معرف المرسل
      'receiverId': widget.receiverId, // معرف المستقبِل
      'message': msg, // نص الرسالة
      'timestamp': now, // وقت إرسال الرسالة
    });

    // تحديث بيانات غرفة الدردشة بآخر رسالة ومعلومات المشاركين
    await _db.updateChatRoom(chatRoomId, {
      'participants': [
        _currentUserId,
        widget.receiverId
      ], // قائمة المشاركين في الدردشة
      'lastMessage': msg, // نص آخر رسالة للعرض في قائمة المحادثات
      'lastMessageTime': now, // وقت آخر رسالة
      'users': {
        _currentUserId: true,
        widget.receiverId: true
      }, // خريطة المستخدمين لسهولة الاستعلام
      'lastMessageSenderId': _currentUserId, // معرف مرسل آخر رسالة
      'isRead':
          false, // تعليم المحادثة كغير مقروءة عند إرسال رسالة جديدة//patient home
    });

    // جلب اسم المرسل من Firestore ثم إرسال إشعار للمستقبِل
    final senderUser =
        await _db.getUserById(_currentUserId); // جلب بيانات المرسل من Firestore
    final senderName = senderUser?.name ??
        'Someone'; // اسم المرسل، وإذا لم يُوجد يُعطى 'Someone'

    final token =
        await _db.getToken(widget.receiverId); // جلب الـ FCM Token بالطرف الاخر
    if (token.isNotEmpty) {
      // إرسال الإشعار فقط إذا كان التوكن موجوداً
      await _messageServices.sendNotificationToUser(
          fcmToken: token, // التوكن الخاص بجهاز المستقبِل
          title:
              'New Message from $senderName', // عنوان الإشعار باسم المرسل الحقيقي من Firestore
          body: msg, // نص الرسالة في جسم الإشعار
          type: 'chat'); // نوع الإشعار لتمييزه عن أنواع الإشعارات الأخرى
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatRoomId = _chatRoomId(_currentUserId,
        widget.receiverId); // معرف غرفة الدردشة لاستخدامه في بناء الواجهة

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.receiverName, // عرض اسم المستقبِل في شريط العنوان
          maxLines: 1,
          overflow: TextOverflow.ellipsis, // اختصار الاسم بـ ... إذا كان طويلاً
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
          ),
        ),
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context), // الرجوع للشاشة السابقة
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
              color: Colors.grey.shade100,
              height: 1), // خط فاصل رفيع أسفل الـ AppBar
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<dynamic>(
              stream: _db.streamMessages(
                  chatRoomId), // الاستماع لتحديثات الرسائل في الوقت الفعلي
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                      child: Text(
                          'Error loading messages')); // عرض خطأ إذا فشل التحميل
                }
                if (!snapshot.hasData) {
                  return const Center(
                      child:
                          CircularProgressIndicator()); // مؤشر تحميل أثناء جلب الرسائل
                }

                final docs =
                    snapshot.data!.docs; // قائمة وثائق الرسائل من Firestore

                return ListView.builder(
                  reverse:
                      true, // عرض الرسائل من الأحدث إلى الأقدم (آخر رسالة في الأسفل)
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  itemCount: docs.length, // عدد الرسائل
                  itemBuilder: (context, index) {
                    final data = docs[index].data()
                        as Map<String, dynamic>; // بيانات الرسالة
                    final isMe = data['senderId'] ==
                        _currentUserId; // تحديد إذا كانت الرسالة مرسلة من المستخدم الحالي
                    return _buildChatBubble(
                        data['message'], isMe); // بناء فقاعة الرسالة
                  },
                );
              },
            ),
          ),
          _buildInputArea(), // منطقة الإدخال وزر الإرسال
        ],
      ),
    );
  }

  // دالة لبناء فقاعة رسالة واحدة مع تنسيق مختلف للمرسِل والمستقبِل
  Widget _buildChatBubble(String text, bool isMe) {
    return Align(
      alignment: isMe
          ? Alignment.centerRight
          : Alignment.centerLeft, // محاذاة الفقاعة يمين للمرسل ويسار للمستقبِل
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color:
              isMe ? kPrimaryBlue : Colors.white, // أزرق للمرسل وأبيض للمستقبِل
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe
                ? 20
                : 0), // الزاوية السفلية اليسرى مستديرة للمرسل ومربعة للمستقبِل
            bottomRight: Radius.circular(isMe
                ? 0
                : 20), // الزاوية السفلية اليمنى مربعة للمرسل ومستديرة للمستقبِل
          ),
          border: isMe
              ? null
              : Border.all(
                  color: Colors.grey.shade200), // حد رمادي فقط لفقاعة المستقبِل
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isMe
                ? Colors.white
                : Colors.black87, // أبيض للمرسل وأسود للمستقبِل
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // دالة لبناء منطقة الإدخال في أسفل الشاشة مع زر الإرسال
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5), // الظل للأعلى لإعطاء تأثير الارتفاع
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(30), // حواف دائرية لحقل الإدخال
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: TextField(
                controller: _messageController, // ربط الحقل بمتحكم النص
                decoration: const InputDecoration(
                  hintText: 'Write a message...', // نص توضيحي داخل الحقل
                  border: InputBorder.none, // إزالة الإطار الافتراضي للحقل
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: kPrimaryBlue.withValues(
                      alpha: 0.4), // ظل أزرق حول زر الإرسال
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 26, // حجم الدائرة لزر الإرسال
              backgroundColor: kPrimaryBlue,
              child: IconButton(
                icon: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                onPressed: _sendMessage, // استدعاء دالة الإرسال عند الضغط
              ),
            ),
          ),
        ],
      ),
    );
  }
}
