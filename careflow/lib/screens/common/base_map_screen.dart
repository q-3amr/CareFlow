import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_tokens.dart';

abstract class BaseMapScreen extends StatefulWidget {
  const BaseMapScreen({super.key});
}

abstract class BaseMapState<T extends BaseMapScreen> extends State<T> {
  GoogleMapController? mapController;
  Position? currentPosition;
  bool isLoading = false;

  final CameraPosition initialPosition = const CameraPosition(
    target: LatLng(31.9539, 35.9106),
    zoom: 13,
  );

  Set<Marker> get markers;
  Widget? buildBottomPanel();
  void onMapTapped(LatLng position);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestLocationAndGetPosition();
    });
  }

  Future<void> _showLocationServiceDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimary(isDark);
    final textSecondary = AppColors.textSecondary(isDark);

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
          title: Text('Enable Location', style: AppTypography.title.copyWith(color: textPrimary)),
          content: Text(
              'Please enable location services (GPS) to allow the app to determine your location accurately.',
              style: AppTypography.body.copyWith(color: textSecondary)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: AppTypography.label.copyWith(color: textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                Geolocator.openLocationSettings();
                Navigator.of(context).pop();
              },
              child: const Text('Settings'),
            ),
          ],
        );
      },
    );
  }

  Future<void> requestLocationAndGetPosition() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => isLoading = false);
        await _showLocationServiceDialog();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showMessage('Permission denied. Cannot determine location.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showMessage(
            'Permissions are permanently denied. Please enable them from app settings.');
        return;
      }

      currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(currentPosition!.latitude, currentPosition!.longitude),
          16,
        ),
      );
    } catch (e) {
      _showMessage('An error occurred while fetching location');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.destructive,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPanel = buildBottomPanel();

    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition:
                initialPosition, // موقع الكاميرا البدئي (عمان)
            onMapCreated: (controller) {
              mapController =
                  controller; // لقطنا الريموت كنترول وخزناه بالمتغير

              requestLocationAndGetPosition(); // شغلنا دالة جلب الموقع الحقيقي فوراً
            },
            markers:
                markers, // مجموعة الدبابيس الجاية ديناميكياً من شاشات الأبناء
            onTap: onMapTapped, // دالة الضغط على الخريطة الجاية من الأبناء
            myLocationEnabled: true, // إظهار النقطة الزرقاء المشعة لموقع المريض
            myLocationButtonEnabled:
                false, // طفينا زر جوجل الافتراضي المشوه للتصميم
            zoomControlsEnabled:
                true, // تفعيل زري الـ (+ و -) لتكبير وتصغير الخريطة
          ),
          Positioned(
            top: AppSpacing.lg,
            right: AppSpacing.lg,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : requestLocationAndGetPosition,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).cardColor,
                foregroundColor: Theme.of(context).colorScheme.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.medium,
                  side: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              icon: isLoading
                  ? const SizedBox(
                      width: AppIconSize.sm,
                      height: AppIconSize.sm,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, size: AppIconSize.md),
              label: const Text('Current Location'),
            ),
          ),
          if (isLoading)
            const Positioned(
              top: AppSpacing.lg,
              left: 0,
              right: 0,
              child: Center(child: CircularProgressIndicator()),
            ),
          if (bottomPanel != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: bottomPanel,
            ),
        ],
      ),
    );
  }
}
