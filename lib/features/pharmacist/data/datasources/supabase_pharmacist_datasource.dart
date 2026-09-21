import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/data/db_rows.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../doctor/domain/entities/consultation.dart';
import '../../../prescriptions/domain/entities/prescription.dart';
import '../../../prescriptions/domain/entities/prescription_item.dart';
import '../../domain/entities/pharmacist_profile.dart';
import 'pharmacist_datasource.dart';

class SupabasePharmacistDataSource implements PharmacistDataSource {
  SupabasePharmacistDataSource(this._client);

  final SupabaseClient _client;

  @override
  PharmacistProfile? getProfile(String pharmacistId) {
    return PharmacistProfile(
      id: pharmacistId,
      licenseNumber: 'PHA-MY-2026',
      pharmacyName: 'MyPulse360 Central Pharmacy',
      clinicId: 'clinic-001',
    );
  }

  @override
  List<Prescription> getQueue(String pharmacyId) => const [];

  @override
  List<Consultation> getAwaitingPrescription() => const [];

  @override
  List<Appointment> getTodaysAppointments() => const [];

  @override
  Future<String> logTemperature(
    String appointmentId,
    String patientId,
    String doctorId,
    double temperature, {
    String? temperatureLogId,
  }) async {
    // 1. Check if consultation exists for this appointment
    final res = await _client
        .from('consultations')
        .select('id')
        .eq('appointment_id', appointmentId)
        .maybeSingle();

    String consultationId;

    if (res != null) {
      // Update existing consultation with vitals note
      consultationId = res['id'] as String;
      await _client.from('consultations').update({
        'notes': 'Vitals logged: Temp ${temperature.toStringAsFixed(1)} °C',
      }).eq('id', consultationId);
    } else {
      // Create new consultation for this appointment
      final inserted = await _client.from('consultations').insert({
        'appointment_id': appointmentId,
        'patient_id': patientId,
        'doctor_id': doctorId,
        'status': 'in_progress',
        'notes': 'Vitals logged: Temp ${temperature.toStringAsFixed(1)} °C',
      }).select('id').single();
      consultationId = inserted['id'] as String;
    }

    // 2. Link or Create the temperature log
    if (temperatureLogId != null) {
      // Claim the unassigned IoT scan and link it to this patient/appointment.
      // Also update the temperature value in case the assistant edited it.
      // The .is_('patient_id', null) guard prevents double-assignment —
      // if the scan was already linked to another patient, this is a no-op.
      await _client.from('temperature_logs').update({
        'patient_id': patientId,
        'appointment_id': appointmentId,
        'temperature': temperature,
        'status': temperature > 37.5 ? 'fever' : 'normal',
      }).eq('id', temperatureLogId).isFilter('patient_id', null);
    } else {
      await _client.from('temperature_logs').insert({
        'patient_id': patientId,
        'appointment_id': appointmentId,
        'temperature': temperature,
        'device': 'Manual Entry',
        'status': temperature > 37.5 ? 'fever' : 'normal',
      });
    }

    return consultationId;
  }

  @override
  Future<String> getOrCreateConsultation({
    required String appointmentId,
    required String patientId,
    required String doctorId,
  }) async {
    final res = await _client
        .from('consultations')
        .select('id')
        .eq('appointment_id', appointmentId)
        .maybeSingle();

    if (res != null) {
      return res['id'] as String;
    }

    final inserted = await _client.from('consultations').insert({
      'appointment_id': appointmentId,
      'patient_id': patientId,
      'doctor_id': doctorId,
      'status': 'in_progress',
    }).select('id').single();

    return inserted['id'] as String;
  }

  /// Real-time stream of today's appointments for the clinic
  Stream<List<Appointment>> watchTodaysAppointments() {
    return _client
        .from('appointments')
        .stream(primaryKey: ['id'])
        .map((rows) {
          final today = DateTime.now();
          return rows
              .map((r) => appointmentFromRow(Map<String, dynamic>.from(r)))
              .where((a) {
                final at = a.scheduledAt.toLocal();
                return a.status != AppointmentStatus.cancelled &&
                    at.year == today.year &&
                    at.month == today.month &&
                    at.day == today.day;
              })
              .toList()
            ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
        });
  }

  /// Real-time stream of completed consultations awaiting processing
  Stream<List<Consultation>> watchConsultations() {
    return _client
        .from('consultations')
        .stream(primaryKey: ['id'])
        .map((rows) {
          return rows.map((r) {
            return Consultation(
              id: r['id'] as String,
              appointmentId: r['appointment_id'] as String,
              patientId: r['patient_id'] as String,
              doctorId: r['doctor_id'] as String,
              status: (r['status'] as String) == 'in_progress'
                  ? ConsultationStatus.inProgress
                  : ConsultationStatus.completed,
              notes: r['notes'] as String?,
              diagnosis: r['diagnosis'] as String?,
              recommendations: r['recommendations'] as String?,
            );
          }).toList();
        });
  }

  /// Real-time stream of prescriptions waiting for verification / dispensing
  Stream<List<Prescription>> watchPrescriptions() {
    return _client
        .from('prescriptions')
        .stream(primaryKey: ['id'])
        .asyncMap((rows) async {
          final list = <Prescription>[];
          for (final r in rows) {
            final rxId = r['id'] as String;
            final itemsRes = await _client
                .from('prescription_items')
                .select()
                .eq('prescription_id', rxId);

            final items = (itemsRes as List).map((i) {
              return PrescriptionItem(
                id: i['id'] as String,
                medicationName: i['medication_name'] as String,
                strength: i['dosage'] as String? ?? '',
                form: 'medication',
                quantity: i['unit_quantity'] as int? ?? 1,
                unit: i['packaging_type'] as String? ?? 'pack',
                frequency: i['frequency'] as String? ?? 'As directed',
                durationDays: i['duration_days'] as int? ?? 30,
                instructions: i['instructions'] as String? ?? '',
              );
            }).toList();

            final statusStr = r['status'] as String? ?? 'active';
            final status = switch (statusStr) {
              'dispensed' => PrescriptionStatus.dispensed,
              'cancelled' => PrescriptionStatus.cancelled,
              'expired' => PrescriptionStatus.expired,
              'expiring' => PrescriptionStatus.expiring,
              _ => PrescriptionStatus.active,
            };

            list.add(
              Prescription(
                id: rxId,
                patientId: r['patient_id'] as String,
                doctorId: r['doctor_id'] as String,
                consultationId: r['consultation_id'] as String?,
                issuedDate: DateTime.parse(r['created_at'] as String).toLocal(),
                expiryDate: DateTime.parse(r['created_at'] as String)
                    .add(const Duration(days: 30))
                    .toLocal(),
                status: status,
                source: PrescriptionSource.inApp,
                items: items,
              ),
            );
          }
          return list;
        });
  }

  /// Real-time stream of latest **unassigned** hardware temperature scans
  /// from IoT devices (patient_id IS NULL).  Only these scans are eligible
  /// for the clinic assistant to claim and link to a specific patient.
  Stream<Map<String, dynamic>?> watchUnassignedTemperatureScans() async* {
    // Initial fetch
    yield await _fetchLatestUnassignedScan();

    // Poll every 3 seconds for new unassigned scans.
    // We use polling because Supabase .stream() does not support
    // .is_('patient_id', null) filters natively.
    await for (final _ in Stream.periodic(const Duration(seconds: 3))) {
      yield await _fetchLatestUnassignedScan();
    }
  }

  Future<Map<String, dynamic>?> _fetchLatestUnassignedScan() async {
    try {
      final rows = await _client
          .from('temperature_logs')
          .select()
          .isFilter('patient_id', null)
          .order('created_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) return null;
      final r = rows.first;
      return {
        'id': r['id'],
        'temperature': (r['temperature'] as num).toDouble(),
        'device': r['device'] ?? 'Lobby Scanner',
        'status': r['status'] ?? 'normal',
        'created_at': DateTime.parse(r['created_at'] as String).toLocal(),
      };
    } catch (_) {
      return null;
    }
  }
}
