import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_tokens.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_empty_state.dart';
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('doctor_id', isEqualTo: uid)
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();
      bool hasUpdates = false;

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        if (data['hasFeedback'] == true && data['isReviewSeen'] != true) {
          batch.update(doc.reference, {'isReviewSeen': true});
          hasUpdates = true;
        }
      }

      if (hasUpdates) {
        await batch.commit();
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint("Error updating reviews status: $e");
    }
  }

  Widget _buildAggregateSummary(List<QueryDocumentSnapshot> docs, bool isDark) {
    if (docs.isEmpty) return const SizedBox.shrink();

    final ratings = docs
        .map((d) => (d.data() as Map<String, dynamic>)['rating'])
        .where((r) => r != null)
        .map((r) => (r as num).toDouble())
        .toList();

    if (ratings.isEmpty) return const SizedBox.shrink();

    final double average = ratings.reduce((a, b) => a + b) / ratings.length;
    final int count = ratings.length;
    final textPrimary = AppColors.textPrimary(isDark);
    final textSecondary = AppColors.textSecondary(isDark);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isDark ? AppColors.starSoftDark : AppColors.warningLight,
                borderRadius: AppRadius.medium,
              ),
              alignment: Alignment.center,
              child: Text(
                average.toStringAsFixed(1),
                style: AppTypography.display.copyWith(
                  color: AppColors.starAmber,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      StarRatingWidget(
                        initialRating: average,
                        starSize: AppIconSize.sm,
                        isReadOnly: true,
                      ),
                      Text(
                        '${average.toStringAsFixed(1)} / 5',
                        style: AppTypography.label.copyWith(color: textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      AppBadge(
                        label: '$count ${count == 1 ? 'review' : 'reviews'}',
                      ),
                      Text(
                        'Patient feedback',
                        style: AppTypography.caption
                            .copyWith(color: textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimary(isDark);
    final textSecondary = AppColors.textSecondary(isDark);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient reviews'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .where('doctor_id', isEqualTo: uid)
            .where('hasFeedback', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var docs = snapshot.data!.docs;

          docs.sort((a, b) {
            final rawA = (a.data() as Map)['appointmentDateTime'];
            final rawB = (b.data() as Map)['appointmentDateTime'];
            if (rawA == null || rawB == null) return 0;
            return rawB.compareTo(rawA);
          });

          if (docs.isEmpty) {
            return AppEmptyState(
              icon: Icons.star_outline_rounded,
              title: 'No reviews yet',
              message: 'Completed visits can leave feedback here.',
              iconColor: AppColors.starAmber,
              iconBackgroundColor:
                  isDark ? AppColors.starSoftDark : AppColors.warningLight,
            );
          }

          return ListView.builder(
            padding: AppSpacing.screen,
            itemCount: docs.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) return _buildAggregateSummary(docs, isDark);

              final data = docs[index - 1].data() as Map<String, dynamic>;
              final double reviewRating =
                  (data['rating'] as num?)?.toDouble() ?? 0.0;
              final name = data['patient_name'] ?? 'Patient';
              final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AppAvatar(initials: initial, size: 36),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.label
                                  .copyWith(color: textPrimary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          StarRatingWidget(
                            initialRating: reviewRating,
                            starSize: AppIconSize.sm,
                            isReadOnly: true,
                          ),
                          Text(
                            reviewRating.toStringAsFixed(1),
                            style: AppTypography.label.copyWith(
                              color: AppColors.starAmber,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        data['feedback_text'] ?? 'No comment provided.',
                        style:
                            AppTypography.body.copyWith(color: textSecondary),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
