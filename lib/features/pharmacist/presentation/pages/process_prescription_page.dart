import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/env/env.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/data/supabase_providers.dart';
import '../../../../shared/mock/mock_database.dart';
import '../../../../shared/presentation/widgets/allergy_banner.dart';
import '../../../../shared/presentation/widgets/async_section.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../../shared/utils/id_generator.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/presentation/providers/appointments_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../doctor/domain/entities/consultation.dart';
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

  final _vitalsTempController = TextEditingController();
  bool _isEditingVitals = false;
  bool _savingVitals = false;
  late final DateTime _pageOpenedAt;
  Map<String, dynamic>? _detectedVitalsScan;

  @override
  void initState() {
    super.initState();
    _pageOpenedAt = DateTime.now();
  }

  @override
  void dispose() {
    _vitalsTempController.dispose();
    super.dispose();
  }

  Future<void> _saveVitals(Consultation consultation) async {
    final tempStr = _vitalsTempController.text.trim();
    if (tempStr.isEmpty) return;
    final temp = double.tryParse(tempStr);
    if (temp == null) return;

    setState(() => _savingVitals = true);
    try {
      await ref.read(pharmacistRepositoryProvider).logTemperature(
        consultation.appointmentId,
        consultation.patientId,
        consultation.doctorId,
        temp,
        temperatureLogId: _detectedVitalsScan?['id']?.toString(),
      );
      ref.read(appointmentsRevisionProvider.notifier).state++;
      setState(() {
        _isEditingVitals = false;
        _savingVitals = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vitals saved: ${temp.toStringAsFixed(1)} °C'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingVitals = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save vitals: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Patient & Doctor Overview Header Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AvatarWidget(
                            name: patient?.fullName ?? 'Patient',
                            color: colors.clinicianAccent,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        patient?.fullName ?? 'Patient',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (patient?.displayId != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: colors.clinicianAccent.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          patient!.displayId!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: colors.clinicianAccent,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (profile?.gender != null) ...[
                                      Text(
                                        profile!.gender!,
                                        style: TextStyle(fontSize: 12, color: colors.textSecondary),
                                      ),
                                      Text(' · ', style: TextStyle(color: colors.textTertiary)),
                                    ],
                                    if (profile?.bloodType != null) ...[
                                      Text(
                                        'Blood ${profile!.bloodType}',
                                        style: TextStyle(fontSize: 12, color: colors.textSecondary),
                                      ),
                                      Text(' · ', style: TextStyle(color: colors.textTertiary)),
                                    ],
                                    Text(
                                      'Visit #${consultation.appointmentId.substring(0, consultation.appointmentId.length > 6 ? 6 : consultation.appointmentId.length)}',
                                      style: TextStyle(fontSize: 12, color: colors.textSecondary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if ((consultation.diagnosis ?? '').isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: colors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.healing_outlined, size: 16, color: colors.clinicianAccent),
                              const SizedBox(width: 8),
                              Text(
                                'Diagnosis: ',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textSecondary),
                              ),
                              Expanded(
                                child: Text(
                                  consultation.diagnosis!,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Divider(height: 1, color: colors.border),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.medical_services_outlined, size: 16, color: colors.clinicianAccent),
                          const SizedBox(width: 8),
                          Text(
                            'Consulting Doctor:',
                            style: TextStyle(fontSize: 12, color: colors.textSecondary),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Dr. ${doctor?.fullName ?? 'Attending Doctor'}',
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

                const SizedBox(height: 16),

                // 2. Patient Vitals & Temperature Card
                _buildVitalsCard(
                  context: context,
                  consultation: consultation,
                  patientName: patient?.fullName ?? 'Patient',
                ),

                const SizedBox(height: 16),

                // 3. Doctor Consultation Notes (Clinical Transcript)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colors.clinicianAccent.withValues(alpha: 0.35), width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: colors.clinicianAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.assignment_outlined, size: 16, color: colors.clinicianAccent),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'DOCTOR\'S PRESCRIPTION NOTES',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: colors.clinicianAccent,
                                  ),
                                ),
                                Text(
                                  'Cross-check instructions before dispensing',
                                  style: TextStyle(fontSize: 11, color: colors.textTertiary),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.sync_rounded, size: 12, color: Color(0xFF10B981)),
                                SizedBox(width: 4),
                                Text(
                                  'Auto-synced',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.border),
                        ),
                        child: Text(
                          (consultation.notes != null && consultation.notes!.trim().isNotEmpty)
                              ? consultation.notes!
                              : 'No doctor notes recorded for this consultation.',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                            color: (consultation.notes != null && consultation.notes!.trim().isNotEmpty)
                                ? colors.textPrimary
                                : colors.textTertiary,
                          ),
                        ),
                      ),
                      if (consultation.recommendations != null && consultation.recommendations!.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.tips_and_updates_outlined, size: 15, color: colors.clinicianAccent),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Advice: ${consultation.recommendations}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 4. Allergy Safety Banner
                AllergyBanner(allergies: profile?.allergies ?? const []),

                const SizedBox(height: 20),

                // 5. Medications to Dispense
                Row(
                  children: [
                    Text(
                      'Medications to Dispense',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.clinicianAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_items.length} ${_items.length == 1 ? 'item' : 'items'}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.clinicianAccent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_items.isEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.medication_outlined, size: 32, color: colors.textTertiary),
                          const SizedBox(height: 8),
                          Text(
                            'No medications in this prescription yet.',
                            style: TextStyle(fontSize: 13, color: colors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap "Add Additional Medication" below to add an item.',
                            style: TextStyle(fontSize: 11, color: colors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  for (final item in _items)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: colors.clinicianAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.medication_rounded, color: colors.clinicianAccent, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.medicationName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: colors.surfaceSubtle,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: colors.border),
                                      ),
                                      child: Text(
                                        item.strength,
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    _pillBadge(Icons.repeat_rounded, item.frequency, colors),
                                    _pillBadge(Icons.calendar_today_outlined, '${item.durationDays} days', colors),
                                    if (item.packagingType.isNotEmpty)
                                      _pillBadge(Icons.inventory_2_outlined, '${item.unitQuantity}x ${item.packagingType}', colors),
                                  ],
                                ),
                                if (item.instructions.isNotEmpty && item.instructions != 'As directed') ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    item.instructions,
                                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18),
                            color: colors.danger,
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(() => _items.remove(item)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                ],

                PrescriptionItemForm(
                  onAdd: (item) => setState(() => _items.add(item)),
                ),

                DrugInteractionAlert(interactions: interactions),

                const SizedBox(height: 28),

                // 6. Verification Checklist
                Text('Verification Checklist', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 10),
                VerificationChecklist(
                  checked: _checked,
                  onChanged: (i) => setState(() => _checked.contains(i) ? _checked.remove(i) : _checked.add(i)),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            border: Border(top: BorderSide(color: colors.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!canSubmit) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: colors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      _items.isEmpty
                          ? 'Add at least 1 medication to dispense'
                          : 'Complete ${kVerificationSteps.length - _checked.length} remaining safety check(s)',
                      style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: canSubmit && !_submitting ? () => _submit(consultation) : null,
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.verified_rounded, size: 18),
                  label: Text(
                    _submitting
                        ? 'Processing Dispense...'
                        : 'Verify & Dispense (${_items.length} ${_items.length == 1 ? 'Item' : 'Items'})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.clinicianAccent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: colors.surfaceSubtle,
                    disabledForegroundColor: colors.textTertiary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pillBadge(IconData icon, String text, AppSemanticColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: colors.textSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
  Widget _buildVitalsCard({
    required BuildContext context,
    required Consultation consultation,
    required String patientName,
  }) {
    final colors = context.colors;
    final recordedTemp = consultation.vitals.temperatureCelsius;
    final showEditor = _isEditingVitals || recordedTemp == null;

    // Listen to latest unassigned scan (scoped strictly to unclaimed IoT scans)
    final tempScan = ref.watch(latestTemperatureLogProvider).valueOrNull;
    if (showEditor && tempScan != null) {
      final scanTime = tempScan['created_at'] as DateTime?;
      final cutoff = _pageOpenedAt.subtract(const Duration(minutes: 2));
      if (scanTime != null && scanTime.isAfter(cutoff)) {
        if (_detectedVitalsScan == null || _detectedVitalsScan!['created_at'] != scanTime) {
          _detectedVitalsScan = tempScan;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _vitalsTempController.text.isEmpty) {
              _vitalsTempController.text = tempScan['temperature'].toString();
            }
          });
        }
      }
    }

    final isFever = recordedTemp != null && recordedTemp > 37.5;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: recordedTemp != null
              ? (isFever ? colors.danger.withValues(alpha: 0.5) : colors.border)
              : Colors.amber.withValues(alpha: 0.4),
          width: isFever ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: recordedTemp != null
                      ? (isFever ? colors.danger.withValues(alpha: 0.15) : colors.clinicianAccent.withValues(alpha: 0.15))
                      : Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.thermostat_rounded,
                  size: 20,
                  color: recordedTemp != null
                      ? (isFever ? colors.danger : colors.clinicianAccent)
                      : Colors.amber,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PATIENT VITALS & TEMPERATURE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: colors.clinicianAccent,
                      ),
                    ),
                    Text(
                      'Measured upon clinic check-in',
                      style: TextStyle(fontSize: 11, color: colors.textTertiary),
                    ),
                  ],
                ),
              ),
              if (recordedTemp != null && !showEditor)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isFever ? colors.danger : const Color(0xFF10B981)).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isFever ? 'Fever (>37.5°C)' : 'Normal',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isFever ? colors.danger : const Color(0xFF10B981),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'Pending Vitals',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (!showEditor) ...[
            Row(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        recordedTemp.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: isFever ? colors.danger : colors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '°C',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Recorded for $patientName',
                          style: TextStyle(fontSize: 12, color: colors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    _vitalsTempController.text = recordedTemp.toStringAsFixed(1);
                    setState(() => _isEditingVitals = true);
                  },
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit / Re-scan'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: colors.clinicianAccent,
                    side: BorderSide(color: colors.clinicianAccent.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ] else ...[
            if (_detectedVitalsScan != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sensors, color: Color(0xFF10B981), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Scanner detected: ${_detectedVitalsScan!['temperature']} °C from ${_detectedVitalsScan!['device']}',
                        style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _vitalsTempController.text = _detectedVitalsScan!['temperature'].toString();
                      },
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: const Color(0xFF10B981),
                      ),
                      child: const Text('Use Scan', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.sensors, color: Colors.amber, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ready for IoT lobby scanner or enter manually below',
                        style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w500, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _vitalsTempController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      labelText: 'Body Temp (°C)',
                      hintText: 'e.g. 36.8',
                      isDense: true,
                      prefixIcon: const Icon(Icons.thermostat_outlined, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (recordedTemp != null) ...[
                  TextButton(
                    onPressed: () => setState(() => _isEditingVitals = false),
                    child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
                  ),
                  const SizedBox(width: 6),
                ],
                FilledButton.icon(
                  onPressed: _savingVitals ? null : () => _saveVitals(consultation),
                  icon: _savingVitals
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check, size: 16),
                  label: Text(_savingVitals ? 'Saving...' : 'Save Vitals'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.clinicianAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
