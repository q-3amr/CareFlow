import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

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
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('Enable Location',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text(
              'Please enable location services (GPS) to allow the app to determine your location accurately.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child:
                  const Text('Settings', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Geolocator.openLocationSettings();
                Navigator.of(context).pop();
              },
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
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
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
            bottom: buildBottomPanel() != null
                ? 140
                : 20, // لوجيك ذكي: إذا الابن عارض لوحة سفلية، ارفع زر الموقع لـ 140 بكسل عشان ما يتغطى، وإلا نزلّه لـ 20 بكسل
            left: 16,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : requestLocationAndGetPosition,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue,
                elevation: 5,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                  side: const BorderSide(color: Colors.blue, width: 1),
                ),
              ),
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          // حط جوة المربع دائرة تحميل بتلف باللون الأزرق
                          strokeWidth: 2,
                          color: Colors.blue))
                  : const Icon(Icons.my_location, size: 20),
              label: const Text(
                'Current Location',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (isLoading) const Center(child: CircularProgressIndicator()),
          if (buildBottomPanel() != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: buildBottomPanel()!,
            ),
        ],
      ),
    );
  }
}
