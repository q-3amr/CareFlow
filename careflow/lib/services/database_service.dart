import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../models/user.dart';
import '../models/appointment.dart';
import '../utils/date_utils.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/message.dart';

class DatabaseService {
  final FirebaseMessaging? _customFcm;
  final FirebaseFirestore _db;

  DatabaseService({FirebaseFirestore? firestore, FirebaseMessaging? fcm})
      : _db = firestore ?? FirebaseFirestore.instance,
        _customFcm = fcm;

  FirebaseMessaging get _fcm => _customFcm ?? FirebaseMessaging.instance;

  Stream<List<UserModel>> streamDoctors() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'doctor')
        .where('isVerified', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => UserModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<UserModel?> getUserById(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    if (doc.exists) return UserModel.fromMap(doc.data()!, doc.id);
    return null;
  }

  Future updateToken(String uid) async {
    final token = await _fcm.getToken(); // جلب الـ FCM Token الحالي
    if (token != null) { // لا تحفظ null في Firestore حتى لا تُلغي التوكن السابق
      await _db.collection("users").doc(uid).update({
        "pushToken": token,
      });
    }
  }

  Future<String> getToken(String uid) async {
    final doc = await _db.collection("users").doc(uid).get();
    if (doc.exists) {
      return doc.get("pushToken") ?? "";
    }
    return "";
  }

  Stream<UserModel?> streamUser(String userId) { // فنكشن يستمع لبيانات المستخدم بشكل مباشر. أي تغيير يحدث في قاعدة البيانات سيظهر تلقائياً على الشاشة
    return _db.collection('users').doc(userId).snapshots() // اشترك في تحديثات مستند المستخدم (كل تغيير يصدر حدثاً جديداً في الستريم)
        .map((doc) { // حوّل كل حدث جديد من النوع الخام إلى نموذج UserModel يفهمه التطبيق
      if (doc.exists) return UserModel.fromMap(doc.data()!, doc.id); // إذا وُجد المستخدم، حوّل بياناته إلى نموذج UserModel
      return null; // إذا لم يوجد المستخدم في قاعدة البيانات، أرجع null
    });
  }

  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    await _db.collection('users').doc(userId).update(data);
  }

  Future<void> deleteUser(String userId) async {
    await _db.collection('users').doc(userId).delete();
  }

  Future<void> submitAppointmentFeedback({ // فنكشن حفظ تقييم المريض على موعده بعد الانتهاء
    required String appointmentId, // رقم الموعد الذي يريد المريض تقييمه (مطلوب إدخاله)
    required String feedbackText, // نص التعليق الذي كتبه المريض (مطلوب إدخاله)
    required double rating, // التقييم رقمياً من 1 إلى 5 نجوم (مطلوب إدخاله)
  }) async {
    await _db.collection('appointments').doc(appointmentId).update({ // حدّث بيانات الموعد في قاعدة البيانات
      'hasFeedback': true, // علّم أن هذا الموعد عنده تقييم لكي يظهر في شاشة الطبيب
      'feedback_text': feedbackText, // احفظ نص التعليق الذي كتبه المريض
      'rating': rating, // احفظ عدد النجوم
      'isReviewSeen': false, // اضبطه كغير مقروء حتى يظهر تنبيه جديد للطبيب
    });
  }

  Future<void> updateDoctorAggregateRating(String doctorId) async {
    final snapshot = await _db
        .collection('appointments')
        .where('doctor_id', isEqualTo: doctorId)
        .where('hasFeedback', isEqualTo: true)
        .get();

    if (snapshot.docs.isEmpty) return;

    final ratings = snapshot.docs
        .map((d) => d.data()['rating'])
        .where((r) => r != null)
        .map((r) => (r as num).toDouble())
        .toList();

    if (ratings.isEmpty) return;

    final double average = ratings.reduce((a, b) => a + b) / ratings.length;

    await _db.collection('users').doc(doctorId).update({
      'rating': double.parse(average.toStringAsFixed(1)),
      'reviewCount': ratings.length,
    });
  }

  Stream<QuerySnapshot> streamReviewsForDoctor(String doctorId) { // فنكشن يبث تقييمات الطبيب بشكل مباشر. أي تقييم جديد سيظهر تلقائياً في شاشة الطبيب
    return _db
        .collection('appointments') // ابحث في جدول المواعيد
        .where('doctor_id', isEqualTo: doctorId) // فلتر: فقط مواعيد هذا الطبيب تحديداً
        .where('hasFeedback', isEqualTo: true) // فلتر: فقط المواعيد التي ترك فيها المريض تقييماً
        .snapshots(); // اشترك في التحديثات المباشرة (بدلاً من .get() التي تجلب مرة واحدة فقط)
  }

  Future<void> markAllReviewsAsSeen(String doctorId) async { // فنكشن لتحويل كل التقييمات الجديدة إلى "مقروءة" (لإخفاء الدائرة الحمراء من الشاشة)
    // أولاً: جلب كل المواعيد الخاصة بهذا الطبيب والتي تحتوي على تقييم
    final querySnapshot = await _db
        .collection('appointments')
        .where('doctor_id', isEqualTo: doctorId)
        .where('hasFeedback', isEqualTo: true)
        .get();

    // ثانياً: استخدام "Batch" (حزمة التحديثات). الباتش يسمح لنا بتعديل عدة مستندات في نفس اللحظة بخطوة واحدة بدلاً من تعديل كل واحد لوحده (أسرع وأوفر)
    WriteBatch batch = _db.batch();
    bool hasUpdates = false; // متغير لمعرفة هل وجدنا تقييمات جديدة تحتاج تغيير أم لا

    for (var doc in querySnapshot.docs) { // المرور على كل التقييمات
      final data = doc.data();
      if (data['isReviewSeen'] != true) { // إذا كان التقييم "غير مقروء"
        batch.update(doc.reference, {'isReviewSeen': true}); // أضف أمر "اجعله مقروءاً" إلى الحزمة
        hasUpdates = true; // نعم، وجدنا شيئاً لتحديثه
      }
    }
    // ثالثاً: تنفيذ التحديث
    if (hasUpdates) await batch.commit(); // أرسل الحزمة كلها لقاعدة البيانات للتنفيذ دفعة واحدة (إذا كان هناك ما يستحق التحديث)
  }

  Stream<QuerySnapshot> streamAppointmentsForDoctor(String doctorId) {
    return _db
        .collection('appointments')
        .where('doctor_id', isEqualTo: doctorId)
        .snapshots();
  }

  Stream<QuerySnapshot> streamPendingAppointments(String doctorId) {
    return _db
        .collection('appointments')
        .where('doctor_id', isEqualTo: doctorId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Stream<QuerySnapshot> streamAcceptedAppointmentsForPatient(String patientId) {
    return _db
        .collection('appointments')
        .where('patient_id', isEqualTo: patientId)
        .where('status', isEqualTo: 'accepted')
        .snapshots();
  }

  Stream<QuerySnapshot> streamUserAppointments(
    String userId, {
    required bool isDoctor,
  }) {
    return _db
        .collection('appointments')
        .where(isDoctor ? 'doctor_id' : 'patient_id', isEqualTo: userId)
        .snapshots();
  }

  Future<QuerySnapshot> getAppointmentsForDoctor(String doctorId) {
    return _db
        .collection('appointments')
        .where('doctor_id', isEqualTo: doctorId)
        .get();
  }

  Future<QuerySnapshot> getAppointmentsForDoctorByStatuses(
    String doctorId,
    List<String> statuses,
  ) {
    return _db
        .collection('appointments')
        .where('doctor_id', isEqualTo: doctorId)
        .where('status', whereIn: statuses)
        .get();
  }

  Future<String?> bookAppointmentSafely(AppointmentModel appointment) async { // فنكشن لحجز الموعد بطريقة آمنة تمنع الحجز المزدوج (شخصين يحجزون نفس الوقت)
    // نصنع مفتاح فريد لهذا الموعد مكوّن من رقم الطبيب والتوقيت
    final String appointmentKey =
        "${appointment.doctorId}_${appointment.appointmentDateTime.millisecondsSinceEpoch}";

    // مرجع لوثيقة في جدول "المواعيد المحجوزة" (جدول مخصص فقط لمنع التضارب)
    final txRef = _db.collection('booked_slots').doc(appointmentKey);

    try {
      // نستخدم "Transaction" (عملية موحدة): وهي تقنية تضمن أنه إذا حاول شخصان الحجز في نفس اللحظة بالثانية، واحد فقط سينجح!
      final isBooked = await _db.runTransaction<bool>((transaction) async {
        final snapshot = await transaction.get(txRef); // نقرأ الموعد من قاعدة البيانات لنتأكد أنه ليس محجوزاً مسبقاً

        if (snapshot.exists) { // إذا وجدنا المستند موجوداً، هذا يعني أن شخصاً آخر سبقنا للتو وحجز هذا الوقت
          return true; // true تعني: "نعم، الوقت أصبح محجوزاً"
        }

        // إذا وصلنا لهنا، فالموعد متاح! نقوم بحجزه فوراً في جدول "booked_slots" لكي لا يأخذه غيرنا
        transaction.set(txRef, {
          'bookedBy': appointment.patientId, // من حجز الموعد
          'timestamp': FieldValue.serverTimestamp(), // متى تم الحجز
        });

        // بعد أن حجزنا الوقت بنجاح (وضعنا يدنا عليه)، نقوم بإنشاء الموعد الفعلي بكل تفاصيله في جدول "المواعيد" الأساسي
        final newApptDoc = _db.collection('appointments').doc();
        transaction.set(newApptDoc, {
          'id': newApptDoc.id,
          'doctor_id': appointment.doctorId,
          'doctor_name': appointment.doctorName,
          'patient_id': appointment.patientId,
          'patient_name': appointment.patientName,
          'appointmentDateTime':
              Timestamp.fromDate(appointment.appointmentDateTime),
          'status': 'pending', // حالة الموعد معلقة بانتظار رد الطبيب
          'hasFeedback': false,
          'isReviewSeen': false,
        });

        return false; // false تعني: "الوقت لم يكن محجوزاً من قبلنا، ونجحنا نحن في حجزه"
      });

      if (isBooked) {
        return 'Sorry, this slot was just booked by someone else!'; // رسالة تظهر للمستخدم إذا فشل الحجز بسبب التضارب
      } else {
        return null; // الحجز نجح (لا توجد أخطاء)
      }
    } catch (e) {
      return 'Transaction failed: $e'; // حدث خطأ غير متوقع في الاتصال أو قاعدة البيانات
    }
  }

  Future<void> updateAppointmentStatus( // فنكشن لتحديث حالة الموعد (مقبول، مرفوض، ملغى، مكتمل)
    String docId, // رقم الموعد في قاعدة البيانات
    String status, { // الحالة الجديدة للموعد
    String? cancelledBy, // اختياري: من الذي ألغى الموعد (المريض أم الطبيب؟) مفيد في حالة الرفض أو الإلغاء
  }) async {
    final Map<String, dynamic> data = {'status': status}; // تجهيز البيانات التي سنقوم بتحديثها
    if (cancelledBy != null) {
      data['cancelledBy'] = cancelledBy; // إذا تم تحديد من ألغى الموعد، أضفه للبيانات
    }

    // جزء مهم جداً: إذا تم إلغاء الموعد أو رفضه، يجب أن نحذف "القفل" من جدول booked_slots لكي يصبح الوقت متاحاً للحجز مرة أخرى!
    if (status == 'cancelled' || status == 'rejected') {
      try {
        final docSnap = await _db.collection('appointments').doc(docId).get(); // أولاً: اجلب بيانات الموعد لمعرفة وقت الطبيب
        if (docSnap.exists) {
          final apptData = docSnap.data() as Map<String, dynamic>;
          final doctorId = apptData['doctor_id']; // استخرج رقم الطبيب
          final Timestamp? timestamp = apptData['appointmentDateTime']; // استخرج وقت الموعد
          if (doctorId != null && timestamp != null) {
            final int millis = timestamp.millisecondsSinceEpoch; // حوّل الوقت إلى ملي ثانية (نفس الطريقة التي أنشأنا بها القفل)
            final String slotKey = "${doctorId}_$millis"; // أعد بناء اسم القفل المطابق لهذا الموعد
            await _db.collection('booked_slots').doc(slotKey).delete(); // احذف القفل من قاعدة البيانات! الآن الوقت أصبح متاحاً للآخرين
            debugPrint("Released booked slot: $slotKey"); // طباعة رسالة للمبرمج في الكونسول لتأكيد نجاح العملية
          }
        }
      } catch (e) {
        debugPrint("Error releasing booked slot: $e"); // طباعة الخطأ إذا فشل حذف القفل
      }
    }

    // أخيراً: بعد التعامل مع القفل، قم بتحديث حالة الموعد في الجدول الأساسي
    await _db.collection('appointments').doc(docId).update(data);
  }

  Future<void> deleteAppointment(String docId) async {
    await _db.collection('appointments').doc(docId).delete();
  }

  Future<DocumentSnapshot> getAvailability(String doctorId, String dateKey) {
    return _db
        .collection('users')
        .doc(doctorId)
        .collection('availability')
        .doc(dateKey)
        .get();
  }

  Future<void> saveSlots(
      String doctorId, String dateKey, List<String> slots) async {
    await _db
        .collection('users')
        .doc(doctorId)
        .collection('availability')
        .doc(dateKey)
        .set({'slots': slots}, SetOptions(merge: true));
  }

  Stream<QuerySnapshot> streamChats(String userId) {
    return _db
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots();
  }

  Stream<QuerySnapshot> streamMessages(String chatRoomId) {
    return _db
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> sendMessage(
      String chatRoomId, Map<String, dynamic> messageData) async {
    await _db
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .add(messageData);
  }

  Future<void> updateChatRoom(
      String chatRoomId, Map<String, dynamic> data) async {
    await _db
        .collection('chats')
        .doc(chatRoomId)
        .set(data, SetOptions(merge: true));
  }

  Stream<List<UserModel>> streamUnverifiedDoctors() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'doctor')
        .where('isVerified', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> approveDoctor(String doctorId) async {
    await _db.collection('users').doc(doctorId).update({'isVerified': true});
  }

  Future<void> updateNotificationToken(String userId) async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _db
            .collection('users')
            .doc(userId)
            .set({'pushToken': token}, SetOptions(merge: true));
        debugPrint("FCM token updated in Firestore for user: $userId");
      }
    } catch (e) {
      debugPrint("Error updating notification token: $e");
    }
  }

  Future<String> searchDoctorsForAi(String specialty, String sortBy,
      {double? userLat, double? userLng}) async { // فنكشن البحث عن الأطباء للذكاء الاصطناعي. تأخذ التخصص وطريقة الترتيب، واختيارياً موقع المريض (GPS)
    try {
      // بناء استعلام لقاعدة البيانات: اجلب المستخدمين ذوي دور "طبيب" وتخصص محدد
      Query query = FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'doctor')
          .where('specialty', isEqualTo: specialty);

      QuerySnapshot snapshot = await query.get(); // نفذ الاستعلام وانتظر النتائج من قاعدة البيانات

      if (snapshot.docs.isEmpty) { // إذا لم يوجد أي طبيب بهذا التخصص نهائياً
        return jsonEncode({
          "success": false,
          "message": "No doctors found for this specialty in the database."
        });
      }

      List<Map<String, dynamic>> doctorsList = []; // قائمة فارغة سيتم تعبئتها ببيانات الأطباء المؤهلين

      for (var doc in snapshot.docs) { // دور على كل طبيب وجدناه في نتائج البحث
        final data = doc.data() as Map<String, dynamic>;

        if (data['isVerified'] != true) continue; // تجاهل الطبيب إذا لم يتم التحقق من هويته بعد

        double docLat = (data['latitude'] ?? data['lat'] ?? 0.0).toDouble(); // جلب خط العرض لموقع عيادة الطبيب
        double docLng = (data['longitude'] ?? data['lng'] ?? 0.0).toDouble(); // جلب خط الطول لموقع عيادة الطبيب
        double distanceInMeters = 0.0; // المسافة افتراضياً صفر، ستُحسب لاحقاً إذا طلب الذكاء الاصطناعي الأقرب

        if (sortBy == "nearest" && userLat != null && userLng != null) { // فقط احسب المسافة إذا كان المريض يبحث عن الأقرب وكان موقعه متاحاً
          if (docLat == 0.0 && docLng == 0.0) continue; // تجاهل أي طبيب لم يسجل موقع عيادته في قاعدة البيانات
          distanceInMeters =
              Geolocator.distanceBetween(userLat, userLng, docLat, docLng); // احسب المسافة بالمتر بين موقع المريض وموقع عيادة الطبيب
        }

        // جلب تقييم الطبيب. نجرب عدة أسماء للحقل لأن قواعد بيانات مختلفة قد تستخدم أسماء مختلفة لنفس الحقل
        var rawRating = data['rating'] ??
            data['rating'] ??
            data['Rating'] ??
            data['rate'] ??
            0.0;
        double doctorRating = double.tryParse(rawRating.toString()) ?? 0.0; // حوّل التقييم إلى رقم عشري، إذا فشل التحويل فستخدم صفر افتراضياً

        // بناء بيانات الطبيب التي ستُرسل للذكاء الاصطناعي
        Map<String, dynamic> doctorInfo = {
          "doctor_id": doc.id, // الرقم التعريفي الفريد للطبيب في قاعدة البيانات
          "name": data['name'] ?? "Unknown", // اسم الطبيب
          "rating": doctorRating, // تقييمه العام
          "reviews_count": data['reviewCount'] ?? data['reviews_count'] ?? 0, // عدد التقييمات التي حصل عليها
        };

        if (sortBy == "nearest") { // أضف المسافة فقط إذا كان البحث بطريقة "الأقرب"
          doctorInfo["distance_in_km"] =
              double.parse((distanceInMeters / 1000).toStringAsFixed(1)); // حوّل المسافة من متر إلى كيلومتر واحتفظ بخانة عشرية واحدة فقط
        }

        doctorsList.add(doctorInfo); // أضف بيانات هذا الطبيب إلى قائمة النتائج النهائية
      }
      if (doctorsList.isEmpty) { // إذا كانت القائمة فارغة (وجد أطباء لكن لا أحد منهم معتمد أو ليس لديهم موقع محدد)
        if (sortBy == "nearest") {
          return jsonEncode({
            "success": false,
            "message":
                "There are doctors for this specialty, but NONE of them have their clinic location (GPS) saved in the database. Tell the user exactly: 'I cannot find the nearest doctor because no doctors in this specialty have registered their locations yet.'"
          });
        } else {
          return jsonEncode({
            "success": false,
            "message": "No verified doctors found for this specialty."
          });
        }
      }
      if (sortBy == "rating") { // إذا طلب الترتيب حسب التقييم، رتب القائمة تنازلياً (الأعلى أولاً)
        doctorsList
            .sort((a, b) => (b['rating'] as num).compareTo(a['rating'] as num));
      } else if (sortBy == "nearest") { // إذا طلب الترتيب حسب المسافة، رتب تصاعدياً (الأقرب أولاً)
        doctorsList.sort((a, b) => (a['distance_in_km'] as double)
            .compareTo(b['distance_in_km'] as double));
      }

      return jsonEncode(
          {"success": true, "doctors_found": doctorsList.take(4).toList()}); // أرسل أفضل 4 أطباء فقط (take(4)) حتى لا ينتج الذكاء الاصطناعي رداً طويلاً جداً
    } catch (e) {
      return jsonEncode({"error": "Database error occurred: $e"}); // إذا حدث خطأ غير متوقع، أرسل رسالة خطأ واضحة للذكاء الاصطناعي
    }
  }

  Future<String> getDoctorAvailabilityForAi(
      String doctorId, String date) async { // فنكشن جلب المواعيد المتاحة لطبيب معين في تاريخ محدد
    try {
      DateTime parsedDate = DateTime.parse(date); // حوّل التاريخ من نص ("2026-06-22") إلى كائن DateTime نستطيع العمل عليه برمجياً
      // تنسيق التاريخ بالصيغة التي تستخدمها قاعدة البيانات داخلياً (بدون أصفار للشهر واليوم)
      String firestoreDate =
          "${parsedDate.year}-${parsedDate.month}-${parsedDate.day}";

      // الذهاب إلى قاعدة البيانات وجلب جدول عمل الطبيب لهذا اليوم تحديداً
      DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(doctorId) // ملف الطبيب
          .collection('availability') // مجلد جداول العمل
          .doc(firestoreDate) // ملف التاريخ المحدد
          .get();

      if (!docSnapshot.exists) { // إذا لم يضع الطبيب جدول عمل لهذا اليوم أصلاً
        return jsonEncode({
          "success": true,
          "message": "The doctor has no working hours configured for today.",
          "available_slots": [] // أرجع قائمة فارغة للذكاء الاصطناعي ليخبر المريض
        });
      }

      final data = docSnapshot.data() as Map<String, dynamic>;
      // اجلب قائمة المواعيد. نجرب عدة أسماء للحقل لأن الطبيب قد يخزنها بأي اسم منها
      List<dynamic> allSlots =
          data['slots'] ?? data['time_slots'] ?? data['available_slots'] ?? [];

      if (allSlots.isEmpty) { // إذا وُجد الملف لكن لا توجد مواعيد بداخله
        return jsonEncode({
          "success": true,
          "message": "The doctor has no working hours configured.",
          "available_slots": []
        });
      }

      // جلب المواعيد المحجوزة بالفعل لهذا الطبيب في نفس اليوم (المعلقة أو المقبولة)
      QuerySnapshot appointments = await FirebaseFirestore.instance
          .collection('appointments')
          .where('doctor_id', isEqualTo: doctorId)
          .where('status', whereIn: ['pending', 'accepted']).get();

      // استخراج أوقات المواعيد المحجوزة فقط في نفس التاريخ المطلوب
      List<String> bookedTimes = [];
      for (var doc in appointments.docs) {
        final apptData = doc.data() as Map<String, dynamic>;
        final rawDate = apptData['appointmentDateTime'];
        if (rawDate == null) continue; // تجاهل أي موعد ليس له تاريخ
        final DateTime apptDt = (rawDate as Timestamp).toDate(); // حوّل التوقيت الخام إلى DateTime
        if (apptDt.year == parsedDate.year &&
            apptDt.month == parsedDate.month &&
            apptDt.day == parsedDate.day) { // تحقق أن الموعد في نفس اليوم المطلوب
          bookedTimes.add(formatTimeFromDateTime(apptDt)); // أضف وقت هذا الموعد إلى قائمة المحجوزة
        }
      }

      List<String> availableTimes = []; // قائمة فارغة سيتم تعبئتها بالمواعيد غير المحجوزة
      DateTime now = DateTime.now();

      // تحقق ما إذا كان التاريخ المطلوب هو اليوم (لإخفاء المواعيد التي مضت بالفعل)
      bool isToday = parsedDate.year == now.year &&
          parsedDate.month == now.month &&
          parsedDate.day == now.day;

      for (String slot in allSlots) { // دور على كل وقت في جدول الطبيب
        if (!bookedTimes.contains(slot)) { // تحقق أن هذا الوقت ليس محجوزاً
          if (isToday) { // إذا كان اليوم، تحقق أيضاً أن الوقت لم يمر بعد
            try {
              // تحليل الوقت النصي ("10:00 PM") وتحويله إلى ساعات ودقائق
              final parts = slot.split(' ');
              final timeParts = parts[0].split(':');
              int hour = int.parse(timeParts[0]);
              int minute = int.parse(timeParts[1]);

              if (parts.length > 1) {
                if (parts[1].toUpperCase() == 'PM' && hour != 12) hour += 12; // تحويل من نظام 12 إلى 24 ساعة (مساءاً)
                if (parts[1].toUpperCase() == 'AM' && hour == 12) hour = 0; // تحويل من نظام 12 إلى 24 ساعة (صباحاً)
              }

              final slotTime = DateTime(parsedDate.year, parsedDate.month,
                  parsedDate.day, hour, minute); // بناء كائن وقت كامل من التاريخ والساعة
              if (slotTime.isBefore(now)) {
                continue; // تجاهل هذا الوقت إذا كان قد مضى فعلاً
              }
            } catch (_) {}
          }
          availableTimes.add(slot); // أضف هذا الوقت إلى قائمة المواعيد المتاحة
        }
      }

      return jsonEncode(
          {"success": true, "date": date, "available_slots": availableTimes}); // أرجع التاريخ وقائمة المواعيد المتاحة للذكاء الاصطناعي
    } catch (e) {
      return jsonEncode(
          {"error": "Database error while fetching availability: $e"}); // إذا حدث خطأ غير متوقع أرسل رسالة خطأ للذكاء الاصطناعي
    }
  }

  Future<String> bookAppointmentForAi(
      String doctorId, String date, String time) async { // فنكشن حجز الموعد عن طريق الذكاء الاصطناعي. تأخذ رقم الطبيب والتاريخ والوقت
    try {
      final String? patientId = FirebaseAuth.instance.currentUser?.uid; // جلب رقم المريض المسجل دخوله حالياً
      if (patientId == null) { // إذا لم يكن هناك مستخدم مسجل الدخول، أوقف الحجز
        return jsonEncode(
            {"error": "User is not logged in. Cannot book appointment."});
      }

      // جلب اسم المريض من قاعدة البيانات لحفظه في الموعد
      DocumentSnapshot patientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .get();
      String patientName = "Unknown"; // اسم افتراضي إذا لم نجد الاسم في قاعدة البيانات
      if (patientDoc.exists) {
        final pData = patientDoc.data() as Map<String, dynamic>;
        patientName = pData['name'] ?? pData['fullName'] ?? "Unknown"; // جرب اسمين مختلفين لنفس الحقل
      }

      // جلب اسم الطبيب من قاعدة البيانات لحفظه في الموعد
      DocumentSnapshot doctorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(doctorId)
          .get();
      String doctorName = "Doctor"; // اسم افتراضي إذا لم نجد الاسم في قاعدة البيانات
      if (doctorDoc.exists) {
        final dData = doctorDoc.data() as Map<String, dynamic>;
        doctorName = dData['name'] ?? dData['fullName'] ?? "Doctor"; // جرب اسمين مختلفين لنفس الحقل
      }

      DateTime parsedDate = DateTime.parse(date); // حوّل التاريخ من نص إلى DateTime

      // دمج التاريخ والوقت معاً في كائن DateTime واحد كامل
      DateTime appointmentDateTime = parsedDate; // قيمة افتراضية قبل تحليل الوقت
      try {
        final parts = time.trim().split(' '); // افصل الوقت عن AM/PM
        final timeParts = parts[0].split(':'); // افصل الساعات عن الدقائق
        int hour = int.parse(timeParts[0]);
        int minute = int.parse(timeParts[1]);
        if (parts.length > 1) {
          if (parts[1].toUpperCase() == 'PM' && hour != 12) hour += 12; // تحويل من نظام 12 إلى 24 ساعة (مساءاً)
          if (parts[1].toUpperCase() == 'AM' && hour == 12) hour = 0; // تحويل من نظام 12 إلى 24 ساعة (صباحاً)
        }
        appointmentDateTime = DateTime(
            parsedDate.year, parsedDate.month, parsedDate.day, hour, minute); // بناء كائن وقت كامل يجمع التاريخ والساعة
      } catch (_) {}

      // التحقق من عدم وجود تضارب (شخص آخر حجز نفس الوقت)
      QuerySnapshot checkConflict = await FirebaseFirestore.instance
          .collection('appointments')
          .where('doctor_id', isEqualTo: doctorId)
          .where('status', whereIn: ['pending', 'accepted']).get();

      // ابحث في المواعيد المحجوزة إذا كان هناك موعد بنفس التاريخ والساعة والدقيقة
      final bool alreadyBooked = checkConflict.docs.any((doc) {
        final d = doc.data() as Map<String, dynamic>;
        final rawDate = d['appointmentDateTime'];
        if (rawDate == null) return false;
        final DateTime existing = (rawDate as Timestamp).toDate();
        return existing.year == appointmentDateTime.year &&
            existing.month == appointmentDateTime.month &&
            existing.day == appointmentDateTime.day &&
            existing.hour == appointmentDateTime.hour &&
            existing.minute == appointmentDateTime.minute; // مطابقة كاملة للسنة والشهر واليوم والساعة والدقيقة
      });

      if (alreadyBooked) { // إذا كان الوقت محجوزاً، أخبر الذكاء الاصطناعي ليخبر المريض باختيار وقت آخر
        return jsonEncode({
          "success": false,
          "error":
              "CRITICAL: This exact time slot ($time) was just booked by someone else! Tell the user to choose another time from the available slots."
        });
      }

      // إنشاء رقم تعريفي فريد للموعد باستخدام رقم الطبيب والتوقيت بالميليثانية لضمان عدم التكرار
      final String slotId =
          "appt_${doctorId}_${appointmentDateTime.millisecondsSinceEpoch}";
      // أضف الموعد إلى قاعدة البيانات
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(slotId) // استخدام الرقم التعريفي كاسم للوثيقة بدلاً من توليده عشوائياً
          .set({
        'doctor_id': doctorId, // رقم الطبيب
        'doctor_name': doctorName, // اسم الطبيب
        'patient_id': patientId, // رقم المريض
        'patient_name': patientName, // اسم المريض
        'appointmentDateTime': Timestamp.fromDate(appointmentDateTime), // التاريخ والوقت كاملين
        'status': 'pending', // حالة الموعد افتراضياً هي معلقة حتى يقبل الطبيب
        'hasFeedback': false, // لم يترك المريض تقييماً بعد
        'isReviewSeen': false, // لم يرى الطبيب التقييم بعد
        'created_at': FieldValue.serverTimestamp(), // توقيت إنشاء الموعد يؤخذه من خادم فايربيس مباشرة
      });

      // إرسال إشعار للطبيب بأن هناك طلب حجز جديد
      try {
        final token = await getToken(doctorId); // جلب رقم جهاز الطبيب لإرسال الإشعار
        if (token.isNotEmpty) {
          MessageServices().sendNotificationToUser(
            fcmToken: token,
            title: 'New Appointment Request',
            body: '$patientName requested an appointment on $date at $time',
            type: 'appointment',
          );
        }
      } catch (e) {
        debugPrint('Failed to send notification for AI booking: $e'); // لا نوقف الحجز إذا فشل الإشعار، فقط نسجل الخطأ
      }

      return jsonEncode({
        "success": true,
        "message":
            "Appointment successfully booked for $date at $time. Tell the user their appointment is now PENDING doctor approval." // أخبر الذكاء الاصطناعي أن الحجز نجح وأن يخبر المريض
      });
    } catch (e) {
      return jsonEncode(
          {"error": "Database error while booking the appointment: $e"}); // إذا حدث خطأ غير متوقع
    }
  }
}
