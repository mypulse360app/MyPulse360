import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/route_paths.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../../shared/presentation/widgets/empty_state_view.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../doctor/domain/entities/consultation.dart' show Consultation, ConsultationStatus;
import '../../../prescriptions/domain/entities/prescription.dart' show Prescription, PrescriptionStatus;
import '../../../../shared/mock/mock_database.dart';
import '../providers/pharmacist_providers.dart';

class PharmacistPrescriptionsPage extends ConsumerWidget {
  const PharmacistPrescriptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final db = ref.watch(mockDatabaseProvider);
    
    final dispensedIds = ref.watch(dispensedConsultationsProvider);
    final user = ref.watch(currentUserProvider);
    
    if (user == null) return const SizedBox.shrink();

    final queue = ref.watch(realtimePrescriptionsStreamProvider).valueOrNull ??
        ref.watch(pharmacyQueueProvider(user.id)) ?? [];
    final liveConsultations = ref.watch(realtimeConsultationsStreamProvider).valueOrNull;
    final appointments = ref.watch(realtimeAppointmentsStreamProvider).valueOrNull ??
        ref.watch(pharmacistTodaysAppointmentsProvider) ?? [];

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
    
    // 1. Awaiting Prescription (Consultation completed, needs medication/verification)
    for (final c in awaiting) {
      final appt = appointments.where((a) => a.id == c.appointmentId).firstOrNull;
      combined.add({'type': 'awaiting', 'data': c, 'time': appt?.scheduledAt ?? DateTime.now(), 'appt': appt});
    }
    
    // 2. Prescriptions (Queue for verification/dispensing - ONLY ACTIVE, NOT DISPENSED!)
    final activeQueue = queue.where((p) =>
        p.status == PrescriptionStatus.active &&
        !dispensedIds.contains(p.consultationId)
    ).toList();
    for (final p in activeQueue) {
      combined.add({'type': 'prescription', 'data': p, 'time': p.issuedDate});
    }
    
    combined.sort((a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime));

    return Scaffold(
      appBar: const LargeTitleAppBar(title: 'Pharmacy', showBack: false),
      body: combined.isEmpty
          ? const Padding(
              padding: EdgeInsets.only(top: 60),
              child: EmptyStateView(
                title: 'No pending prescriptions',
                message: 'Patients waiting for medication will show up here.',
                icon: Icons.medication_outlined,
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: combined.map((item) {
                if (item['type'] == 'awaiting') {
                  final c = item['data'] as Consultation;
                  final appt = item['appt'] as dynamic; // Appointment?
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
            ),
    );
  }
}
