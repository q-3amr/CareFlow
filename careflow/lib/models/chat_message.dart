import 'package:uuid/uuid.dart';

enum MessageSender { user, bot } // تعريف نوع المرسل، سواء كان المستخدم أو البوت

class ChatMessage {
  final String id; // معرف فريد لكل رسالة
  final String text; // نص الرسالة
  final MessageSender sender; // المرسل (المستخدم أو البوت)
  final DateTime timestamp; // الطابع الزمني للرسالة

  ChatMessage({
    // منشئ الكلاس
    String? id, // معرف اختياري، إذا لم يتم توفيره سيتم توليد معرف فريد
    required this.text, // نص الرسالة مطلوب
    required this.sender, // المرسل مطلوب
    DateTime?
        timestamp, // الطابع الزمني اختياري، إذا لم يتم توفيره سيتم استخدام الوقت الحالي
  })  : id = id ?? Uuid().v4(), // توليد معرف فريد إذا لم يتم توفيره
        timestamp = timestamp ??
            DateTime
                .now(); // إذا لم يتم توفير الطابع الزمني، سيتم استخدام الوقت الحالي

  bool get isUser =>
      sender == MessageSender.user; // تحقق مما إذا كانت الرسالة من المستخدم
}
