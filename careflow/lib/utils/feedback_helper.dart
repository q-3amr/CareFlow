import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';
import '../widgets/star_rating_widget.dart';
import 'constants.dart';

class FeedbackHelper {
  final BuildContext context;
  final String userId;
  final DatabaseService _db = DatabaseService();
  StreamSubscription? _feedbackListener;
  final TextEditingController _feedbackController = TextEditingController();

  FeedbackHelper({required this.context, required this.userId}) {
    _startFeedbackListener();
  }

  void _startFeedbackListener() {
    //براقب مواعيد المريض اللي خلصت عشان يظهر بوكس الفيدباك
    _feedbackListener = FirebaseFirestore.instance
        .collection('appointments')
        .where('patient_id',
            isEqualTo: userId) //المريض اللي بتتعمل عليه المراقبة
        .where('status', isEqualTo: 'completed') //المواعيد اللي خلصت
        .snapshots() //اول ما يحصل تعديل في الداتا بظهر البوكس
        .listen((snapshot) {
      //الـ snapshot دي بنستخدمها عشان نراقب التغييرات في الداتا
      for (var doc in snapshot.docs) {
        //الداتا اللي بتيجي من الـ snapshot بتكون على هيئة list من الـ documents
        final data = doc.data();
        if (data['hasFeedback'] != true && data['isDismissed'] != true) {
          //لو مفيش فيدباك وعند المريض
          if (context.mounted) {
            _showFeedbackPopup(doc.id); //بستدعي الدالة هاي عشان يظهر البوكس
            break; //بكسر اللوب عشان ما يبين البوكس اكتر من مرة
          }
        }
      }
    });
  }

  void _showFeedbackPopup(String appointmentId) {
    double dialogRating = 5.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25)),
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 8),
                          const Icon(Icons.stars_rounded,
                              color: Colors.amber, size: 50),
                          const SizedBox(height: 10),
                          const Text('Feedback',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 22)),
                          const SizedBox(height: 15),
                          const Text(
                            'Your appointment has finished!\nPlease share your experience with us.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                  color: Colors.amber.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              children: [
                                StarRatingWidget(
                                  initialRating: dialogRating,
                                  starSize: 36,
                                  onRatingChanged: (val) =>
                                      setDialogState(() => dialogRating = val),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  dialogRating == 1
                                      ? 'Poor'
                                      : dialogRating == 2
                                          ? 'Fair'
                                          : dialogRating == 3
                                              ? 'Good'
                                              : dialogRating == 4
                                                  ? 'Very Good'
                                                  : 'Excellent',
                                  style: const TextStyle(
                                      color: Colors.amber,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _feedbackController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Write your feedback here...',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade200)),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimaryBlue,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                              ),
                              onPressed: () async {
                                final apptDoc = await FirebaseFirestore.instance
                                    .collection('appointments')
                                    .doc(appointmentId)
                                    .get();
                                final doctorId =
                                    apptDoc.data()?['doctor_id'] as String?;

                                await FirebaseFirestore.instance
                                    .collection('appointments')
                                    .doc(appointmentId)
                                    .update({
                                  'hasFeedback': true, // المريض حط فيدباك
                                  'feedback_text': _feedbackController
                                      .text, //النص اللي المريض رح يكتبو
                                  'isReviewSeen':
                                      false, //اول ما يحط فيدباك يخليه false عشان ما يبين البوكس مره ثانيه
                                  'rating':
                                      dialogRating, //التقييم اللي المريض رح يحطو
                                });

                                if (doctorId != null && doctorId.isNotEmpty) {
                                  //لو الدكتور موجود
                                  await _db.updateDoctorAggregateRating(
                                      doctorId); //دالة تتحدث التقييم الكلي للدكتور
                                }

                                _feedbackController.clear();
                                if (dialogContext.mounted) {
                                  Navigator.pop(dialogContext);
                                }
                              },
                              child: const Text('Confirm',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      onPressed: () async {
                        await FirebaseFirestore
                            .instance // لما المريض يعمل skip نخلي البوكس هاد يختفي
                            .collection('appointments')
                            .doc(appointmentId)
                            .update({
                          'isDismissed': true, // انه المريض تخطى البوكس
                        });
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void dispose() {
    _feedbackListener?.cancel();
    _feedbackController.dispose();
  }
}
