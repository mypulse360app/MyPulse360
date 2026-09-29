import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/env/env.dart';
import '../../../../shared/data/supabase_providers.dart';

import '../../../../shared/mock/mock_database.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/presentation/providers/appointments_providers.dart';
import '../../data/datasources/mock_doctor_datasource.dart';
import '../../data/datasources/supabase_doctor_datasource.dart';
import '../../data/repositories/doctor_repository_impl.dart';
import '../../domain/entities/consultation.dart';
import '../../domain/entities/doctor_profile.dart';
import '../../domain/repositories/doctor_repository.dart';

final doctorRepositoryProvider = Provider<DoctorRepository>((ref) {
  return DoctorRepositoryImpl(
    Env.isMockMode ? MockDoctorDataSource(ref.watch(mockDatabaseProvider)) : SupabaseDoctorDataSource(ref.watch(supabaseClientProvider)),
  );
});

final doctorProfileProvider = Provider.family<DoctorProfile?, String>((
  ref,
  doctorId,
) {
  return ref.watch(doctorRepositoryProvider).getProfile(doctorId);
});

final todaysQueueProvider = StreamProvider.family<List<Appointment>, String>((
  ref,
  doctorId,
) {
  ref.watch(appointmentsRevisionProvider);
  return ref.watch(appointmentsRepositoryProvider).watchTodaysQueue(doctorId);
});

final _consultsStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, patientId) {
  if (Env.isMockMode) return Stream.value([]);
  final client = ref.watch(supabaseClientProvider);
  return client.from('consultations').stream(primaryKey: ['id']).eq('patient_id', patientId);
});

final _tempsStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, patientId) {
  if (Env.isMockMode) return Stream.value([]);
  final client = ref.watch(supabaseClientProvider);
  return client.from('temperature_logs').stream(primaryKey: ['id']).eq('patient_id', patientId);
});

final patientHistoryProvider = Provider.family<AsyncValue<List<Consultation>>, String>((
  ref,
  patientId,
) {
  ref.watch(appointmentsRevisionProvider);
  
  if (Env.isMockMode) {
    return AsyncData(ref.watch(doctorRepositoryProvider).getPatientHistory(patientId));
  }
  
  final consultsAsync = ref.watch(_consultsStreamProvider(patientId));
  final tempsAsync = ref.watch(_tempsStreamProvider(patientId));
  
  if (consultsAsync.isLoading) return const AsyncLoading();
  if (consultsAsync.hasError) return AsyncError(consultsAsync.error!, consultsAsync.stackTrace!);
  
  final consults = consultsAsync.valueOrNull ?? [];
  final temps = List<Map<String, dynamic>>.from(tempsAsync.valueOrNull ?? []);
  
  // Sort temperatures by newest first
  temps.sort((a, b) {
    final aTime = a['created_at'] as String?;
    final bTime = b['created_at'] as String?;
    if (aTime == null || bTime == null) return 0;
    return bTime.compareTo(aTime);
  });
  
  final list = consults.map((r) {
    final apptId = r['appointment_id'] as String;
    double? temperature;
    
    try {
      final match = temps.firstWhere((t) => t['appointment_id'] == apptId);
      temperature = (match['temperature'] as num?)?.toDouble();
    } catch (_) {}

    return Consultation(
      id: r['id'] as String,
      appointmentId: apptId,
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
  }).toList();
  
  list.sort((a, b) => b.id.compareTo(a.id));
  
  return AsyncData(list);
});
