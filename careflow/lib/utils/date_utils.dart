import 'package:cloud_firestore/cloud_firestore.dart';

DateTime parseDate(dynamic dateData) {
  if (dateData is Timestamp) return dateData.toDate().toLocal();
  if (dateData is String) {
    final parsed = DateTime.tryParse(dateData);
    return parsed != null ? parsed.toLocal() : DateTime.now();
  }
  return DateTime.now();
}

bool isExpiredAppointment(DateTime appointmentDate) {
  return DateTime.now().isAfter(
    appointmentDate.add(const Duration(minutes: 20)),
  );
}

String formatTimeFromDateTime(DateTime date) {
  int hour =
      date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
  String minute = date.minute.toString().padLeft(2, '0');
  String amPm = date.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $amPm';
}

String formatDateKey(DateTime date) => '${date.year}-${date.month}-${date.day}';

String formatDateDisplay(DateTime date) {
  return '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
