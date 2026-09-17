import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/env/env.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/data/supabase_providers.dart';
import '../../../../shared/mock/mock_database.dart';
import '../../../../shared/presentation/widgets/allergy_banner.dart';
import '../../../../shared/presentation/widgets/app_card.dart';
import '../../../../shared/presentation/widgets/async_section.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../../shared/utils/id_generator.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/presentation/providers/appointments_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../doctor/domain/entities/consultation.dart';
import '../../../doctor/presentation/widgets/sticky_submit_bar.dart';
import '../../../patient/presentation/providers/patient_providers.dart';
import '../../../prescriptions/domain/entities/prescription.dart';
import '../../../prescriptions/domain/entities/prescription_item.dart';
import '../../../prescriptions/presentation/providers/prescriptions_providers.dart';
import '../providers/pharmacist_providers.dart';
import '../widgets/drug_interaction_alert.dart';
import '../widgets/prescription_item_form.dart';
import '../widgets/verification_checklist.dart';

class ProcessPrescriptionPage extends ConsumerStatefulWidget {
  const ProcessPrescriptionPage({super.key, required this.consultationId});

  final String consultationId;

  @override
  ConsumerState<ProcessPrescriptionPage> createState() =>
      _ProcessPrescriptionPageState();
}

class _ProcessPrescriptionPageState
    extends ConsumerState<ProcessPrescriptionPage> {
  final List<PrescriptionItem> _items = [];
  final Set<int> _checked = {};
  bool _submitting = false;
  bool _initializedFromNotes = false;

  void _populateFromDoctorNotes(String rawNotes) {
    if (_items.isNotEmpty) return;

    final notes = rawNotes.trim();
    if (notes.isEmpty) return;

    final candidateLines = notes
        .split(RegExp(r'[\n\r,]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    for (final raw in candidateLines) {
      var clean = raw
          .replaceFirst(RegExp(r'^[-\*•]\s*'), '')
          .replaceFirst(RegExp(r'^Rx:\s*', caseSensitive: false), '')
          .replaceFirst(RegExp(r'^Prescribing:\s*', caseSensitive: false), '')
          .replaceFirst(RegExp(r'^Prescribing\s+', caseSensitive: false), '')
          .trim();

      final match = RegExp(
        r'Prescribing\s+([A-Za-z0-9\s]+?)(?:\s+for|\s+\d+x|\.|$)',
        caseSensitive: false,
      ).firstMatch(raw);
      if (match != null && match.group(1) != null) {
        clean = match.group(1)!.trim();
      }

      if (clean.isNotEmpty && clean.length < 80) {
        final strengthMatch = RegExp(
          r'(\d+\s*(?:mg|g|ml|mcg|tablets?|capsules?))',
          caseSensitive: false,
        ).firstMatch(clean);
        String name = clean;
        String strength = 'As prescribed';
        if (strengthMatch != null) {
          strength = strengthMatch.group(1)!;
          name = clean.replaceAll(strengthMatch.group(0)!, '').trim();
          if (name.isEmpty) name = clean;
        }

        _items.add(
          PrescriptionItem(
            id: generateId(),
            medicationName: name,
            strength: strength,
            form: 'tablet',
            quantity: 14,
            unit: 'tablets',
            frequency: '2x daily',
            durationDays: 7,
            instructions: 'Take as directed in doctor consultation',
          ),
        );
      }
    }

    if (_items.isEmpty) {
      _items.add(
        PrescriptionItem(
          id: generateId(),
          medicationName: notes.length > 50 ? notes.substring(0, 50) : notes,
          strength: 'As prescribed',
          form: 'medication',
          quantity: 14,
          unit: 'tablets',
          frequency: 'As directed',
          durationDays: 7,
          instructions: notes,
        ),
      );
    }
  }

  Future<void> _submit(Consultation consultation) async {
    setState(() => _submitting = true);
    try {
      final client = ref.read(supabaseClientProvider);

      // 1. Create prescription in Supabase / repository directly as dispensed
      await ref
          .read(prescriptionsRepositoryProvider)
          .create(
            Prescription(
              id: '',
              patientId: consultation.patientId,
              doctorId: consultation.doctorId,
              issuedDate: DateTime.now(),
              expiryDate: DateTime.now().add(const Duration(days: 30)),
              status: PrescriptionStatus.dispensed,
              items: _items,
              source: PrescriptionSource.inApp,
              consultationId: widget.consultationId,
            ),
          );

      // 2. Clear appointment in database (marks visit as completed)
      if (!Env.isMockMode) {
        if (consultation.appointmentId.isNotEmpty) {
          try {
            await client
                .from('appointments')
                .update({'status': 'completed'})
                .eq('id', consultation.appointmentId);
          } catch (_) {}
        }
        try {
          await client
              .from('consultations')
              .update({'status': 'completed'})
              .eq('id', widget.consultationId);
        } catch (_) {}
      } else {
        final db = ref.read(mockDatabaseProvider);
        final apptIdx = db.appointments.indexWhere((a) => a.id == consultation.appointmentId);
        if (apptIdx != -1) {
          db.appointments[apptIdx] = db.appointments[apptIdx].copyWith(status: AppointmentStatus.completed);
        }
      }

      // 3. Add to dispensed set so it vanishes from the assistant queue IMMEDIATELY
      ref.read(dispensedConsultationsProvider.notifier).update((s) => {...s, widget.consultationId});
          
      ref.read(prescriptionsRevisionProvider.notifier).state++;
      ref.read(appointmentsRevisionProvider.notifier).state++;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prescription verified and dispensed! Patient cleared from queue.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to dispense prescription: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    
    // Check both live Supabase realtime stream and async consultation provider
    final liveConsultation = ref
        .watch(realtimeConsultationsStreamProvider)
        .valueOrNull
        ?.where((c) => c.id == widget.consultationId)
        .firstOrNull;
    final consultationAsync = ref.watch(consultationProvider(widget.consultationId));
    final consultation = liveConsultation ?? consultationAsync.valueOrNull;
    
    if (consultation == null) {
      if (consultationAsync.isLoading) {
        return const Scaffold(
          appBar: LargeTitleAppBar(title: 'Process Prescription'),
          body: Center(child: CircularProgressIndicator()),
        );
      }
      return Scaffold(
        appBar: const LargeTitleAppBar(title: 'Process Prescription'),
        body: Center(
          child: Text(
            consultationAsync.hasError
                ? 'Error: ${consultationAsync.error}'
                : 'Consultation not found',
          ),
        ),
      );
    }
    
    if (!_initializedFromNotes &&
        consultation.notes != null &&
        consultation.notes!.trim().isNotEmpty) {
      _initializedFromNotes = true;
      _populateFromDoctorNotes(consultation.notes!);
    }
    
    final patient = ref
        .watch(userProfileProvider(consultation.patientId))
        .valueOrNull;
    final doctor = ref
        .watch(userProfileProvider(consultation.doctorId))
        .valueOrNull;
    final profileAsync = ref.watch(
      patientProfileProvider(consultation.patientId),
    );

    final allChecked = _checked.length == kVerificationSteps.length;
    final canSubmit = _items.isNotEmpty && allChecked;

    return Scaffold(
      appBar: const LargeTitleAppBar(title: 'Process Prescription'),
      body: AsyncSection(
        value: profileAsync,
        data: (profile) {
          final allMedNames = <String>{
            ...?profile?.currentMedications.map((m) => m.split(' ').first),
            ..._items.map((i) => i.medicationName),
          }.toList();
          
          final interactions = ref
              .watch(prescriptionsRepositoryProvider)
              .checkInteractions(allMedNames);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AvatarWidget(
                            name: patient?.fullName ?? 'Patient',
                            color: colors.clinicianAccent,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  patient?.fullName ?? 'Patient',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                if ((consultation.diagnosis ?? '').isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Text(
                                      'Diagnosis: ${consultation.diagnosis}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(height: 1, color: colors.border),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.medical_services_outlined, size: 16, color: colors.clinicianAccent),
                          const SizedBox(width: 6),
                          Text(
                            'Consulting Doctor: Dr. ${doctor?.fullName ?? 'Attending Doctor'}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.clinicianAccent.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.assignment_outlined, size: 16, color: colors.clinicianAccent),
                          const SizedBox(width: 6),
                          Text(
                            'DOCTOR CONSULTATION NOTES (CROSS-CHECK)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: colors.clinicianAccent,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.clinicianAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Auto-transferred to Rx',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colors.clinicianAccent),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        (consultation.notes != null && consultation.notes!.trim().isNotEmpty)
                            ? consultation.notes!
                            : 'No doctor notes recorded for this consultation.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color: (consultation.notes != null && consultation.notes!.trim().isNotEmpty)
                              ? colors.textPrimary
                              : colors.textTertiary,
                        ),
                      ),
                      if (consultation.recommendations != null && consultation.recommendations!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Recommendations: ${consultation.recommendations}',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AllergyBanner(allergies: profile?.allergies ?? const []),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      'Medications to Dispense',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.clinicianAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_items.length} item${_items.length == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.clinicianAccent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_items.isNotEmpty) ...[
                  for (final item in _items)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: colors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.medication_outlined, size: 20, color: colors.clinicianAccent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '${item.medicationName} ${item.strength}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'From Doctor Notes',
                                        style: TextStyle(fontSize: 9.5, color: Colors.green, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${item.frequency} · ${item.durationDays} days · ${item.instructions}',
                                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 20),
                            color: colors.danger,
                            onPressed: () => setState(() => _items.remove(item)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
                Text(
                  'Add Additional Medication',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textSecondary),
                ),
                const SizedBox(height: 6),
                PrescriptionItemForm(
                  onAdd: (item) => setState(() => _items.add(item)),
                ),
                DrugInteractionAlert(interactions: interactions),
                
                const SizedBox(height: 32),
                Text('Verification Checklist', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                VerificationChecklist(
                  checked: _checked,
                  onChanged: (i) => setState(() => _checked.contains(i) ? _checked.remove(i) : _checked.add(i)),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: StickySubmitBar(
        label: 'Verify & Dispense',
        enabled: canSubmit,
        onSubmit: () => _submit(consultation),
        loading: _submitting,
      ),
    );
  }
}
