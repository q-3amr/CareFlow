import 'package:speech_to_text/speech_to_text.dart';

// الكلاس الخاص بتحويل الحكي لنص
// بستخدم مكتبة speech_to_text مشان يحول الحكي لنص
class SpeechService {
  final SpeechToText _stt =
      SpeechToText(); // بعمل اوبجكت من المكتبه مشان استخدمها

  bool _isAvailable =
      false; // متغير مشان اتاكد اذا الخدمة اشتغلت او لا الخاصة بالمايك

  bool get isListening =>
      _stt.isListening; // فنكشن برجع صح او خطا حيث بتاكد انو المايك قاعد بستمع
  bool get isAvailable =>
      _isAvailable; // فنكشن برجع قيمة المتغير المعرف بالاعلى

  Future<bool> initialize() async {
    // فنكشن بتم استدعاء عند انشاء اوبجكت من الكلاس
    _isAvailable = await _stt.initialize(
      // هون بتسدعي الانشاء الخاص الاوبجكت المعرف بالاعلى واستدعاء فنكشن معرف داخل المكتبه كمان بسند القيمة للمتغير
      onError: (error) => print(
          'STT error: $error'), // في حال لم يتم تعريف المتغير يطبع رسالة المشكلة
    );
    return _isAvailable; // ارجاع قيمة المتغير
  }

  Future<void> startListening({
    // فنكشن بداية الاستماع بستقبل مغيرين و هم فنكشن مشان يتعرف على الكلمات  و الثاني مشان يحكي خلص الاستماع
    required void Function(String words) onResult,
    required void Function() onDone,
  }) async {
    if (!_isAvailable)
      await initialize(); // بتاكد اذا تم تعريف المتغير اذا لا استدعي فنكشن initialize
    await _stt.listen(
      // بتسخدم فنكشن الاستماع الخاص بالاوبجكت المعرف مشان يبلش يستمع
      onResult: (result) {
        // عند التحليل برجع نتيجة
        if (result.finalResult) {
          // اذا عرف الكلمة المستمع الها برجع true واذا لا false
          onResult(
              result.recognizedWords); // استدعاء الفنكشن المرسل وارسال الكلمة
          onDone(); // انو خلص الكلمة
        }
      },
      listenFor: const Duration(seconds: 30), // مدة الاستماع
      pauseFor: const Duration(seconds: 3), // بعمل pause كل ثلث ثواني
    );
  }

  Future<void> stopListening() async {
    // فنكشن ايقاف الاستماع
    await _stt.stop(); // بتم استدعاء فنكشن الايقاف عن طريق الاوبجكت
  }

  Future<void> cancel() async {
    // فنكشن لغاء الاستماع حيث يتم اغلاق الاوبجكت كامل
    await _stt.cancel(); // بتم استدعاء فنكشن الالغاء عن طريق الاوبجكت
  }
}
