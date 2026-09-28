import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/async_section.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../patient/presentation/providers/patient_providers.dart';
import '../../domain/entities/time_slot.dart';
import '../providers/appointments_providers.dart';
import '../widgets/month_calendar.dart';
import '../widgets/time_slot_grid.dart';

const _appointmentTypes = [
  'General Checkup',
  'Follow-up',
  'New Patient',
  'Diabetes Follow-up',
];
const _customType = 'Custom';

/// P6 â€” Book Appointment: month calendar + slot grid + booking summary,
/// matching the Â§4.1.6B reference (calendar + slot grid with
/// booked/selected/disabled states).
class BookAppointmentPage extends ConsumerStatefulWidget {
  const BookAppointmentPage({super.key});

  @override
  ConsumerState<BookAppointmentPage> createState() =>
      _BookAppointmentPageState();
}

class _BookAppointmentPageState extends ConsumerState<BookAppointmentPage> {
  late DateTime _selectedDate;
  TimeSlot? _selectedSlot;
  String? _selectedDoctorId;
  final String _type = _appointmentTypes.first;
  final _customTypeController = TextEditingController();
  bool _booking = false;
  String? _selectedReason;

  bool get _isCustom => _type == _customType;
  bool get _customTypeMissing =>
      _isCustom && _customTypeController.text.trim().isEmpty;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _customTypeController.dispose();
    super.dispose();
  }

  Future<void> _book(String doctorId, String patientId) async {
    final slot = _selectedSlot;
    if (slot == null || _customTypeMissing) return;
    
    final isClinicClosed = ref.read(clinicClosedProvider);
    if (isClinicClosed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The clinic is currently closed. Booking is disabled.')),
      );
      return;
    }

    setState(() => _booking = true);
    try {
      final repo = ref.read(appointmentsRepositoryProvider);
      
      // Check if patient already has an appointment on this day
      final existingAppts = await repo.getForPatient(patientId);
      final hasApptOnDay = existingAppts.any((appt) => 
        appt.status.name != 'cancelled' &&
        appt.scheduledAt.year == slot.dateTime.year &&
        appt.scheduledAt.month == slot.dateTime.month &&
        appt.scheduledAt.day == slot.dateTime.day
      );
      
      if (hasApptOnDay) {
        if (!mounted) return;
        setState(() => _booking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You can only book one appointment per day.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          )
        );
        return;
      }

      await repo.book(
            patientId: patientId,
            doctorId: doctorId,
            scheduledAt: slot.dateTime,
            appointmentType: _selectedReason ?? 'General Checkup',
            reasonForVisit: _selectedReason,
          );
      ref.read(appointmentsRevisionProvider.notifier).state++;
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      // Someone booked this slot between the grid rendering and Confirm.
      // Refresh so the grid shows the truth, and clear the stale selection.
      ref.read(appointmentsRevisionProvider.notifier).state++;
      if (!mounted) return;
      setState(() {
        _booking = false;
        _selectedSlot = null;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final profileAsync = ref.watch(patientProfileProvider(user.id));

    return Scaffold(
      backgroundColor: colors.patientAccent, // Rich accent color for header
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: const [],
      ),
      body: AsyncSection(
        value: profileAsync,
        data: (profile) {
          final doctorsAsync = ref.watch(availableDoctorsProvider);
          return AsyncSection(
            value: doctorsAsync,
            data: (availableDoctors) {

          if (availableDoctors.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No doctors available. Contact the clinic.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            );
          }

          final effectiveDoctorId = _selectedDoctorId;
          final doctor = effectiveDoctorId == null ? null : availableDoctors.firstWhere(
            (d) => d.id == effectiveDoctorId,
            orElse: () => availableDoctors.first,
          );

          final slotsAsync = doctor == null ? const AsyncValue<List<TimeSlot>>.data([]) : ref.watch(
            availableSlotsProvider((doctorId: doctor.id, date: _selectedDate)),
          );

          return Stack(
            children: [
              // Premium Gradient Header Background
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 340,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.8, -0.5),
                      radius: 1.5,
                      colors: [
                        colors.patientAccent.withValues(alpha: 0.8),
                        const Color(0xFF101015),
                      ],
                    ),
                  ),
                ),
              ),
              
              Column(
                children: [
                  // Header Content
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [

                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedDoctorId,
                                      hint: const Text(
                                        'Select a Doctor',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 24),
                                      dropdownColor: Theme.of(context).cardTheme.color,
                                      isExpanded: true,
                                      onChanged: (newId) {
                                        if (newId != null) {
                                          setState(() {
                                            _selectedDoctorId = newId;
                                            _selectedSlot = null; // reset slot on doctor change
                                          });
                                        }
                                      },
                                      selectedItemBuilder: (BuildContext context) {
                                        return availableDoctors.map<Widget>((doc) {
                                          return Container(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              doc.fullName,
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          );
                                        }).toList();
                                      },
                                      items: availableDoctors.map((doc) {
                                        return DropdownMenuItem<String>(
                                          value: doc.id,
                                          child: Text(
                                            doc.fullName,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: colors.textPrimary,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2),
                                const SizedBox(height: 6),
                                
                              ],
                            ),
                          ),
                          Container(
                            width: 85,
                            height: 85,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF1A1A24),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 8),
                                )
                              ],
                              image: doctor?.avatarUrl != null && doctor!.avatarUrl!.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(doctor.avatarUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: (doctor?.avatarUrl == null || doctor!.avatarUrl!.isEmpty)
                                ? Icon(Icons.person_outline_rounded, size: 40, color: Colors.white.withValues(alpha: 0.5))
                                : null,
                          ).animate().scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack),
                        ],
                      ),
                    ),
                  ),
                  
                  // Bottom Sheet Content
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, -5),
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(24, 36, 24, 24 + MediaQuery.paddingOf(context).bottom),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (effectiveDoctorId == null)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 60),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.person_search_rounded, size: 64, color: colors.textTertiary),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Please select a doctor to see their availability.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: colors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else ...[
                                MonthCalendar(
                                  doctorId: effectiveDoctorId,
                                  selectedDate: _selectedDate,
                                  onSelected: (d) => setState(() {
                                    _selectedDate = d;
                                    _selectedSlot = null;
                                  }),
                                ),
                                const SizedBox(height: 36),
                                
                                AsyncSection(
                                  value: slotsAsync,
                                  data: (rawSlots) {
                                    final isClinicClosed = ref.watch(clinicClosedProvider);
                                    
                                    final slots = rawSlots.map((s) {
                                      final selected =
                                          _selectedSlot != null &&
                                          s.dateTime == _selectedSlot!.dateTime;
                                      return s.copyWith(isSelected: selected);
                                    }).toList();

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Available Time',
                                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        if (isClinicClosed)
                                        Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: colors.danger.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: colors.danger.withValues(alpha: 0.3)),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.report_problem_outlined, color: colors.danger),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  'The clinic has been temporarily closed by staff for today. Booking is disabled.',
                                                  style: TextStyle(color: colors.danger, fontSize: 14),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else if (slots.every((s) => s.isDisabled))
                                        Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).cardTheme.color,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: colors.border),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.event_busy_rounded, color: colors.textSecondary),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  _selectedDate.weekday == DateTime.sunday
                                                      ? 'The clinic is closed on Sundays.'
                                                      : slots.any((s) => s.isDoctorOnLeave)
                                                          ? '${doctor!.fullName} is on leave this day.'
                                                          : 'No slots available this day. Try selecting another date.',
                                                  style: TextStyle(color: colors.textSecondary, fontSize: 14),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        TimeSlotGrid(
                                          slots: slots,
                                          onSelect: (s) => setState(() => _selectedSlot = s),
                                        ),
                                      
                                      const SizedBox(height: 32),
Text('Reason for Visit', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 18)),
const SizedBox(height: 12),
_ReasonSelector(selectedReason: _selectedReason, onSelect: (reason) => setState(() => _selectedReason = reason)),
const SizedBox(height: 48),
                                      
                                      SizedBox(
                                        width: double.infinity,
                                        child: GestureDetector(
                                          onTap: isClinicClosed || _selectedSlot == null || _booking 
                                              ? null 
                                              : () => _book(doctor!.id, user.id),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            height: 56,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(28),
                                              color: isClinicClosed || _selectedSlot == null 
                                                  ? colors.surfaceMuted 
                                                  : colors.patientAccent,
                                            ),
                                            child: Center(
                                              child: _booking 
                                                ? const SizedBox(
                                                    width: 24, height: 24, 
                                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                                                  )
                                                : Text(
                                                    'Book Appointment',
                                                    style: TextStyle(
                                                      fontSize: 16, 
                                                      fontWeight: FontWeight.w600,
                                                      color: isClinicClosed || _selectedSlot == null || _selectedReason == null ? colors.textTertiary : Colors.white,
                                                    ),
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
            },
          );
        },
      ),
    );
  }
}



class _ReasonSelector extends StatelessWidget {
  final String? selectedReason;
  final ValueChanged<String> onSelect;

  const _ReasonSelector({required this.selectedReason, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reasons = [
      ('General Consultation', 'Standard visit for new or unspecific symptoms.'),
      ('Routine Checkup', 'Annual or periodic health evaluation and physical.'),
      ('Chronic Condition Management', 'Management and review of ongoing health conditions.'),
      ('Follow-up & Diagnostics', 'Review test results or follow up on a previous visit.'),
    ];

    return Column(
      children: reasons.map((r) {
        final isSelected = selectedReason == r.$1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: InkWell(
            onTap: () => onSelect(r.$1),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: isSelected ? colors.patientAccent : colors.border),
                borderRadius: BorderRadius.circular(12),
                color: isSelected ? colors.patientAccent.withValues(alpha: 0.1) : Colors.transparent,
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: isSelected ? colors.patientAccent : colors.textTertiary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.$1, style: TextStyle(fontWeight: FontWeight.w600, color: colors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(r.$2, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}




