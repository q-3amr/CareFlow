import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/star_rating_widget.dart';

class DoctorReviewsScreen extends StatefulWidget {
  const DoctorReviewsScreen({super.key});

  @override
  State<DoctorReviewsScreen> createState() => _DoctorReviewsScreenState();
}

class _DoctorReviewsScreenState extends State<DoctorReviewsScreen> {
  @override
  void initState() {
    super.initState();

    _markReviewsAsSeen();
  }

  void _markReviewsAsSeen() async {
    // هاي الدالة هي المسؤولة عن إخفاء تنبيهات "التقييمات الجديدة"
    final uid = FirebaseAuth.instance.currentUser?.uid;
    // التحقق من وجود مستخدم مسجل الدخول، إذا لم يوجد يتم الخروج من الدالة
    if (uid == null) return;

    try {
      // جلب جميع المواعيد الخاصة بالطبيب الحالي
      final querySnapshot = await FirebaseFirestore.instance
          .collection('appointments') //من جدول المواعيد
          .where('doctor_id', isEqualTo: uid)
          .get();

      // استخدام WriteBatch لتحديث عدة مستندات في قاعدة البيانات في نفس الوقت (لتحسين الأداء)
      WriteBatch batch = FirebaseFirestore.instance.batch();
      bool hasUpdates = false;

      for (var doc in querySnapshot.docs) {
        final data = doc.data();

        if (data['hasFeedback'] == true && data['isReviewSeen'] != true) {
          //وبتدور على كل المواعيد اللي المريض ترك فيها تقييم لكن الدكتور لسا ما شافها
          batch.update(doc.reference, {'isReviewSeen': true}); //يخليه seen
          hasUpdates = true; //علشان نحدث الشاشة
        }
      }

      // إذا كان هناك تقييمات جديدة لم تُرَ من قبل، نقوم بتنفيذ التحديثات
      if (hasUpdates) {
        await batch.commit();

        // تحديث واجهة المستخدم بعد تغيير حالة التقييمات إلى مقروءة
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint("Error updating reviews status: $e");
    }
  }

  Widget _buildAggregateSummary(List<QueryDocumentSnapshot> docs) {
    // إذا لم تكن هناك تقييمات، لا تعرض شيئًا
    if (docs.isEmpty) return const SizedBox.shrink();

    // استخراج جميع التقييمات الرقمية وتجاهل القيم الفارغة
    final ratings = docs
        .map((d) => (d.data() as Map<String, dynamic>)['rating'])
        .where((r) => r != null)
        .map((r) => (r as num).toDouble())
        .toList();

    if (ratings.isEmpty) return const SizedBox.shrink();

    // حساب متوسط التقييمات وعددها الإجمالي
    final double average = ratings.reduce((a, b) => a + b) / ratings.length;
    final int count = ratings.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF407CE2), Color(0xFF6FA0FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF407CE2).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            average.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 52,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StarRatingWidget(
                initialRating: average,
                starSize: 22,
                isReadOnly: true,
              ),
              const SizedBox(height: 6),
              Text(
                '$count ${count == 1 ? 'Review' : 'Reviews'}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('Patient Reviews',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      // الاستماع المباشر (Real-time) للتقييمات الخاصة بالطبيب
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .where('doctor_id', isEqualTo: uid)
            .where('hasFeedback', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            // عرض مؤشر تحميل أثناء جلب البيانات
            return const Center(child: CircularProgressIndicator());
          }

          var docs = snapshot.data!.docs;

          // ترتيب التقييمات بناءً على تاريخ الموعد (الأحدث أولاً)
          docs.sort((a, b) {
            final rawA = (a.data() as Map)['appointmentDateTime'];
            final rawB = (b.data() as Map)['appointmentDateTime'];
            if (rawA == null || rawB == null) return 0;
            return rawB.compareTo(rawA);
          });

          if (docs.isEmpty) {
            // رسالة تظهر إذا لم يكن هناك أي تقييمات
            return const Center(
              child: Text('No reviews yet',
                  style: TextStyle(color: Colors.grey, fontSize: 16)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            // إضافة 1 لعدد العناصر لأننا سنعرض ملخص التقييمات في أول عنصر
            itemCount: docs.length + 1,
            itemBuilder: (context, index) {
              // العنصر الأول هو دائماً مربع ملخص التقييمات
              if (index == 0) return _buildAggregateSummary(docs);

              // طرح 1 من الفهرس للحصول على التقييم الصحيح من القائمة
              final data = docs[index - 1].data() as Map<String, dynamic>;
              final double reviewRating =
                  (data['rating'] as num?)?.toDouble() ?? 0.0;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            data['patient_name'] ?? 'Patient',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        Row(
                          children: [
                            StarRatingWidget(
                              initialRating: reviewRating,
                              starSize: 18,
                              isReadOnly: true,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              reviewRating.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      data['feedback_text'] ?? 'No comment provided.',
                      style:
                          TextStyle(color: Colors.grey.shade700, height: 1.4),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
