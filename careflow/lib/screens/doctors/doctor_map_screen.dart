import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../common/base_map_screen.dart';

class DoctorMapScreen extends BaseMapScreen {
  const DoctorMapScreen({super.key});

  @override
  State<DoctorMapScreen> createState() => _DoctorMapScreenState();
}

class _DoctorMapScreenState extends BaseMapState<DoctorMapScreen> {
  LatLng? pickedClinicLocation;

@override
  Set<Marker> get markers {
    if (pickedClinicLocation == null) return {};
    return {
      Marker(
        markerId: const MarkerId('picked_clinic'),
        position: pickedClinicLocation!,
      )
    };
  }

@override
  void onMapTapped(LatLng position) {
    setState(() {
      pickedClinicLocation = position;
    });
  }

@override
  Widget? buildBottomPanel() {
    if (pickedClinicLocation == null)
      return null;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          minimumSize: const Size(double.infinity, 50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () {

          Navigator.of(context).pop(pickedClinicLocation);
        },
        child: const Text('Confirm Clinic Location',
            style: TextStyle(color: Colors.white, fontSize: 18)),
      ),
    );
  }
}
