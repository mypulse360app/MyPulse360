import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/mock/mock_database.dart';
import '../../../../shared/presentation/widgets/app_card.dart';
import '../../../../shared/presentation/widgets/async_section.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../../../shared/presentation/widgets/secondary_button.dart';
import '../../../../shared/presentation/widgets/status_badge.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../doctor/presentation/providers/doctor_providers.dart';
import '../../domain/entities/appointment.dart';
import '../providers/appointments_providers.dart';
import 'reschedule_page.dart';

final appointmentExtraDetailsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, appointmentId) async {
  final supabase = Supabase.instance.client;
  
  // 1. Get Temperature Log
  final tempRes = await supabase.from('temperature_logs').select().eq('appointment_id', appointmentId).maybeSingle();
  
  // 2. Get Consultation
  final consultRes = await supabase.from('consultations').select('id, notes').eq('appointment_id', appointmentId).maybeSingle();
  
  List<dynamic> prescriptions = [];
  if (consultRes != null) {
    // 3. Get Prescriptions
    final pxRes = await supabase.from('prescriptions').select('id, status, created_at, prescription_items(medication_name, dosage, frequency)').eq('consultation_id', consultRes['id']);
    prescriptions = pxRes as List<dynamic>;
  }

  return {
    'temperature': tempRes != null ? tempRes['temperature'] : null,
    'consultation_notes': consultRes != null ? consultRes['notes'] : null,
    'prescriptions': prescriptions,
  };
});

/// Full detail view of a single appointment — doctor, clinic, date/time —
/// with the option to reschedule.
class AppointmentDetailPage extends ConsumerWidget {
  const AppointmentDetailPage({super.key, required this.appointmentId});

  final String appointmentId;

  StatusTone _tone(AppointmentStatus status) => switch (status) {
    AppointmentStatus.pending => StatusTone.neutral,
    AppointmentStatus.confirmed => StatusTone.success,
    AppointmentStatus.completed => StatusTone.info,
    AppointmentStatus.cancelled => StatusTone.danger,
    AppointmentStatus.scheduled => StatusTone.neutral,
    AppointmentStatus.inProgress => StatusTone.warning,
    AppointmentStatus.rescheduled => StatusTone.warning,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final appointmentsAsync = ref.watch(patientAppointmentsProvider(user.id));

    return Scaffold(
      appBar: const LargeTitleAppBar(title: 'Appointment'),
      body: AsyncSection(
        value: appointmentsAsync,
        data: (appointments) {
          final matches = appointments.where((a) => a.id == appointmentId);
          if (matches.isEmpty) {
            return const Center(child: Text('Appointment not found'));
          }
          final appointment = matches.first;
          final availableDoctors = ref.watch(availableDoctorsProvider).valueOrNull ?? [];
          final doctor = availableDoctors.where((d) => d.id == appointment.doctorId).firstOrNull;
          final doctorProfile = ref.watch(
            doctorProfileProvider(appointment.doctorId),
          );
          final clinics = ref.watch(mockDatabaseProvider).clinics;
          final matchingClinics = clinics.where(
            (c) => c.id == appointment.clinicId,
          );
          final clinic = matchingClinics.isNotEmpty
              ? matchingClinics.first
              : (clinics.isEmpty ? null : clinics.first);
          final canReschedule =
              appointment.status != AppointmentStatus.completed &&
              appointment.status != AppointmentStatus.cancelled;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: StatusBadge(
                  label: appointment.status.label,
                  tone: _tone(appointment.status),
                ),
              ),
              const SizedBox(height: 10),
              AppCard(
                child: Row(
                  children: [
                    AvatarWidget(
                      name: doctor?.fullName ?? 'Doctor',
                      size: 52,
                      color: colors.clinicianAccent,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doctor?.fullName ?? 'Doctor',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (doctorProfile != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              doctorProfile.specialization,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _DetailRow(
                icon: Icons.calendar_today_outlined,
                label: 'Date & Time',
                value:
                    '${DateFormatters.full(appointment.scheduledAt)} at ${DateFormatters.time(appointment.scheduledAt)}',
              ),
              _DetailRow(
                icon: Icons.medical_services_outlined,
                label: 'Type',
                value:
                    '${appointment.appointmentType} · ${appointment.durationMinutes} minutes',
              ),
              if (appointment.reasonForVisit != null)
                _DetailRow(
                  icon: Icons.notes_outlined,
                  label: 'Reason',
                  value: appointment.reasonForVisit!,
                ),
              if (clinic != null)
                _DetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'Clinic',
                  value: '${clinic.name}\n${clinic.address}',
                ),
              if (clinic != null)
                _DetailRow(
                  icon: Icons.phone_outlined,
                  label: 'Clinic Phone',
                  value: clinic.phone,
                ),
              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, _) {
                  final detailsAsync = ref.watch(appointmentExtraDetailsProvider(appointmentId));
                  return detailsAsync.when(
                    data: (data) {
                      final hasData = data['temperature'] != null || data['consultation_notes'] != null || (data['prescriptions'] as List).isNotEmpty;
                      if (!hasData) return const SizedBox.shrink();

                      return AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Post-Appointment Details', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 16),
                            if (data['temperature'] != null)
                              _DetailRow(
                                icon: Icons.thermostat_outlined,
                                label: 'Body Temperature',
                                value: '${data['temperature']} °C',
                              ),
                            if (data['consultation_notes'] != null)
                              _DetailRow(
                                icon: Icons.medical_information_outlined,
                                label: 'Consultation Notes',
                                value: data['consultation_notes'],
                              ),
                            if ((data['prescriptions'] as List).isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text('Prescriptions', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textSecondary)),
                              const SizedBox(height: 8),
                              ...(data['prescriptions'] as List).map((px) {
                                final items = px['prescription_items'] as List;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: items.map((item) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: Row(
                                        children: [
                                          Icon(Icons.medication_outlined, size: 16, color: colors.clinicianAccent),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text('${item['medication_name']} - ${item['dosage'] ?? ''}\n${item['frequency'] ?? ''}', style: TextStyle(fontSize: 13)),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                );
                              }),
                            ],
                          ],
                        ),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, st) => Text('Error loading details: $e'),
                  );
                },
              ),
              if (canReschedule) ...[
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Reschedule',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReschedulePage(appointment: appointment),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _CancelAppointmentButton(appointmentId: appointment.id),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Its own small stateful widget (rather than a loading bool on the parent
/// page) because [AppointmentDetailPage] is a plain [ConsumerWidget] and
/// this button is the only thing on the page that needs to track an
/// in-flight write.
class _CancelAppointmentButton extends ConsumerStatefulWidget {
  const _CancelAppointmentButton({required this.appointmentId});

  final String appointmentId;

  @override
  ConsumerState<_CancelAppointmentButton> createState() =>
      _CancelAppointmentButtonState();
}

class _CancelAppointmentButtonState
    extends ConsumerState<_CancelAppointmentButton> {
  bool _cancelling = false;

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    try {
      await ref
          .read(appointmentsRepositoryProvider)
          .updateStatus(widget.appointmentId, AppointmentStatus.cancelled);
      ref.read(appointmentsRevisionProvider.notifier).state++;
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SecondaryButton(
      label: _cancelling ? 'Cancelling…' : 'Cancel Appointment',
      onPressed: _cancelling ? null : _cancel,
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Icon(icon, size: 16, color: colors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: colors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 13.5, color: colors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
