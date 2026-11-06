import '../utils/date_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentModel {
  final String id;
  final String doctorId;
  final String doctorName;
  final String patientId;
  final String patientName;
  final DateTime appointmentDateTime;
  final String status;
  final String? notes;

  AppointmentModel({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.patientId,
    required this.patientName,
    required this.appointmentDateTime,
    required this.status,
    this.notes,
  });

  factory AppointmentModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return AppointmentModel(
      id: documentId,
      doctorId: map['doctor_id'] ?? '',
      doctorName: map['doctor_name'] ?? '',
      patientId: map['patient_id'] ?? '',
      patientName: map['patient_name'] ?? 'Unknown',
      appointmentDateTime: parseDate(map['appointmentDateTime']),
      status: map['status'] ?? 'pending',
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'doctor_id': doctorId,
      'doctor_name': doctorName,
      'patient_id': patientId,
      'patient_name': patientName,
      'appointmentDateTime': Timestamp.fromDate(appointmentDateTime),
      'status': status,
      if (notes != null) 'notes': notes,
    };
  }

  AppointmentModel copyWith({
    String? id,
    String? doctorId,
    String? doctorName,
    String? patientId,
    String? patientName,
    DateTime? appointmentDateTime,
    String? status,
    String? notes,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      appointmentDateTime: appointmentDateTime ?? this.appointmentDateTime,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }
}
