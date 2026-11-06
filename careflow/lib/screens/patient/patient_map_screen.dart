import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../common/base_map_screen.dart';
import '../../models/user.dart';

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
            .map((doc) {
              return UserModel.fromMap(doc.data(), doc.id);
            })
            .where(
                (doctor) => doctor.latitude != null && doctor.longitude != null)
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
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(title: doctor.name, snippet: doctor.specialty),
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, -5),
            )
          ]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.local_hospital, color: Colors.white),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(selectedDoctor!.name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      selectedDoctor!.specialty ?? 'General',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          
          Row(
            children: [
              
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    elevation: 2,
                  ),
                  onPressed: () => _openGoogleMapsDirections(
                      selectedDoctor!.latitude!, selectedDoctor!.longitude!),
                  icon: const Icon(Icons.directions_car, color: Colors.white),
                  label: const Text('Directions',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),

              
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue, 
                    foregroundColor: Colors.white, 
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(15)), 
                    elevation: 2,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DoctorDetailsScreen(
                          doctorName: selectedDoctor!.name,
                          specialty: selectedDoctor!.specialty ?? 'General',
                          doctorId: selectedDoctor!.id,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person, color: Colors.white),
                  label: const Text('View Profile',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
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
            'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
        if (await canLaunchUrl(browserUrl)) {
          await launchUrl(browserUrl, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              
              const SnackBar(content: Text('Cannot open maps on this device.')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          
          const SnackBar(
              content: Text('An error occurred while opening maps.')),
        );
      }
    }
  }
}
