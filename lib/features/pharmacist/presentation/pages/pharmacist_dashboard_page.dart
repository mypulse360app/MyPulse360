import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/constants/app_constants.dart';
import '../../../../config/router/route_paths.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/mock/mock_database.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../../shared/presentation/widgets/empty_state_view.dart';
import '../../../../shared/presentation/widgets/sign_out_icon_button.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/pharmacist_providers.dart';
import '../widgets/add_patient_dialog.dart';
import '../../../appointments/presentation/providers/appointments_providers.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../prescriptions/domain/entities/prescription.dart';
import '../../../prescriptions/presentation/providers/prescriptions_providers.dart';
import '../../../doctor/domain/entities/consultation.dart';

/// F1 — Pharmacist Dashboard: queue ordered by wait, amber past 30 min.
class PharmacistDashboardPage extends ConsumerWidget {
  const PharmacistDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep queue synchronized in real-time
    ref.watch(realtimeQueueStreamProvider);
    ref.watch(appointmentsRevisionProvider);
    ref.watch(prescriptionsRevisionProvider);

    final colors = context.colors;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final db = ref.watch(mockDatabaseProvider);
    final List<Prescription> queue = ref.watch(realtimePrescriptionsStreamProvider).valueOrNull ??
        ref.watch(pharmacyQueueProvider(user.id));
    final List<Appointment> appointments = ref.watch(realtimeAppointmentsStreamProvider).valueOrNull ??
        ref.watch(pharmacistTodaysAppointmentsProvider);
    final liveConsultations = ref.watch(realtimeConsultationsStreamProvider).valueOrNull;
    
    final isDesktop = MediaQuery.of(context).size.width >= AppConstants.desktopBreakpoint;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(user.fullName, style: Theme.of(context).textTheme.headlineMedium),
                ),
                FilledButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const AddPatientDialog(),
                    );
                  },
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('Add Patient'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.clinicianAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                if (!isDesktop) const SignOutIconButton(),
              ],
            ),
            const SizedBox(height: 2),
            Text(DateFormatters.full(DateTime.now()), style: TextStyle(fontSize: 12, color: colors.textSecondary)),
            const SizedBox(height: 16),
            Consumer(
              builder: (context, ref, child) {
                final isClosed = ref.watch(clinicClosedProvider);
                return SwitchListTile(
                  title: const Text('Clinic is Closed'),
                  subtitle: Text(isClosed ? 'The clinic is currently marked as closed.' : 'The clinic is currently open.'),
                  value: isClosed,
                  onChanged: (val) => ref.read(clinicClosedProvider.notifier).state = val,
                  activeThumbColor: colors.danger,
                  contentPadding: EdgeInsets.zero,
                );
              },
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Clinic Patient Queue', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  'REALTIME',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Live clinic flow — Check-in, vitals, and dispensing in one queue.', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                    ],
                  ),
                ),
                if (queue.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.clinicianAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long, size: 14, color: colors.clinicianAccent),
                        const SizedBox(width: 6),
                        Text(
                          '${queue.length} ready to dispense',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.clinicianAccent),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            
            Builder(builder: (context) {
              final dispensedIds = ref.watch(dispensedConsultationsProvider);

              // 1. Awaiting Prescription (Consultation completed, needs medication/verification)
              final rawAwaiting = liveConsultations != null
                  ? liveConsultations.where((c) {
                      if (dispensedIds.contains(c.id)) return false;
                      if (c.status != ConsultationStatus.completed) return false;
                      // Exclude if a prescription for this consultation has already been dispensed
                      final isDispensed = queue.any((p) => p.consultationId == c.id && p.status == PrescriptionStatus.dispensed);
                      if (isDispensed) return false;
                      // Exclude if an active prescription for this consultation is already in the queue
                      final hasActiveRx = queue.any((p) => p.consultationId == c.id && p.status == PrescriptionStatus.active);
                      return !hasActiveRx;
                    }).toList()
                  : ref.watch(awaitingPrescriptionProvider).where((c) => !dispensedIds.contains(c.id)).toList();

              // Deduplicate awaiting items by consultation id
              final awaiting = <Consultation>[];
              final seenConsultationIds = <String>{};
              for (final c in rawAwaiting) {
                if (seenConsultationIds.add(c.id)) {
                  awaiting.add(c);
                }
              }

              final combined = <Map<String, dynamic>>[];
              
              // 1. Appointments (Pending / Checked-in) -> Log Vitals
              for (final a in appointments) {
                // Skip if it's completed or cancelled
                if (a.status == AppointmentStatus.completed || a.status == AppointmentStatus.cancelled) continue;
                combined.add({'type': 'appointment', 'data': a, 'time': a.scheduledAt});
              }
              
              // 2. Awaiting Prescription (Consultation completed, needs medication/verification)
              for (final c in awaiting) {
                final appt = appointments.where((a) => a.id == c.appointmentId).firstOrNull;
                combined.add({'type': 'awaiting', 'data': c, 'time': appt?.scheduledAt ?? DateTime.now(), 'appt': appt});
              }
              
              // 3. Prescriptions (Queue for verification/dispensing - ONLY ACTIVE, NOT DISPENSED!)
              final activeQueue = queue.where((p) =>
                  p.status == PrescriptionStatus.active &&
                  !dispensedIds.contains(p.consultationId)
              ).toList();
              for (final p in activeQueue) {
                combined.add({'type': 'prescription', 'data': p, 'time': p.issuedDate});
              }
              
              combined.sort((a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime));
              
              if (combined.isEmpty) {
                return const EmptyStateView(
                  title: 'Queue is empty',
                  message: 'No patients in the queue right now.',
                  icon: Icons.inbox_outlined,
                );
              }
              
              return Column(
                children: combined.map((item) {
                  if (item['type'] == 'appointment') {
                    final appt = item['data'] as Appointment;
                    final mockUser = db.userById(appt.patientId);
                    final name = mockUser?.fullName ?? ref.watch(userProfileProvider(appt.patientId)).valueOrNull?.fullName ?? 'Patient';
                    final consultation = liveConsultations?.where((c) => c.appointmentId == appt.id).firstOrNull ??
                        ref.watch(consultationForAppointmentProvider(appt.id)).valueOrNull;
                    final temp = consultation?.vitals.temperatureCelsius;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: InkWell(
                        onTap: () async {
                          final currentConsultation = liveConsultations?.where((c) => c.appointmentId == appt.id).firstOrNull ??
                              ref.read(consultationForAppointmentProvider(appt.id)).valueOrNull;
                          String consultationId;
                          if (currentConsultation != null) {
                            consultationId = currentConsultation.id;
                          } else {
                            consultationId = await ref.read(pharmacistRepositoryProvider).getOrCreateConsultation(
                              appointmentId: appt.id,
                              patientId: appt.patientId,
                              doctorId: appt.doctorId,
                            );
                          }
                          if (context.mounted) {
                            context.push(RoutePaths.processPrescription(consultationId));
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardTheme.color,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            children: [
                              AvatarWidget(name: name, size: 40, color: colors.clinicianAccent),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            appt.status == AppointmentStatus.completed ? 'Completed' : 'Checked-in',
                                            style: const TextStyle(fontSize: 10, color: Colors.white70),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${DateFormatters.time(appt.scheduledAt)} · ${appt.appointmentType}',
                                      style: TextStyle(fontSize: 13, color: colors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: temp != null
                                      ? colors.danger.withValues(alpha: 0.1)
                                      : colors.clinicianAccent.withValues(alpha: 0.1),
                                  border: Border.all(
                                    color: temp != null
                                        ? colors.danger
                                        : colors.clinicianAccent.withValues(alpha: 0.4),
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      temp != null ? Icons.thermostat : Icons.assignment_outlined,
                                      size: 16,
                                      color: temp != null
                                          ? colors.danger
                                          : colors.clinicianAccent,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      temp != null
                                          ? '${temp.toStringAsFixed(1)} °C'
                                          : 'Log Vitals & Rx',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: temp != null
                                            ? colors.danger
                                            : colors.clinicianAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  } else if (item['type'] == 'awaiting') {
                    final c = item['data'] as Consultation;
                    final appt = item['appt'] as Appointment?;
                    final mockUser = db.userById(c.patientId);
                    final name = mockUser?.fullName ?? ref.watch(userProfileProvider(c.patientId)).valueOrNull?.fullName ?? 'Patient';
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: InkWell(
                        onTap: () => context.push(RoutePaths.processPrescription(c.id)),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardTheme.color,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            children: [
                              AvatarWidget(name: name, size: 40, color: colors.clinicianAccent),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Consultation Completed',
                                            style: TextStyle(fontSize: 10, color: Colors.blue[400]),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      appt != null ? '${DateFormatters.time(appt.scheduledAt)} · ${appt.appointmentType}' : 'No appointment details',
                                      style: TextStyle(fontSize: 13, color: colors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: colors.clinicianAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.medication, size: 16, color: colors.clinicianAccent),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Process Prescription',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: colors.clinicianAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  } else {
                    final rx = item['data'] as Prescription;
                    final mockUser = db.userById(rx.patientId);
                    final name = mockUser?.fullName ?? ref.watch(userProfileProvider(rx.patientId)).valueOrNull?.fullName ?? 'Patient';
                    final medNames = rx.items.map((i) => i.medicationName).join(', ');
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: InkWell(
                        onTap: () => context.push(RoutePaths.verify(rx.id)),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardTheme.color,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            children: [
                              AvatarWidget(name: name, size: 40, color: colors.clinicianAccent),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Prescription Ready',
                                            style: TextStyle(fontSize: 10, color: Colors.green[400]),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Meds: $medNames',
                                      style: TextStyle(fontSize: 13, color: colors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: colors.clinicianAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.receipt_long, size: 16, color: colors.clinicianAccent),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Verify & Dispense',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: colors.clinicianAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                }).toList(),
              );
            }),
          ],
        ),
      ),
    );
  }
}
