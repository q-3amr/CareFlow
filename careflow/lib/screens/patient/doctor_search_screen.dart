import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' show cos, sqrt, asin;
import '../../services/database_service.dart';
import '../../models/user.dart';
import '../../utils/constants.dart';
import '../../widgets/star_rating_widget.dart';
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

  String searchQuery = '';
  String selectedFilter = 'Select Filter';
  String? selectedSpecialty;

  Position? _userPosition;
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

  static const List<String> _filterSpecialties = [
    'All Specialties',
    ...kSpecialties,
  ];

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _userPosition = position;
      selectedFilter = 'By Nearest';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Find Your Doctor',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                onChanged: (value) =>
                    setState(() => searchQuery = value.toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Search by name or specialty...',
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: _buildFilterSection(),
          ),
          _buildSpecialtyDropdown(),
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: _db.streamDoctors(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No doctors found.'));
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

                if (selectedFilter == 'By Nearest' && _userPosition != null) {
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

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      _buildDoctorCard(filtered[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_list_rounded, color: kPrimaryBlue, size: 22),
          const SizedBox(width: 12),
          const Text('Filter by:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedFilter,
                isExpanded: true,
                items: ['Select Filter', 'Top Rated', 'By Nearest']
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (String? newValue) {
                  if (newValue == 'By Nearest') {
                    _getCurrentLocation();
                  } else if (newValue == 'Top Rated') {
                    setState(() => selectedFilter = 'Top Rated');
                  } else {
                    setState(() => selectedFilter = 'Select Filter');
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialtyDropdown() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: kPrimaryBlue.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kPrimaryBlue.withValues(alpha: 0.3)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedSpecialty,
            isExpanded: true,
            items: _filterSpecialties
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (val) => setState(() => selectedSpecialty = val),
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorCard(UserModel doctor) {
    return GestureDetector(
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withValues(alpha: 0.05), blurRadius: 15)
          ],
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 35,
              backgroundColor: Colors.blue,
              child: Icon(Icons.person, color: Colors.white, size: 35),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dr. ${doctor.name}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(doctor.specialty ?? 'General',
                      style: TextStyle(color: Colors.grey.shade500)),
                  if (doctor.rating != null && doctor.rating! > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        children: [
                          StarRatingWidget(
                            initialRating: doctor.rating!,
                            starSize: 14,
                            isReadOnly: true,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            doctor.rating!.toStringAsFixed(1),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber),
                          ),
                        ],
                      ),
                    ),
                  if (doctor.distance != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${doctor.distance!.toStringAsFixed(1)} km away',
                        style: const TextStyle(
                            color: kPrimaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 18, color: kPrimaryBlue),
          ],
        ),
      ),
    );
  }
}
