import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../services/ai_service.dart';

// هون العقل الخاص بالتحكم بين قراءة النص و بين تحويل النص لحكي
class ChatProvider extends ChangeNotifier {
  final SpeechService _speechService =
      SpeechService(); // تعريف اوبجكت من الكلاس الخاصة بتحويل الحكي لنص
  final TtsService _ttsService =
      TtsService(); // تعريف اوبجكت من الكلاس الخاصة بلفظ النص
  final AiService _aiService = AiService(); // الكلاس الخاصة بال AI

  final List<ChatMessage> _messages =
      []; // list فيها جميع المسجات الخاصة بالمحادثة و بتكون على شكل ChatMessage

  bool _isListening = false; // متغير اذا بستمع
  bool _isSpeaking = false; // متغير اذا بتحدث
  bool _isTyping = false; // متغير اذا بكتب
  bool _isInitialized = false; // تغير خاص اذا تم الانشاء بشكل صحيح

  bool _isTriageComplete = false; // متغير خاص بجمع الاجابة بال AI
  String _triageUrgency = 'none'; // نوع الطلب اذا عاجل او عادي لل AI
  String _recommendedSpecialty = ''; // متغير خاص اذا في توصيات لل AI
  bool _hasConnectionError = false; // متغير خاص بحالة الاتصال

  List<ChatMessage> get messages =>
      List.unmodifiable(_messages); // فنكشن خاص بارجاع المسجات
  bool get isListening => _isListening; // فنكشن لارجاع قيمة التغير
  bool get isSpeaking => _isSpeaking; // فنكشن لارجاع قيمة التغير
  bool get isTyping => _isTyping; // فنكشن لارجاع قيمة التغير
  bool get isTriageComplete => _isTriageComplete; // فنكشن لارجاع قيمة التغير
  String get triageUrgency => _triageUrgency; // فنكشن لارجاع قيمة التغير
  String get recommendedSpecialty =>
      _recommendedSpecialty; // فنكشن لارجاع قيمة التغير
  bool get hasConnectionError =>
      _hasConnectionError; // فنكشن لارجاع قيمة التغير

  Future<void> initialize() async {
    // اول فنكشن بتم استدعاء من اجل استناد القيم الاولية
    if (_isInitialized) return; // اذا معرف قبل بوقف اذا لا بكمل شغل
    await _speechService
        .initialize(); // بستدعي الفنكشن المعرف في كلاس تحويل الحكي لنص
    await _ttsService.initialize(); // بستدعي الفنكشن المعرف داخل كلاس لفظ الحكي

    // اضافة اول مسج من قبل التطبيق على الشات
    _messages.add(ChatMessage(
      text:
          'Hello! I am CareFlow AI Triage Assistant. How can I help you today?',
      sender: MessageSender.bot,
    ));
    notifyListeners(); // فنكشن بيبين حالة الكلاس فقط
    _isInitialized = true; // اسناد قيمة true للمتغير
  }

  Future<void> sendTextMessage(String text) async {
    // فنكشن ارسال مسج على الشات
    if (_isTyping || text.trim().isEmpty) return; // بتاكد اذا النص فاضي او لا
    await _processUserMessage(text.trim()); // بستدعي فنكشن معالجة المسج المرسل
  }

  Future<void> startListening() async {
    // فنكشن بدايه الاستماع
    if (_isListening) return; // اذا كان قاعد بستمع لا تعمل اشي
    if (_isTyping) return; // اذا كان بكتب لا تعمل اي اشي
    if (_isSpeaking) await _ttsService.stop(); // اذا كان بسجل حكي وقفوا

    _isListening = true; // اسناد قيمة قيد الاستماع
    notifyListeners(); // فنكشن بيبين حالة الكلاس فقط

    await _speechService.startListening(
      // بتم استدعاء فنكشن معرف داخل كلاس تحويل الحكي لنص
      onResult: (words) {
        // عند النتيجة
        if (words.isNotEmpty)
          _processUserMessage(
              words); // اذا في كلمات قم بمالجة الكلمات و ادخالهم في الشات
      },
      onDone: () {
        // عند الانتهاء
        _isListening = false; // اسناد قيمة ايقاف الاستماع
        notifyListeners(); // فنكشن بيبين حالة الكلاس فقط
      },
    );
  }

  Future<void> stopListening() async {
    // فنكشن ايقاف الاستماع
    await _speechService
        .stopListening(); // بتم استدعاء فنكشن ايقاف الاستماع من الكلاس الخاص بتحويل الحكي لنص
    _isListening = false; // اسناد قيمة ايقاف الاستماع
    notifyListeners(); // فنكشن بيبين حالة الكلاس فقط
  }

  Future<void> speakMessage(ChatMessage message) async {
    // فنكشن لفظ المسج
    _isSpeaking = true; // اسناد قيمة قيد اللفظ
    notifyListeners(); // فنكشن بيبين حالة الكلاس فقط

    await _ttsService.speak(message
        .text); // بتم استدعاء فنكشن معرف داخل كلاس الخاص بلفظ النص حيث يتم ارسال النص داخل المسج
    _isSpeaking = false; // اسناد قيمة ايقاف اللفظ
    notifyListeners(); // فنكشن بيبين حالة الكلاس فقط
  }

  Future<void> _processUserMessage(String text) async {
    // فنكشن مالجة المسجات المرسلة
    _messages.add(ChatMessage(
        text: text,
        sender: MessageSender
            .user)); // يتم اضافة المسج المرسل الي ال list الخاصة بالمسجات مع المرسل
    _isTyping = true; // اسناد قيمة الكتابة
    notifyListeners(); // فنكشن بيبين حالة الكلاس فقط

    final String aiResponseText = await _aiService.getAiResponse(
        text); // استدعاء فنكشن مالجة المسج من قبل ال AI و تخزينة في متغير

    _isTyping = false; // اسناد قيمة ايقاف الكتابة

    if (aiResponseText.startsWith('Server error') ||
        aiResponseText.startsWith('Connection issue')) {
      // اذا حدثت اي مشكلة في رد ال AI
      _messages.removeLast(); // يتم حذف اخر مسج في المحادثة
      _onConnectionError(); // استدعاء فنكشن السوول عن اظهار خط الاتصال
    } else {
      // اذا ما حدثت مشكلة
      try {
        final Map<String, dynamic> aiData = jsonDecode(
            aiResponseText); // تحويل الرد من صيغة api لصيغة ال json وتخزين الرد في متغير

        final String displayMessage = aiData['message'] ??
            'Error parsing message.'; // اسناد قيمة محتوى الرد من ال AI او اظهار خطا
        final String status =
            aiData['status'] ?? 'asking'; // اسناد قيمة الحالة للطلب
        final String urgency =
            aiData['urgency'] ?? 'none'; // اسناد قيمة مستوى العجلة
        final String specialty =
            aiData['specialty'] ?? 'none'; // اسناد قيمة التخصيص للطلب

        _messages.add(ChatMessage(
            text: displayMessage,
            sender: MessageSender.bot)); // اضافة رد ال AI للمحادثة

        if (status == 'finished') {
          // اذا حالة الطلب منتهيه
          _isTriageComplete = true; // اسناد قيمة اضافة الرد
          _triageUrgency = urgency; // اسناد قيمة مستوى العجلة
          if (specialty != 'none') {
            // اذا كان الطلب بحتوي على قيمة تخصيص
            _recommendedSpecialty = specialty; // اسناد قيمة التخصيص للطلب
          }
        }
      } catch (e) {
        // في حال حدوث اي خطا
        _messages.add(ChatMessage(
          // اضافة مسج الخطا على الشات
          text: "System Error: Couldn't parse response.",
          sender: MessageSender.bot,
        ));
        debugPrint('JSON Parse Error: $e'); // جملة طباعة الخطا
      }
    }

    notifyListeners(); // فنكشن بيبين حالة الكلاس فقط
  }

  void _onConnectionError() {
    // فنكشن حدوث الخطا
    _hasConnectionError = true; // اسناد قيمة حدوث خطا
    notifyListeners(); // فنكشن بيبين حالة الكلاس فقط

    _hasConnectionError = false; // اسناد قيمة فصل الاتصال
  }

  void clearMessages() {
    // فنكشن حذف الشات الكامل
    _messages.clear(); // استدعاء فنكشن خاص بال list بفضيها
    _isTriageComplete = false; // اسناد قيمة تجميع الشات
    _triageUrgency = 'none'; // اسناد قيمة لمستوى العجلة
    _recommendedSpecialty = ''; // اسناد قيمة التخصيص للطلب
    notifyListeners(); // فنكشن بيبين حالة الكلاس فقط
  }

  @override
  void dispose() {
    // في حال اغلاق الاوبجكت الخاص بالكلاس يتم حذف جميع البيانات
    _ttsService.dispose(); // استدعاء فنكشن التدمير للكلاس الخاص بلفظ النص
    super.dispose(); // فنكشن خاص باغلاق الكلاس
  }
}
