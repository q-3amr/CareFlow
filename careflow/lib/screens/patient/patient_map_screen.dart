import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../common/base_map_screen.dart';
import '../../models/user.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_tokens.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_badge.dart';
import 'doctor_details_screen.dart';

class PatientMapScreen extends BaseMapScreen {
  const PatientMapScreen({super.key});

  @override
  State<PatientMapScreen> createState() => _PatientMapScreenState();
}

class _PatientMapScreenState extends BaseMapState<PatientMapScreen> {
  List<UserModel> doctors = [];
  UserModel? selectedDoctor;

  @override
  void initState() {
    super.initState();
    _fetchDoctors();
  }

  Future<void> _fetchDoctors() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'doctor')
          .get();

      setState(() {
        doctors = snapshot.docs
            .map((doc) => UserModel.fromMap(doc.data(), doc.id))
            .where((doctor) => doctor.latitude != null && doctor.longitude != null)
            .toList();
      });
    } catch (e) {
      debugPrint('Error fetching doctors: $e');
    }
  }

  @override
  Set<Marker> get markers {
    return doctors.map((doctor) {
      return Marker(
        markerId: MarkerId(doctor.id),
        position: LatLng(doctor.latitude!, doctor.longitude!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: 'Dr. ${doctor.name}', snippet: doctor.specialty),
        onTap: () {
          setState(() {
            selectedDoctor = doctor;
          });

          mapController?.animateCamera(
            CameraUpdate.newLatLng(LatLng(doctor.latitude!, doctor.longitude!)),
          );
        },
      );
    }).toSet();
  }

  @override
  void onMapTapped(LatLng position) {
    setState(() {
      selectedDoctor = null;
    });
  }

  @override
  Widget? buildBottomPanel() {
    if (selectedDoctor == null) return null;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final initials = selectedDoctor!.name.isNotEmpty
        ? selectedDoctor!.name.trim().split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join()
        : 'DR';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadius.sheet,
        boxShadow: AppShadows.raised,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(initials: initials, size: 48),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Dr. ${selectedDoctor!.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.section.copyWith(
                                color: textPrimary,
                              ),
                            ),
                          ),
                          if (selectedDoctor!.isVerified == true) ...[
                            const SizedBox(width: AppSpacing.xs),
                            const Icon(
                              Icons.verified_rounded,
                              color: AppColors.primary,
                              size: AppIconSize.sm,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          AppBadge(
                            label: selectedDoctor!.specialty ?? 'General',
                            variant: AppBadgeVariant.primary,
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 13,
                                color: AppColors.starAmber,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                (selectedDoctor!.rating ?? 5.0)
                                    .toStringAsFixed(1),
                                style: AppTypography.caption.copyWith(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded),
                  color: textSecondary,
                  onPressed: () => setState(() => selectedDoctor = null),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openGoogleMapsDirections(
                  selectedDoctor!.latitude!,
                  selectedDoctor!.longitude!,
                ),
                icon: const Icon(
                  Icons.near_me_rounded,
                  size: AppIconSize.sm,
                ),
                label: const Text('Directions'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DoctorDetailsScreen(
                        doctorName: selectedDoctor!.name,
                        specialty: selectedDoctor!.specialty ?? 'General',
                        doctorId: selectedDoctor!.id,
                        latitude: selectedDoctor!.latitude,
                        longitude: selectedDoctor!.longitude,
                      ),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.calendar_today_rounded,
                  size: AppIconSize.sm,
                ),
                label: const Text('Book Slot'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openGoogleMapsDirections(double lat, double lng) async {
    final Uri googleMapsUrl = Uri.parse('google.navigation:q=$lat,$lng&mode=d');

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl);
      } else {
        final Uri browserUrl = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
        );
        if (await canLaunchUrl(browserUrl)) {
          await launchUrl(browserUrl, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Could not open map directions'),
                backgroundColor: AppColors.destructive,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error launching navigation'),
            backgroundColor: AppColors.destructive,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
