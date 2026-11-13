import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' show cos, sqrt, asin;
import '../../services/database_service.dart';
import '../../models/user.dart';
import '../../utils/app_tokens.dart';
import '../../utils/constants.dart';
import '../../widgets/star_rating_widget.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_empty_state.dart';
import 'doctor_details_screen.dart';

class DoctorSearchScreen extends StatefulWidget {
  final String? initialSpecialty;
  const DoctorSearchScreen({super.key, this.initialSpecialty});

  @override
  State<DoctorSearchScreen> createState() => _DoctorSearchScreenState();
}

class _DoctorSearchScreenState extends State<DoctorSearchScreen> {
  final _db = DatabaseService();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();

  // Keep one subscription for the lifetime of the screen. Creating the
  // Firestore stream inside build() re-subscribed on every keystroke and made
  // the results flash and disappear.
  late Stream<List<UserModel>> _doctorsStream = _db.streamDoctors();

  void _reloadDoctors() {
    setState(() => _doctorsStream = _db.streamDoctors());
  }

  String searchQuery = '';
  String selectedFilter = 'All';
  String? selectedSpecialty;
  Position? _userPosition;
  bool _isLoadingLocation = false;

  static const List<String> _filterSpecialties = [
    'All Specialties',
    ...kSpecialties,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialSpecialty != null &&
        _filterSpecialties.contains(widget.initialSpecialty)) {
      selectedSpecialty = widget.initialSpecialty;
    } else {
      selectedSpecialty = 'All Specialties';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final c = cos;
    final a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _isLoadingLocation = false);
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _userPosition = position;
          selectedFilter = 'Nearest';
          _isLoadingLocation = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      appBar: AppBar(title: const Text('Find Doctors')),
      body: Column(
        children: [
          // Filter & Search Header
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Column(
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  onChanged: (val) =>
                      setState(() => searchQuery = val.toLowerCase().trim()),
                  textInputAction: TextInputAction.search,
                  style: AppTypography.body.copyWith(color: textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search by doctor name or specialty...',
                    fillColor: isDark
                        ? AppColors.surfaceSunken
                        : AppColors.surfaceSunken,
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.primary,
                    ),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => searchQuery = '');
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Specialty Selector + Quick Filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Specialty Dropdown
                      Container(
                        width: 210,
                        height: AppMetrics.controlHeight,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.cardTintDark
                              : AppColors.surfaceSunken,
                          borderRadius: AppRadius.medium,
                          border: Border.all(
                            color: isDark
                                ? AppColors.borderDark
                                : AppColors.borderLight,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedSpecialty,
                            isExpanded: true,
                            isDense: true,
                            dropdownColor: isDark
                                ? AppColors.cardDark
                                : AppColors.cardLight,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                            ),
                            items: _filterSpecialties.map((s) {
                              return DropdownMenuItem(
                                value: s,
                                child: Text(
                                  s,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.label.copyWith(
                                    color: textPrimary,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setState(() => selectedSpecialty = val),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),

                      // Top Rated Toggle
                      _buildFilterChip(
                        label: 'Top Rated',
                        icon: Icons.star_rounded,
                        isSelected: selectedFilter == 'Top Rated',
                        onTap: () {
                          setState(() {
                            selectedFilter = selectedFilter == 'Top Rated'
                                ? 'All'
                                : 'Top Rated';
                          });
                        },
                        isDark: isDark,
                      ),
                      const SizedBox(width: AppSpacing.sm),

                      // Nearest Toggle
                      _buildFilterChip(
                        label:
                            _isLoadingLocation ? 'Locating...' : 'Nearest',
                        icon: Icons.near_me_rounded,
                        isSelected: selectedFilter == 'Nearest',
                        onTap: () {
                          if (selectedFilter == 'Nearest') {
                            setState(() => selectedFilter = 'All');
                          } else {
                            _getCurrentLocation();
                          }
                        },
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Doctors Stream List
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: _doctorsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    snapshot.data == null) {
                  return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.2));
                }
                if (snapshot.hasError) {
                  return _buildErrorState(textPrimary, textSecondary);
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState(textPrimary, textSecondary);
                }

                List<UserModel> filtered = snapshot.data!.where((doctor) {
                  if (currentUser != null && doctor.id == currentUser!.uid)
                    return false;
                  final name = doctor.name.toLowerCase();
                  final spec = (doctor.specialty ?? '').toLowerCase();
                  final matchesSearch =
                      name.contains(searchQuery) || spec.contains(searchQuery);

                  bool matchesSpecialty = true;
                  if (selectedSpecialty != 'All Specialties') {
                    matchesSpecialty = doctor.specialty == selectedSpecialty;
                  }
                  return matchesSearch && matchesSpecialty;
                }).toList();

                if (selectedFilter == 'Nearest' && _userPosition != null) {
                  for (var doc in filtered) {
                    if (doc.latitude != null && doc.longitude != null) {
                      doc.distance = _calculateDistance(
                        _userPosition!.latitude,
                        _userPosition!.longitude,
                        doc.latitude!,
                        doc.longitude!,
                      );
                    }
                  }
                  filtered.sort((a, b) =>
                      (a.distance ?? 99999).compareTo(b.distance ?? 99999));
                }

                if (selectedFilter == 'Top Rated') {
                  filtered.sort((a, b) {
                    final rA = a.rating ?? -1.0;
                    final rB = b.rating ?? -1.0;
                    return rB.compareTo(rA);
                  });
                }

                if (filtered.isEmpty) {
                  return _buildEmptyState(textPrimary, textSecondary);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _buildDoctorCard(
                      filtered[index], isDark, textPrimary, textSecondary),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.medium,
        child: Container(
          height: AppMetrics.controlHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? AppColors.primaryContainerDark
                    : AppColors.primaryLight)
                : (isDark
                    ? AppColors.cardTintDark
                    : AppColors.surfaceSunken),
            borderRadius: AppRadius.medium,
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.borderDark : AppColors.borderLight),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: AppIconSize.sm,
                color: isSelected ? AppColors.primary : textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label.copyWith(
                  color: isSelected ? AppColors.primary : textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorCard(
    UserModel doctor,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final initials = doctor.name.isNotEmpty
        ? doctor.name
            .trim()
            .split(' ')
            .map((n) => n.isNotEmpty ? n[0] : '')
            .take(2)
            .join()
        : 'DR';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (c) => DoctorDetailsScreen(
              doctorName: doctor.name,
              specialty: doctor.specialty ?? 'General',
              doctorId: doctor.id,
              latitude: doctor.latitude,
              longitude: doctor.longitude,
              distance: doctor.distance,
            ),
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AppAvatar(initials: initials, size: 52),
            const SizedBox(width: AppSpacing.md),

            // Doctor Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Dr. ${doctor.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.section.copyWith(
                            color: textPrimary,
                          ),
                        ),
                      ),
                      if (doctor.isVerified == true) ...[
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
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      AppBadge(
                        label: doctor.specialty ?? 'General',
                        variant: AppBadgeVariant.primary,
                      ),
                      if (doctor.distance != null)
                        AppBadge(
                          label: '${doctor.distance!.toStringAsFixed(1)} km',
                          variant: AppBadgeVariant.neutral,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      StarRatingWidget(
                        initialRating: doctor.rating ?? 5.0,
                        starSize: 13,
                        isReadOnly: true,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        (doctor.rating ?? 5.0).toStringAsFixed(1),
                        style: AppTypography.caption.copyWith(
                          color: textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        ' (${doctor.reviewCount ?? 0})',
                        style: AppTypography.caption.copyWith(
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.chevron_right_rounded,
              color: textSecondary,
              size: AppIconSize.md,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Color textPrimary, Color textSecondary) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppEmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Could not load doctors',
      message: 'Check your connection and try again.',
      iconColor: isDark ? const Color(0xFFFCD34D) : AppColors.warningText,
      iconBackgroundColor:
          isDark ? AppColors.warningSoftDark : AppColors.warningLight,
      action: OutlinedButton.icon(
        onPressed: _reloadDoctors,
        icon: const Icon(Icons.refresh_rounded, size: AppIconSize.sm),
        label: const Text('Retry'),
      ),
    );
  }

  Widget _buildEmptyState(Color textPrimary, Color textSecondary) {
    return const AppEmptyState(
      icon: Icons.search_off_rounded,
      title: 'No Doctors Found',
      message: 'Try adjusting your search query or specialty filter.',
    );
  }
}
