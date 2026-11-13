import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../../utils/app_colors.dart';
import '../../utils/app_tokens.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  static const LatLng _initialPosition = LatLng(31.9539, 35.9106);
  LatLng? _pickedLocation;
  GoogleMapController? _mapController;
  bool _isLoading = false;

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar(
            "Please enable Location Services (GPS) from device settings",
            AppColors.warning);
        setState(() => _isLoading = false);
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar("Location permission denied", AppColors.destructive);
          setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar(
            "Location permission is permanently denied, please enable it from Settings",
            AppColors.destructive);
        setState(() => _isLoading = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      LatLng currentLatLng = LatLng(position.latitude, position.longitude);

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(currentLatLng, 15),
      );

      setState(() {
        _pickedLocation = currentLatLng;
        _isLoading = false;
      });
    } catch (e) {
      _showSnackBar("An error occurred while fetching location: $e",
          AppColors.destructive);
      setState(() => _isLoading = false);
    }
  }

  void _selectLocation(LatLng position) {
    setState(() {
      _pickedLocation = position;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick clinic location'),
        actions: [
          if (_pickedLocation != null)
            IconButton(
              tooltip: 'Use this location',
              icon: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: AppIconSize.lg,
              ),
              onPressed: () => Navigator.of(context).pop(_pickedLocation),
            ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: _initialPosition,
              zoom: 13,
            ),
            onTap: _selectLocation,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: _pickedLocation == null
                ? {}
                : {
                    Marker(
                      markerId: const MarkerId('picked_location'),
                      position: _pickedLocation!,
                    ),
                  },
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _goToCurrentLocation,
        label: Text(_isLoading ? 'Locating...' : 'My current location'),
        icon: _isLoading
            ? const SizedBox(
                width: AppIconSize.md,
                height: AppIconSize.md,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.my_location_rounded),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
