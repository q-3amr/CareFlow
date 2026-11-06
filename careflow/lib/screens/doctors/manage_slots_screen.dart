import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/database_service.dart';
import '../../utils/constants.dart';
import '../../utils/date_utils.dart';

class ManageSlotsScreen extends StatefulWidget {
  const ManageSlotsScreen({super.key});

  @override
  State<ManageSlotsScreen> createState() => _ManageSlotsScreenState();
}

class _ManageSlotsScreenState extends State<ManageSlotsScreen> {
  final _db = DatabaseService();
  final User? user = FirebaseAuth.instance.currentUser;

  DateTime _selectedDate = DateTime.now();
  List<String> _mySlots = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSlotsForDate(_selectedDate);
  }

  void _loadSlotsForDate(DateTime date) async {
    setState(() => _isLoading = true);
    try {
      final dateKey = formatDateKey(date);
      final availabilityDoc = await _db.getAvailability(user!.uid, dateKey);

      final List<String> allAddedSlots = availabilityDoc.exists
          ? List<String>.from(availabilityDoc['slots'])
          : [];

      if (allAddedSlots.isEmpty) {
        if (mounted)
          setState(() {
            _mySlots = [];
            _isLoading = false;
          });
        return;
      }

      final appointmentsSnap = await _db.getAppointmentsForDoctorByStatuses(
        user!.uid,
        ['pending', 'accepted'],
      );

      final List<String> bookedTimes = [];
      for (var doc in appointmentsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;

        final DateTime apptDate = parseDate(data['appointmentDateTime']);

        if (apptDate.year == date.year &&
            apptDate.month == date.month &&
            apptDate.day == date.day) {
          bookedTimes.add(formatTimeFromDateTime(apptDate));
        }
      }

      final now = DateTime.now();
      final isToday = date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;

      final freeSlots = allAddedSlots.where((s) {
        if (bookedTimes.contains(s)) return false;

        if (isToday) {
          try {
            final parts = s.split(' ');
            final timeParts = parts[0].split(':');
            int hour = int.parse(timeParts[0]);
            int minute = int.parse(timeParts[1]);
            if (parts.length > 1) {
              if (parts[1].toUpperCase() == 'PM' && hour != 12) hour += 12;
              if (parts[1].toUpperCase() == 'AM' && hour == 12) hour = 0;
            }
            final slotTime =
                DateTime(date.year, date.month, date.day, hour, minute);
            if (slotTime.isBefore(now)) {
              return false;
            }
          } catch (e) {
            
          }
        }
        return true;
      }).toList();

      if (mounted)
        setState(() {
          _mySlots = freeSlots;
          _isLoading = false;
        });
    } catch (e) {
      debugPrint('Error loading slots: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addSlot() async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );

    if (time != null) {
      final now = DateTime.now();
      final slotDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        time.hour,
        time.minute,
      );

      if (slotDateTime.isBefore(now)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot add a time in the past!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (slotDateTime.isBefore(now.add(const Duration(minutes: 20)))) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please give at least 20 min notice.'),
            backgroundColor: Color.fromARGB(255, 255, 193, 7),
          ),
        );
        return;
      }

      int hour = time.hourOfPeriod;
      if (hour == 0) hour = 12;
      final slotString = '$hour:${time.minute.toString().padLeft(2, '0')} '
          '${time.period == DayPeriod.am ? 'AM' : 'PM'}';

      if (!_mySlots.contains(slotString)) {
        setState(() => _mySlots.add(slotString));
        _saveSlots();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Slot already exists or is booked!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeSlot(String slot) {
    setState(() => _mySlots.remove(slot));
    _saveSlots();
  }

  void _saveSlots() async {
    await _db.saveSlots(user!.uid, formatDateKey(_selectedDate), _mySlots);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Manage Availability',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            color: Colors.grey.shade50,
            child: SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 14,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemBuilder: (context, index) {
                  final day = DateTime.now().add(Duration(days: index));
                  final isSelected = day.day == _selectedDate.day;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedDate = day);
                      _loadSlotsForDate(day);
                    },
                    child: Container(
                      width: 60,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? kPrimaryBlue : Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color:
                              isSelected ? kPrimaryBlue : Colors.grey.shade300,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: kPrimaryBlue.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                ),
                              ]
                            : [],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            [
                              'Sun',
                              'Mon',
                              'Tue',
                              'Wed',
                              'Thu',
                              'Fri',
                              'Sat',
                            ][day.weekday % 7],
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Slots for ${_selectedDate.day}/${_selectedDate.month}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _addSlot,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Time'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _mySlots.isEmpty
                    ? Center(
                        child: Text(
                          'No available slots.',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        children: _mySlots
                            .map(
                              (slot) => Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.access_time,
                                    color: Colors.blue,
                                  ),
                                  title: Text(
                                    slot,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _removeSlot(slot),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
          ),
        ],
      ),
    );
  }
}
