import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/utils/id_generator.dart';
import '../../domain/entities/drug_interaction.dart';
import '../../domain/entities/prescription.dart';
import '../../domain/entities/prescription_item.dart';
import 'prescriptions_datasource.dart';

const _knownInteractions = [
  DrugInteraction(
    medicationA: 'warfarin',
    medicationB: 'aspirin',
    severity: InteractionSeverity.severe,
    description: 'Combined use significantly increases bleeding risk.',
  ),
  DrugInteraction(
    medicationA: 'lisinopril',
    medicationB: 'ibuprofen',
    severity: InteractionSeverity.moderate,
    description: 'NSAIDs may reduce the blood-pressure-lowering effect and stress the kidneys.',
  ),
  DrugInteraction(
    medicationA: 'metformin',
    medicationB: 'contrast dye',
    severity: InteractionSeverity.severe,
    description: 'Risk of lactic acidosis; hold metformin around contrast imaging.',
  ),
  DrugInteraction(
    medicationA: 'atorvastatin',
    medicationB: 'clarithromycin',
    severity: InteractionSeverity.moderate,
    description: 'Increases statin levels, raising risk of muscle toxicity.',
  ),
];

class SupabasePrescriptionsDataSource implements PrescriptionsDataSource {
  SupabasePrescriptionsDataSource(this._client);

  final SupabaseClient _client;
  final Map<String, List<Prescription>> _cachedPrescriptions = {};
  final Set<String> _fetchedPatients = {};

  Future<void> _fetchForPatient(String patientId) async {
    if (_fetchedPatients.contains(patientId)) return;
    _fetchedPatients.add(patientId);

    try {
      final rows = await _client
          .from('prescriptions')
          .select('*, prescription_items(*)')
          .eq('patient_id', patientId)
          .order('issued_date', ascending: false)
          .timeout(const Duration(seconds: 4));

      final list = <Prescription>[];
      for (final r in rows) {
        list.add(_prescriptionFromRow(r));
      }

      // Merge with any freshly created ones in memory
      final existing = _cachedPrescriptions[patientId] ?? [];
      final existingIds = existing.map((p) => p.id).toSet();
      for (final p in list) {
        if (!existingIds.contains(p.id)) {
          existing.add(p);
        }
      }
      existing.sort((a, b) => b.issuedDate.compareTo(a.issuedDate));
      _cachedPrescriptions[patientId] = existing;
    } catch (_) {
      // Offline or network error: cache continues to serve existing items
    }
  }

  @override
  List<Prescription> getForPatient(String patientId) {
    if (!_cachedPrescriptions.containsKey(patientId)) {
      _cachedPrescriptions[patientId] = [];
      _fetchForPatient(patientId);
    }
    return _cachedPrescriptions[patientId] ?? const [];
  }

  @override
  List<Prescription> getPendingVerification() => const [];

  @override
  Future<Prescription> create(Prescription prescription) async {
    final rxId = prescription.id.isEmpty ? generateId() : prescription.id;

    final statusStr = switch (prescription.status) {
      PrescriptionStatus.dispensed => 'dispensed',
      PrescriptionStatus.cancelled => 'cancelled',
      PrescriptionStatus.expired => 'expired',
      PrescriptionStatus.expiring => 'expiring',
      _ => 'active',
    };

    final isScanned = prescription.source == PrescriptionSource.scannedExternal;
    final doctorId = (isScanned || prescription.doctorId.isEmpty || prescription.doctorId == 'external')
        ? null
        : prescription.doctorId;

    final created = Prescription(
      id: rxId,
      patientId: prescription.patientId,
      doctorId: isScanned ? 'external' : prescription.doctorId,
      issuedDate: prescription.issuedDate,
      expiryDate: prescription.expiryDate,
      status: prescription.status,
      items: prescription.items,
      source: prescription.source,
      consultationId: prescription.consultationId,
      externalDoctorName: prescription.externalDoctorName,
    );

    // Update local cache immediately for zero UI latency
    final patientList = _cachedPrescriptions[prescription.patientId] ?? [];
    patientList.removeWhere((p) => p.id == rxId);
    patientList.insert(0, created);
    _cachedPrescriptions[prescription.patientId] = patientList;

    // Persist to Supabase asynchronously with a fast timeout
    try {
      await _client.from('prescriptions').insert({
        'id': rxId,
        'patient_id': prescription.patientId,
        'doctor_id': doctorId,
        'consultation_id': prescription.consultationId,
        'status': statusStr,
        'notes': prescription.items.map((i) => '${i.medicationName} ${i.strength}').join(', '),
        'source': isScanned ? 'scanned_external' : 'in_app',
        'external_doctor_name': prescription.externalDoctorName,
        'issued_date': prescription.issuedDate.toIso8601String(),
        'expiry_date': prescription.expiryDate.toIso8601String(),
      }).timeout(const Duration(seconds: 4));

      if (prescription.items.isNotEmpty) {
        final itemsPayload = prescription.items.map((item) {
          final itemId = item.id.isEmpty ? generateId() : item.id;
          return {
            'id': itemId,
            'prescription_id': rxId,
            'medication_name': item.medicationName,
            'dosage': item.strength,
            'frequency': item.frequency,
            'duration_days': item.durationDays,
            'instructions': item.instructions,
            'packaging_type': item.packagingType,
            'unit_quantity': item.unitQuantity,
            'form': item.form,
            'quantity': item.quantity,
            'unit': item.unit,
            'refills_allowed': item.refillsAllowed,
          };
        }).toList();

        // Batch insert all items at once in a single roundtrip
        await _client.from('prescription_items').insert(itemsPayload).timeout(const Duration(seconds: 4));
      }
    } catch (_) {
      // Local cache already holds the created prescription for this session
    }

    return created;
  }

  @override
  Future<Prescription> updateStatus(
    String prescriptionId,
    PrescriptionStatus status,
  ) async {
    final statusStr = switch (status) {
      PrescriptionStatus.dispensed => 'dispensed',
      PrescriptionStatus.cancelled => 'cancelled',
      PrescriptionStatus.expired => 'expired',
      PrescriptionStatus.expiring => 'expiring',
      _ => 'verified',
    };

    try {
      await _client
          .from('prescriptions')
          .update({'status': statusStr})
          .eq('id', prescriptionId)
          .timeout(const Duration(seconds: 4));
    } catch (_) {}

    return Prescription(
      id: prescriptionId,
      patientId: '',
      doctorId: '',
      issuedDate: DateTime.now(),
      expiryDate: DateTime.now(),
      status: status,
      items: const [],
      source: PrescriptionSource.inApp,
    );
  }

  @override
  List<DrugInteraction> checkInteractions(List<String> medicationNames) {
    if (medicationNames.length < 2) return const [];
    final lower = medicationNames.map((m) => m.toLowerCase()).toSet();
    final matches = <DrugInteraction>[];
    for (final interaction in _knownInteractions) {
      final hasA = lower.any((m) => m.contains(interaction.medicationA));
      final hasB = lower.any((m) => m.contains(interaction.medicationB));
      if (hasA && hasB) {
        matches.add(interaction);
      }
    }
    return matches;
  }

  Prescription _prescriptionFromRow(Map<String, dynamic> r) {
    final statusStr = r['status'] as String? ?? 'active';
    final status = switch (statusStr) {
      'dispensed' => PrescriptionStatus.dispensed,
      'cancelled' => PrescriptionStatus.cancelled,
      'expired' => PrescriptionStatus.expired,
      'expiring' => PrescriptionStatus.expiring,
      _ => PrescriptionStatus.active,
    };

    final sourceStr = r['source'] as String? ?? 'in_app';
    final source = sourceStr == 'scanned_external'
        ? PrescriptionSource.scannedExternal
        : PrescriptionSource.inApp;

    final rawItems = r['prescription_items'] as List? ?? [];
    final items = rawItems.map((itemRow) {
      final ir = itemRow as Map<String, dynamic>;
      return PrescriptionItem(
        id: ir['id'] as String? ?? '',
        medicationName: ir['medication_name'] as String? ?? '',
        strength: (ir['dosage'] as String?) ?? '',
        form: (ir['form'] as String?) ?? 'tablet',
        quantity: (ir['quantity'] as int?) ?? 1,
        unit: (ir['unit'] as String?) ?? 'units',
        frequency: (ir['frequency'] as String?) ?? 'As directed',
        durationDays: (ir['duration_days'] as int?) ?? 30,
        instructions: (ir['instructions'] as String?) ?? '',
        packagingType: (ir['packaging_type'] as String?) ?? 'box',
        unitQuantity: (ir['unit_quantity'] as int?) ?? 1,
        refillsAllowed: (ir['refills_allowed'] as int?) ?? 0,
      );
    }).toList();

    final issuedRaw = r['issued_date'] ?? r['created_at'];
    final expiryRaw = r['expiry_date'];
    final issued = issuedRaw != null ? DateTime.tryParse(issuedRaw as String) ?? DateTime.now() : DateTime.now();
    final expiry = expiryRaw != null
        ? DateTime.tryParse(expiryRaw as String) ?? issued.add(const Duration(days: 30))
        : issued.add(const Duration(days: 30));

    return Prescription(
      id: r['id'] as String? ?? '',
      patientId: r['patient_id'] as String? ?? '',
      doctorId: (r['doctor_id'] as String?) ?? (source == PrescriptionSource.scannedExternal ? 'external' : ''),
      issuedDate: issued,
      expiryDate: expiry,
      status: status,
      items: items,
      source: source,
      consultationId: r['consultation_id'] as String?,
      externalDoctorName: r['external_doctor_name'] as String?,
    );
  }
}
