import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../utils/app_tokens.dart';
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
    if (pickedClinicLocation == null) return null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadius.sheet,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
        boxShadow: AppShadows.raised,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop(pickedClinicLocation);
            },
            icon: const Icon(Icons.check_rounded, size: AppIconSize.md),
            label: const Text('Confirm clinic location'),
          ),
        ),
      ),
    );
  }
}
