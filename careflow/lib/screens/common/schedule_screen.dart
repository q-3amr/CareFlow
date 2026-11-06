import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/database_service.dart';
import '../../utils/constants.dart';
import '../../utils/date_utils.dart';

class ScheduleScreen extends StatefulWidget {
  final bool isDoctor;

  const ScheduleScreen({super.key, required this.isDoctor});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final _db = DatabaseService();
  final User? user = FirebaseAuth.instance.currentUser;

  int _buttonIndex = 0;

  bool _isExpired(DateTime appointmentDate) =>
      isExpiredAppointment(appointmentDate);

  void _cancelAppointment(String docId) async {
    final confirm = await _confirmDialog(
          title: 'Cancel Appointment?',
          message: 'Are you sure you want to cancel?',
          confirmLabel: 'Yes, Cancel',
          confirmColor: Colors.red,
        ) ??
        false;

    if (confirm) {
      await _db.updateAppointmentStatus(
        docId,
        'cancelled',
        cancelledBy: 'patient', 
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment Cancelled')),
        );
      }
    }
  }

  void _completeAppointment(String docId) async {
    final confirm = await _confirmDialog(
          title: 'Complete Appointment?',
          message: 'Is the session done / patient arrived?',
          confirmLabel: 'Yes, Complete',
          confirmColor: Colors.green,
        ) ??
        false;

    if (confirm) {
      await _db.updateAppointmentStatus(docId, 'completed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked as Completed')),
        );
      }
    }
  }

  void _deleteAppointment(String docId) async {
    final confirm = await _confirmDialog(
          title: 'Delete from History?',
          message: 'This will remove the record permanently.',
          confirmLabel: 'Delete',
          confirmColor: Colors.red,
        ) ??
        false;

    if (confirm) {
      await _db.deleteAppointment(docId);
    }
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmLabel,
              style: TextStyle(color: confirmColor),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'My Schedule',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  _buildTab('Upcoming', 0),
                  _buildTab('History', 1),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<dynamic>(
                // يستمع للتحديثات الفورية من فايرستور لمواعيد المستخدم
                stream: user?.uid != null
                    ? _db.streamUserAppointments(
                        user!.uid,
                        isDoctor: widget.isDoctor,
                      )
                    : null,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    // عرض مؤشر تحميل أثناء جلب البيانات
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;

                  // تصفية المواعيد بناءً على التبويب المحدد (قادمة أو السجل)
                  final filtered = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status'] as String;
                    final date = parseDate(data['appointmentDateTime']);
                    final expired = _isExpired(date);

                    if (_buttonIndex == 0) {
                      // تبويب المواعيد القادمة: عرض المواعيد المقبولة فقط والتي لم تنقضِ بعد
                      return status == 'accepted' && !expired;
                    } else {
                      // تبويب السجل: عرض المواعيد المكتملة، الملغاة، المرفوضة، أو المنتهية
                      return status == 'completed' ||
                          status == 'cancelled' ||
                          status == 'rejected' ||
                          (status == 'accepted' && expired);
                    }
                  }).toList();

                  // ترتيب المواعيد المصفاة حسب التاريخ والوقت
                  filtered.sort((a, b) {
                    final dateA =
                        parseDate((a.data() as Map)['appointmentDateTime']);
                    final dateB =
                        parseDate((b.data() as Map)['appointmentDateTime']);
                    return _buttonIndex == 0
                        // المواعيد القادمة: المواعيد الأقرب أولاً (تصاعدي)
                        ? dateA.compareTo(dateB)
                        // السجل: المواعيد الأحدث أولاً (تنازلي)
                        : dateB.compareTo(dateA);
                  });

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 70,
                            color: Colors.grey.shade300,
                          ),
                          Text(
                            'No appointments',
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _buildCard(filtered[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String text, int index) {
    // التحقق مما إذا كان هذا التبويب محدداً حالياً
    final active = _buttonIndex == index;
    return Expanded(
      child: GestureDetector(
        // تحديث الفهرس عند النقر على التبويب، مما يعيد بناء واجهة المستخدم
        onTap: () => setState(() => _buttonIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            // تمييز التبويب النشط باللون الأزرق الأساسي
            color: active ? kPrimaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                // تغيير لون النص بناءً على حالة التبويب (نشط أو غير نشط)
                color: active ? Colors.white : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(dynamic doc) {
    final data = doc.data() as Map<String, dynamic>;
    // تحديد الاسم المراد عرضه بناءً على ما إذا كان المستخدم الحالي طبيباً أم مريضاً
    final String name = widget.isDoctor
        ? (data['patient_name'] ?? 'Patient')
        : (data['doctor_name'] ?? 'Doctor');
    final DateTime dateObj = parseDate(data['appointmentDateTime']);
    final String dateStr = formatDateDisplay(dateObj);
    final String timeStr = formatTimeFromDateTime(dateObj);

    final bool expired = _isExpired(dateObj);
    final String status = data['status'];

    String displayStatus;
    Color statusColor;

    // تحديد نص ولون الحالة المراد عرضها على البطاقة بناءً على حالة الموعد
    if (status == 'accepted' && !expired) {
      displayStatus = 'Upcoming';
      statusColor = Colors.blue;
    } else if (status == 'accepted' && expired) {
      displayStatus = 'Expired';
      statusColor = Colors.orange;
    } else if (status == 'cancelled') {
      
      displayStatus = 'Cancelled';
      statusColor = Colors.orange;
    } else if (status == 'rejected') {
      
      displayStatus = 'Rejected';
      statusColor = Colors.red;
    } else if (status == 'completed') {
      displayStatus = 'Completed';
      statusColor = Colors.green;
    } else {
      displayStatus = status;
      statusColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: statusColor.withValues(alpha: 0.1),
                child: Icon(Icons.person, color: statusColor),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      displayStatus,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // زر الإلغاء للمرضى في المواعيد القادمة
              if (!widget.isDoctor && displayStatus == 'Upcoming')
                IconButton(
                  icon: const Icon(Icons.cancel_outlined,
                      color: Colors.redAccent),
                  onPressed: () => _cancelAppointment(doc.id),
                ),
              // زر الإكمال للأطباء في المواعيد القادمة
              if (widget.isDoctor && displayStatus == 'Upcoming')
                IconButton(
                  icon: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 28,
                  ),
                  onPressed: () => _completeAppointment(doc.id),
                  tooltip: 'Mark as Completed',
                ),
              // زر الحذف من السجل (يظهر فقط في تبويب السجل)
              if (_buttonIndex == 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  onPressed: () => _deleteAppointment(doc.id),
                ),
            ],
          ),
          const Divider(height: 25),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
              const SizedBox(width: 5),
              Text(dateStr,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              const Icon(Icons.access_time, size: 16, color: Colors.grey),
              const SizedBox(width: 5),
              Text(timeStr,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
