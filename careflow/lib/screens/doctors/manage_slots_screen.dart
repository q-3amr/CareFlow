import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_tokens.dart';
import '../../utils/date_utils.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_empty_state.dart';

class ManageSlotsScreen extends StatefulWidget {
  const ManageSlotsScreen({super.key});

  @override
  State<ManageSlotsScreen> createState() => _ManageSlotsScreenState();
}

class _ManageSlotsScreenState extends State<ManageSlotsScreen> {
  final _db = DatabaseService();
  final User? user = FirebaseAuth.instance.currentUser;

  static const List<String> _weekdays = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];
  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

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
        if (mounted) {
          setState(() {
            _mySlots = [];
            _isLoading = false;
          });
        }
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
          } catch (_) {
            // Ignore malformed slot strings.
          }
        }
        return true;
      }).toList();

      if (mounted) {
        setState(() {
          _mySlots = freeSlots;
          _isLoading = false;
        });
      }
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
          SnackBar(
            content: const Text('Cannot add a time in the past.'),
            backgroundColor: AppColors.destructive,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (slotDateTime.isBefore(now.add(const Duration(minutes: 20)))) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please give at least 20 min notice.'),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
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
          SnackBar(
            content: const Text('Slot already exists or is booked.'),
            backgroundColor: AppColors.destructive,
            behavior: SnackBarBehavior.floating,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimary(isDark);
    final textSecondary = AppColors.textSecondary(isDark);
    final cardBg = AppColors.card(isDark);
    final borderColor = AppColors.border(isDark);

    final dateLabel =
        '${_weekdays[_selectedDate.weekday % 7]}, ${_months[_selectedDate.month - 1]} ${_selectedDate.day}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage availability'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 92,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 14,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              itemBuilder: (context, index) {
                final day = DateTime.now().add(Duration(days: index));
                final isSelected = day.day == _selectedDate.day &&
                    day.month == _selectedDate.month &&
                    day.year == _selectedDate.year;
                return Container(
                  width: 54,
                  margin: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Material(
                    color: isSelected ? AppColors.primary : cardBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.medium,
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : borderColor,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: AppRadius.medium,
                      onTap: () {
                        setState(() => _selectedDate = day);
                        _loadSlotsForDate(day);
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _weekdays[day.weekday % 7],
                            style: AppTypography.caption.copyWith(
                              color: isSelected ? Colors.white : textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${day.day}',
                            style: AppTypography.title.copyWith(
                              color: isSelected ? Colors.white : textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available slots',
                        style:
                            AppTypography.section.copyWith(color: textPrimary),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        dateLabel,
                        style: AppTypography.caption
                            .copyWith(color: textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                ElevatedButton.icon(
                  onPressed: _addSlot,
                  icon: const Icon(
                    Icons.add_rounded,
                    size: AppIconSize.md,
                  ),
                  label: const Text('Add time'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _mySlots.isEmpty
                    ? const AppEmptyState(
                        icon: Icons.schedule_rounded,
                        title: 'No slots for this day',
                        message: 'Add a time to open availability.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          AppSpacing.xl,
                        ),
                        itemCount: _mySlots.length,
                        itemBuilder: (context, index) {
                          final slot = _mySlots[index];
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: AppCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding:
                                        const EdgeInsets.all(AppSpacing.sm),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                          alpha: isDark ? 0.18 : 0.10),
                                      borderRadius: AppRadius.small,
                                    ),
                                    child: const Icon(
                                      Icons.access_time_rounded,
                                      color: AppColors.primary,
                                      size: AppIconSize.md,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Text(
                                      slot,
                                      style: AppTypography.label
                                          .copyWith(color: textPrimary),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Remove slot',
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: AppColors.destructive,
                                      size: AppIconSize.md,
                                    ),
                                    onPressed: () => _removeSlot(slot),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
