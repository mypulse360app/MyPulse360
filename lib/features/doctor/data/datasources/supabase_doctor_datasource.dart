import 'package:supabase_flutter/supabase_flutter.dart';



import '../../../appointments/domain/entities/appointment.dart';
import '../../domain/entities/consultation.dart';
import '../../domain/entities/doctor_profile.dart';
import 'doctor_datasource.dart';

class SupabaseDoctorDataSource implements DoctorDataSource {
  SupabaseDoctorDataSource(this._client);

  final SupabaseClient _client;

  @override
  DoctorProfile? getProfile(String doctorId) {
    // Synchronous mock return since profile isn't fully implemented in Supabase yet for this demo
    return DoctorProfile(
      id: doctorId,
      specialization: 'General Practice',
      licenseNumber: 'MD-12345',
      clinicId: 'clinic-001',
    );
  }

  @override
  List<Appointment> getTodaysQueue(String doctorId) => const [];

  @override
  Future<Consultation> submitConsultation(Consultation consultation) async {
    final statusStr = consultation.status == ConsultationStatus.completed ? 'completed' : 'in_progress';
    
    final data = <String, dynamic>{
        'appointment_id': consultation.appointmentId,
        'patient_id': consultation.patientId,
        'doctor_id': consultation.doctorId,
        'status': statusStr,
        'notes': consultation.notes,
      };
      if (consultation.diagnosis != null) data['diagnosis'] = consultation.diagnosis;
      if (consultation.recommendations != null) data['recommendations'] = consultation.recommendations;

    if (consultation.id.isEmpty) {
      final res = await _client.from('consultations').insert(data).select().single();
      return _consultationFromRow(res);
    } else {
      final res = await _client.from('consultations').update(data).eq('id', consultation.id).select().single();
      return _consultationFromRow(res);
    }
  }

  @override
  List<Consultation> getPatientHistory(String patientId) {
    throw UnimplementedError('Handled asynchronously');
  }

  Future<List<Consultation>> getPatientHistoryAsync(String patientId) async {
    final rows = await _client
        .from('consultations')
        .select()
        .eq('patient_id', patientId)
        .order('created_at', ascending: false);

    return rows.map((r) => _consultationFromRow(r)).toList();
  }
  
  @override
  Future<Consultation> startOrGetConsultation(String appointmentId, String patientId, String doctorId) async {
    final res = await _client
        .from('consultations')
        .select()
        .eq('appointment_id', appointmentId)
        .limit(1)
        .maybeSingle();

    if (res != null) {
      return _consultationFromRow(res);
    }

    final inserted = await _client.from('consultations').insert({
      'appointment_id': appointmentId,
      'patient_id': patientId,
      'doctor_id': doctorId,
      'status': 'in_progress',
    }).select().single();
    
    return _consultationFromRow(inserted);
  }

  Consultation _consultationFromRow(Map<String, dynamic> r) {
    double? temperature;
    if (r['temperature_logs'] != null) {
      final logs = r['temperature_logs'] as List;
      if (logs.isNotEmpty) {
        temperature = (logs.first['temperature'] as num?)?.toDouble();
      }
    }
    
    return Consultation(
      id: r['id'] as String,
      appointmentId: r['appointment_id'] as String,
      patientId: r['patient_id'] as String,
      doctorId: r['doctor_id'] as String,
      status: (r['status'] as String) == 'in_progress'
          ? ConsultationStatus.inProgress
          : ConsultationStatus.completed,
      diagnosis: r['diagnosis'] as String?,
      recommendations: r['recommendations'] as String?,
      notes: r['notes'] as String?,
      vitals: ConsultationVitals(
        temperatureCelsius: temperature,
        systolicBp: null,
        diastolicBp: null,
      ),
    );
  }
}
