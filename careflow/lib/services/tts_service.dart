import 'package:flutter_tts/flutter_tts.dart';

// الكلاس الخاص بتحويل النص لحكي
// بستخدم مكتبة flutter_tts مشان يحول الحكي لنص
class TtsService {
  final FlutterTts _tts = FlutterTts(); // بعمل اوبجكت من المكتبه مشان استخدمها

  bool _isSpeaking = false; // متغير بستخدموا مشان اتاكد اذا الشخص بحكي او لا

  Future<void> initialize() async {
    // فنكشن بتم استدعاء عند انشاء اوبجكت من الكلاس

    final languages = await _tts.getLanguages
        as List?; // بتم انشاء متغير مشان اجيب اللغات واخزنها فيه حيث اللغات رح تكون عربي وانكليزي
    final hasArabic =
        languages?.any((l) => l.toString().toLowerCase().contains('ar')) ??
            false; // بتم انشاء متغير بحيث يتاكد اذا بحتوي على نص عربي او لا

    if (hasArabic) {
      // اذا بحتوي على نص عربي
      await _tts.setLanguage('ar-SA'); // هون بحول لغة النص للعربي
    } else {
      await _tts.setLanguage('en-US'); // هون بحول لغة النص للانكليزي
    }

    await _tts.setSpeechRate(0.45); // بحدد هون سرعة الحكي
    await _tts.setVolume(1.0); // بحدد هون درجة صوت للحكي
    await _tts.setPitch(1.0); // بحدد نبرة الصوت

    _tts.setStartHandler(
        () => _isSpeaking = true); // يتم استدعاء عند يبلش الحكي
    _tts.setCompletionHandler(
        () => _isSpeaking = false); // يتم استدعاء عند انتهاء الحكي بالكامل
    _tts.setErrorHandler(
        (msg) => _isSpeaking = false); // يتم استدعاء إذا صار خطا خلال الحكي
  }

  bool get isSpeaking => _isSpeaking; // فنكشن برجع قيمة المتغير

  Future<void> speak(String text) async {
    // فنكشن لفظ الكلمة الواحد حيث يتم ارسال اكثر من جمله
    if (text.trim().isEmpty) return; // اذا النص فاضي لا تعمل اشي

    final isArabic = RegExp(r'[\u0600-\u06FF]')
        .hasMatch(text); // تحديد الكلمة عربية او لا عن طريق regexp
    if (isArabic) {
      // اذا الجملة عربية
      await _tts.setLanguage('ar-SA'); // حول اللغة عربية
    } else {
      // اذا لا
      await _tts.setLanguage('en-US'); // حول اللغة انكليزية
    }

    await _tts.speak(text); // فنكشن معرف داخل الاوبجكت مشان يلفظ الجملة
  }

  Future<void> stop() async {
    // فنكشن الايقاف
    await _tts.stop(); // بتم استدعاء فنكشن الايقاف من الاوبجكت
    _isSpeaking = false; // حول قيمة ل false للمتغير
  }

  Future<void> dispose() async {
    // فنكشن اغلاق الكلاس
    await _tts.stop(); // بتم استدعاء فنكشن الايقاف من الاوبجكت
  }
}
