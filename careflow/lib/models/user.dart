class UserModel {
  final String id;
  final String email;
  final String name;
  final String role;
  final String? profileImage;
  final String? specialty;
  final double? rating;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? pushToken;
  final String? about;
  final bool? isVerified;
  final int? reviewCount;
  double? distance;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.pushToken,
    this.profileImage,
    this.specialty,
    this.rating,
    this.location,
    this.latitude,
    this.longitude,
    this.about,
    this.isVerified,
    this.distance,
    this.reviewCount,
  });

  bool get isDoctor => role.trim().toLowerCase() == 'doctor';
  bool get isPatient => role.trim().toLowerCase() == 'patient';

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      id: documentId,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      pushToken: map['pushToken'] ?? '',
      role: map['role'] ?? 'patient',
      profileImage: map['profileImage'],
      specialty: map['specialty'],
      rating: map['rating'] != null ? (map['rating'] as num).toDouble() : null,
      location: map['location'],
      latitude:
          map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null
          ? (map['longitude'] as num).toDouble()
          : null,
      about: map['about'],
      isVerified: map['isVerified'] ?? false,
      reviewCount:
          map['reviewCount'] != null ? (map['reviewCount'] as num).toInt() : 0,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'email': email,
      'name': name,
      'role': role,
      'pushToken': pushToken,
      'profileImage': profileImage ?? '',
    };
    if (isDoctor) {
      map['specialty'] = specialty ?? '';
      map['rating'] = rating ?? 0.0;
      map['location'] = location ?? '';
      map['latitude'] = latitude;
      map['longitude'] = longitude;
      map['about'] = about ?? '';
      map['isVerified'] = isVerified ?? false;
      map['reviewCount'] = reviewCount ?? 0;
    }

    return map;
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? role,
    String? profileImage,
    String? specialty,
    double? rating,
    String? location,
    String? pushToken,
    double? latitude,
    double? longitude,
    String? about,
    bool? isVerified,
    double? distance,
    int? reviewCount,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      pushToken: pushToken ?? this.pushToken,
      profileImage: profileImage ?? this.profileImage,
      specialty: specialty ?? this.specialty,
      rating: rating ?? this.rating,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      about: about ?? this.about,
      isVerified: isVerified ?? this.isVerified,
      distance: distance ?? this.distance,
      reviewCount: reviewCount ?? this.reviewCount,
    );
  }
}
