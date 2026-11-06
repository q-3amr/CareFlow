import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../services/database_service.dart';
import '../../models/user.dart';
import '../../utils/constants.dart';
import '../../utils/date_utils.dart';
import '../../widgets/action_button.dart';
import 'doctor_search_screen.dart';
import 'package:provider/provider.dart';
import 'voice_chat.dart';
import '../../providers/chat_provider.dart';
import 'patient_map_screen.dart';
import '../common/schedule_screen.dart';
import '../common/profile_screen.dart';
import '../common/chats_list_screen.dart';
import '../../services/auth_service.dart';
import '../../utils/feedback_helper.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const PatientHomeContent(),
    const ScheduleScreen(isDoctor: false),
    const ChatsListScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border:
              Border(top: BorderSide(color: Colors.grey.shade100, width: 1)),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: kPrimaryBlue,
          unselectedItemColor: Colors.grey.shade400,
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          items: [
            const BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded), label: 'Home'),
            const BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today_rounded), label: 'My Bookings'),
            BottomNavigationBarItem(
              icon: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .where('participants',
                        arrayContains:
                            _uid) //ببحث في مجموعة المحادثات اللي أنا مشارك فيها
                    .snapshots(),
                builder: (context, snapshot) {
                  int unreadCount = 0;
                  if (snapshot.hasData) {
                    unreadCount = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      if (data.containsKey('isRead') &&
                          data.containsKey('lastMessageSenderId')) {
                        return data['isRead'] ==
                                false && //هل الرسالة غير مقروءة؟
                            data['lastMessageSenderId'] !=
                                _uid; //وهل أرسلها المرسل الآخر وليس أنا؟
                      }
                      return false; // لو ما تحقق الشروط اللي فوق ما بزيد اشي بضل زي ما هو
                    }).length; //(عدد الشروط اللي فوق اللي اتحققت (بزيد واحد
                  }
                  return _buildBadgeIcon(
                      Icons.chat_bubble_outline_rounded, unreadCount);
                },
              ),
              label: 'Messages',
            ),
            const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeIcon(IconData icon, int count) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0) //لو في رسائل غير مقروءة
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle), //تقوم الدالة برسم دائرة حمراء صغيرة
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text('$count', //(عدد الرسائل الغير مقروءة)
                  style: const TextStyle(
                      color: Colors
                          .white, //تكون الارقام داخل الدائره الحمراء ب لون الخط أبيض
                      fontSize: 10, //حجم الخط 10
                      fontWeight: FontWeight.bold), //لون الخط غامق
                  textAlign: TextAlign.center), //سنتر النص
            ),
          ),
      ],
    );
  }
}

class PatientHomeContent extends StatefulWidget {
  const PatientHomeContent({super.key});
  @override
  State<PatientHomeContent> createState() => _PatientHomeContentState();
}

class _PatientHomeContentState extends State<PatientHomeContent> {
  final _db = DatabaseService();
  final User? user = AuthService().currentUser;
  FeedbackHelper?
      _feedbackHelper; //عشان نستخدم الـ helper اللي فيه ال functions اللي بتعمل feedback

  @override
  void initState() {
    super.initState();
    if (user != null) {
      _feedbackHelper = FeedbackHelper(
          context: context,
          userId:
              user!.uid); //بنستدعي الـ helper ونعطيه الـ context والـ user ID
    }
  }

  @override
  void dispose() {
    _feedbackHelper?.dispose(); //بنعمل dispose للـ helper
    super.dispose(); //بنعمل dispose للـ widget
  }

  @override
  Widget build(BuildContext context) {
    //هنا بنعمل build للـ widget
    return Scaffold(
      body: Stack(
        children: [
          Container(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                kPrimaryBlue.withValues(alpha: 0.15),
                Colors.white
              ],
                      stops: const [
                0.0,
                0.4
              ]))),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('Hello,',
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 16)),
                              StreamBuilder<UserModel?>(
                                stream: user?.uid != null
                                    ? _db.streamUser(user!.uid)
                                    : null,
                                builder: (context, snapshot) {
                                  String name =
                                      snapshot.data?.name ?? 'Patient';
                                  return Text(name.split(' ')[0],
                                      style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900));
                                },
                              ),
                            ])),
                        CircleAvatar(
                            radius: 24,
                            backgroundColor: const Color(0xFFE0E7FF),
                            child: Icon(Icons.person,
                                color: kPrimaryBlue, size: 28)),
                      ]),
                  const SizedBox(height: 30),
                  StreamBuilder<dynamic>(
                    stream: user?.uid != null
                        ? _db.streamAcceptedAppointmentsForPatient(user!.uid)
                        : null,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return _buildEmptyBanner();
                      var docs = snapshot.data!.docs;
                      var future = docs
                          .map((doc) {
                            final d = doc.data() as Map;
                            return {
                              'data': d,
                              'date': parseDate(d['appointmentDateTime']),
                            };
                          })
                          .where((item) => (item['date'] as DateTime)
                              .isAfter(DateTime.now()))
                          .toList();
                      if (future.isEmpty) return _buildEmptyBanner();
                      future.sort((a, b) => (a['date'] as DateTime)
                          .compareTo(b['date'] as DateTime));
                      final next = future.first;
                      return LiveTimerBanner(
                          date: next['date'] as DateTime,
                          doctorName:
                              (next['data'] as Map)['doctor_name'] ?? 'Doctor');
                    },
                  ),
                  const SizedBox(height: 25),
                  const Text('Quick Actions',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 15),
                  Expanded(
                    child: ListView(
                      children: [
                        ActionButton(
                            icon: Icons.person_search_rounded,
                            title: 'Find Doctor',
                            color: Colors.blue,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (c) =>
                                        const DoctorSearchScreen()))),
                        const SizedBox(height: 15),
                        ActionButton(
                            icon: Icons.smart_toy_rounded,
                            title: 'AI Assistant',
                            color: Colors.purple,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (c) => ChangeNotifierProvider(
                                          create: (_) => ChatProvider(),
                                          child: const VoiceChat(),
                                        )))),
                        const SizedBox(height: 15),
                        ActionButton(
                            icon: Icons.map_outlined,
                            title: 'Clinic Map',
                            color: Colors.green.shade600,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (c) => const PatientMapScreen()))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBanner() {
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10))
            ]),
        child: Row(children: [
          const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('No upcoming appointments yet.',
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                SizedBox(height: 5),
                Text('Book Now?',
                    style: TextStyle(
                        color: Colors.black87,
                        fontSize: 20,
                        fontWeight: FontWeight.w900))
              ])),
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.grey.shade100, shape: BoxShape.circle),
              child: const Icon(Icons.calendar_month_rounded,
                  color: Colors.grey, size: 30))
        ]));
  }
}

class LiveTimerBanner extends StatefulWidget {
  final DateTime date;
  final String doctorName;

  const LiveTimerBanner(
      {super.key, required this.date, required this.doctorName});

  @override
  State<LiveTimerBanner> createState() => _LiveTimerBannerState();
}

class _LiveTimerBannerState extends State<LiveTimerBanner> {
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();

    _bannerTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Duration diff = widget.date.difference(DateTime.now());

    if (diff.isNegative) return const SizedBox.shrink();

    String timeText = diff.inDays > 0
        ? '${diff.inDays} Days, ${diff.inHours % 24} Hours'
        : '${diff.inHours} Hours, ${diff.inMinutes % 60} Minutes';

    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [kPrimaryBlue, kPrimaryBlue.withValues(alpha: 0.8)]),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                  color: kPrimaryBlue.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Upcoming Appointment',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          Text(timeText,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text('with Dr. ${widget.doctorName}',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(color: Colors.white, fontSize: 16))
        ]));
  }
}
