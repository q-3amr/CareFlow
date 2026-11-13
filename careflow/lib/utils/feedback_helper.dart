import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';
import '../widgets/star_rating_widget.dart';
import '../utils/app_colors.dart';
import '../utils/app_tokens.dart';

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
    _feedbackListener = FirebaseFirestore.instance
        .collection('appointments')
        .where('patient_id', isEqualTo: userId)
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['hasFeedback'] != true && data['isDismissed'] != true) {
          if (context.mounted) {
            _showFeedbackPopup(doc.id);
            break;
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
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final textPrimary = AppColors.textPrimary(isDark);
            final textSecondary = AppColors.textSecondary(isDark);
            final textTertiary = AppColors.textTertiaryLight;
            final panelFill = isDark ? AppColors.cardTintDark : AppColors.surfaceSunken;
            final border = AppColors.border(isDark);

            return AnimatedPadding(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.large,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.xl,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.starSoftDark
                                      : AppColors.starLight,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.stars_rounded,
                                  color: AppColors.starAmber,
                                  size: AppIconSize.xl,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'Feedback',
                                textAlign: TextAlign.center,
                                style: AppTypography.title.copyWith(color: textPrimary),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Your appointment has finished!\nPlease share your experience with us.',
                                textAlign: TextAlign.center,
                                style: AppTypography.body.copyWith(color: textSecondary),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.md,
                                ),
                                decoration: BoxDecoration(
                                  color: panelFill,
                                  borderRadius: AppRadius.medium,
                                  border: Border.all(color: border),
                                ),
                                child: Column(
                                  children: [
                                    StarRatingWidget(
                                      initialRating: dialogRating,
                                      starSize: AppIconSize.xl,
                                      onRatingChanged: (val) => setDialogState(
                                          () => dialogRating = val),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
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
                                      style: AppTypography.label.copyWith(
                                        color: isDark
                                            ? AppColors.starAmber
                                            : AppColors.warningText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              TextField(
                                controller: _feedbackController,
                                maxLines: 3,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                style: AppTypography.body.copyWith(color: textPrimary),
                                decoration: InputDecoration(
                                  hintText: 'Write your feedback here...',
                                  hintStyle: AppTypography.body.copyWith(color: textTertiary),
                                  fillColor: panelFill,
                                  filled: true,
                                  border: OutlineInputBorder(
                                    borderRadius: AppRadius.medium,
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.all(AppSpacing.md),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              SizedBox(
                                width: double.infinity,
                                height: AppMetrics.controlHeight,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final apptDoc =
                                        await FirebaseFirestore.instance
                                            .collection('appointments')
                                            .doc(appointmentId)
                                            .get();
                                    final doctorId =
                                        apptDoc.data()?['doctor_id'] as String?;

                                    await FirebaseFirestore.instance
                                        .collection('appointments')
                                        .doc(appointmentId)
                                        .update({
                                      'hasFeedback': true,
                                      'feedback_text': _feedbackController.text,
                                      'isReviewSeen': false,
                                      'rating': dialogRating,
                                    });

                                    // Also store the review in the public
                                    // reviews collection so doctor profiles
                                    // can display it.
                                    await _db.saveReviewForAppointment(
                                      appointmentId: appointmentId,
                                      rating: dialogRating,
                                      feedbackText: _feedbackController.text,
                                    );

                                    if (doctorId != null &&
                                        doctorId.isNotEmpty) {
                                      await _db.updateDoctorAggregateRating(
                                          doctorId);
                                    }

                                    _feedbackController.clear();
                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext);
                                    }
                                  },
                                  child: const Text('Confirm'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        right: AppSpacing.xs,
                        top: AppSpacing.xs,
                        child: IconButton(
                          tooltip: 'Skip feedback',
                          icon: Icon(
                            Icons.close_rounded,
                            color: textSecondary,
                            size: AppIconSize.lg,
                          ),
                          onPressed: () async {
                            await FirebaseFirestore.instance
                                .collection('appointments')
                                .doc(appointmentId)
                                .update({
                              'isDismissed': true,
                            });
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
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