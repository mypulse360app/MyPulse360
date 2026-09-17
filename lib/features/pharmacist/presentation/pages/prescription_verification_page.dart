import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/mock/mock_database.dart';
import '../../../../shared/presentation/widgets/app_card.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../doctor/domain/entities/consultation.dart';
import '../../../prescriptions/domain/entities/prescription.dart';
import '../../../prescriptions/presentation/providers/prescriptions_providers.dart';
import '../providers/pharmacist_providers.dart';
import '../widgets/dispense_action_bar.dart';
import '../widgets/verification_checklist.dart';

/// F2 — Prescription verification: every check resolved before Dispense
/// becomes reachable.
class PrescriptionVerificationPage extends ConsumerStatefulWidget {
  const PrescriptionVerificationPage({super.key, required this.prescriptionId});

  final String prescriptionId;

  @override
  ConsumerState<PrescriptionVerificationPage> createState() => _PrescriptionVerificationPageState();
}

class _PrescriptionVerificationPageState extends ConsumerState<PrescriptionVerificationPage> {
  final Set<int> _checked = {};
  bool _dispensing = false;

  Future<void> _dispense(Prescription prescription) async {
    setState(() => _dispensing = true);
    await ref
        .read(prescriptionsRepositoryProvider)
        .updateStatus(prescription.id, PrescriptionStatus.dispensed);
    ref.read(prescriptionsRevisionProvider.notifier).state++;
    if (!mounted) return;
    setState(() => _dispensing = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final liveQueue = ref.watch(realtimePrescriptionsStreamProvider).valueOrNull;
    final queue = liveQueue ?? ref.watch(pharmacyQueueProvider(user.id));
    final matches = (queue ?? const <Prescription>[]).where((p) => p.id == widget.prescriptionId);
    if (matches.isEmpty) {
      return const Scaffold(body: Center(child: Text('Prescription not found')));
    }
    final prescription = matches.first;
    final patient = ref.watch(userProfileProvider(prescription.patientId)).valueOrNull;
    final doctor = ref.watch(userProfileProvider(prescription.doctorId)).valueOrNull;
    
    // Look up consultation by ID, or fallback to patient's latest consultation
    Consultation? consultation;
    if (prescription.consultationId != null) {
      consultation = ref.watch(consultationProvider(prescription.consultationId!)).valueOrNull;
    }
    consultation ??= ref
        .watch(realtimeConsultationsStreamProvider)
        .valueOrNull
        ?.where((c) => c.patientId == prescription.patientId)
        .lastOrNull;
    consultation ??= ref
        .watch(mockDatabaseProvider)
        .consultations
        .where((c) => c.patientId == prescription.patientId)
        .lastOrNull;

    final allChecked = _checked.length == kVerificationSteps.length;

    return Scaffold(
      appBar: const LargeTitleAppBar(title: 'Verify Prescription'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient & Doctor Info Card
            AppCard(
              child: Row(
                children: [
                  AvatarWidget(name: patient?.fullName ?? 'Patient', color: colors.clinicianAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(patient?.fullName ?? 'Patient', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          'Prescribed by ${doctor?.fullName ?? 'Doctor'} · Issued ${DateFormatters.short(prescription.issuedDate)}',
                          style: TextStyle(fontSize: 12, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Doctor Consultation Notes
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.clinicianAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.clinicianAccent.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.assignment_outlined, size: 18, color: colors.clinicianAccent),
                      const SizedBox(width: 8),
                      Text(
                        'DOCTOR CONSULTATION NOTES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: colors.clinicianAccent,
                        ),
                      ),
                      if (consultation?.diagnosis != null && consultation!.diagnosis!.isNotEmpty) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.clinicianAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            consultation.diagnosis!,
                            style: TextStyle(fontSize: 10.5, color: colors.clinicianAccent, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    consultation?.notes != null && consultation!.notes!.isNotEmpty
                        ? consultation.notes!
                        : 'No detailed consultation notes recorded.',
                    style: const TextStyle(fontSize: 13.5, height: 1.4),
                  ),
                  if (consultation?.recommendations != null && consultation!.recommendations!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Recommendations: ${consultation.recommendations!}',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: colors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Prescribed Medication Section
            Row(
              children: [
                Icon(Icons.medication_outlined, size: 18, color: colors.textPrimary),
                const SizedBox(width: 8),
                Text('Prescribed Medication', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Text(
                  '${prescription.items.length} ${prescription.items.length == 1 ? 'item' : 'items'}',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Verify that prescribed medication matches the doctor\'s consultation notes above.',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
            const SizedBox(height: 10),

            for (final item in prescription.items) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colors.clinicianAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.medical_services_outlined, size: 18, color: colors.clinicianAccent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.medicationName} ${item.strength}'.trim(),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item.form.toUpperCase()} · Qty: ${item.quantity} ${item.unit}',
                                style: TextStyle(fontSize: 12, color: colors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        if (item.refillsAllowed > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${item.refillsAllowed} refills',
                              style: TextStyle(fontSize: 11, color: Colors.blue[400], fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dosage: ${item.frequency} for ${item.durationDays} days',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          if (item.instructions.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Instructions: ${item.instructions}',
                              style: TextStyle(fontSize: 12, color: colors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Verification Checklist
            Text('Verification Checklist', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Complete all checks to verify against doctor\'s consultation before dispensing.',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
            const SizedBox(height: 8),
            VerificationChecklist(
              checked: _checked,
              onChanged: (i) => setState(() => _checked.contains(i) ? _checked.remove(i) : _checked.add(i)),
            ),
          ],
        ),
      ),
      bottomNavigationBar: DispenseActionBar(
        enabled: allChecked,
        onDispense: () => _dispense(prescription),
        loading: _dispensing,
      ),
    );
  }
}
