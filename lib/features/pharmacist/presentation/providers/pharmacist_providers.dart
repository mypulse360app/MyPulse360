import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/env/env.dart';
import '../../../../shared/data/supabase_providers.dart';
import '../../../../shared/mock/mock_database.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/presentation/providers/appointments_providers.dart';
import '../../../doctor/domain/entities/consultation.dart';
import '../../../prescriptions/domain/entities/prescription.dart';

import '../../../prescriptions/presentation/providers/prescriptions_providers.dart';
import '../../data/datasources/mock_pharmacist_datasource.dart';
import '../../data/datasources/supabase_pharmacist_datasource.dart';
import '../../data/repositories/pharmacist_repository_impl.dart';
import '../../domain/entities/pharmacist_profile.dart';
import '../../domain/repositories/pharmacist_repository.dart';

final mockPharmacistDataSourceProvider = Provider((ref) {
  return MockPharmacistDataSource(ref.watch(mockDatabaseProvider));
});

final supabasePharmacistDataSourceProvider = Provider((ref) {
  return SupabasePharmacistDataSource(ref.watch(supabaseClientProvider));
});

final pharmacistRepositoryProvider = Provider<PharmacistRepository>((ref) {
  if (Env.isMockMode) {
    return PharmacistRepositoryImpl(ref.watch(mockPharmacistDataSourceProvider));
  } else {
    return PharmacistRepositoryImpl(ref.watch(supabasePharmacistDataSourceProvider));
  }
});

final pharmacistProfileProvider = Provider.family<PharmacistProfile?, String>((
  ref,
  pharmacistId,
) {
  return ref.watch(pharmacistRepositoryProvider).getProfile(pharmacistId);
});

final pharmacistTodaysAppointmentsProvider = Provider<List<Appointment>>((ref) {
  ref.watch(appointmentsRevisionProvider);
  return ref.watch(pharmacistRepositoryProvider).getTodaysAppointments();
});

/// Supabase Realtime stream of today's appointments
final realtimeAppointmentsStreamProvider = StreamProvider.autoDispose<List<Appointment>>((ref) {
  if (Env.isMockMode) {
    ref.watch(appointmentsRevisionProvider);
    return Stream.value(ref.watch(pharmacistRepositoryProvider).getTodaysAppointments());
  }
  return ref.watch(supabasePharmacistDataSourceProvider).watchTodaysAppointments();
});

final _consultsStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  if (Env.isMockMode) return Stream.value([]);
  return ref.watch(supabaseClientProvider).from('consultations').stream(primaryKey: ['id']);
});

final _tempsStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  if (Env.isMockMode) return Stream.value([]);
  return ref.watch(supabaseClientProvider).from('temperature_logs').stream(primaryKey: ['id']);
});

/// Supabase Realtime stream of consultations
final realtimeConsultationsStreamProvider = Provider.autoDispose<AsyncValue<List<Consultation>>>((ref) {
  if (Env.isMockMode) {
    ref.watch(appointmentsRevisionProvider);
    final db = ref.watch(mockDatabaseProvider);
    return AsyncData(db.consultations);
  }
  
  final consultsAsync = ref.watch(_consultsStreamProvider);
  final tempsAsync = ref.watch(_tempsStreamProvider);
  
  if (consultsAsync.isLoading) return const AsyncLoading();
  if (consultsAsync.hasError) return AsyncError(consultsAsync.error!, consultsAsync.stackTrace!);
  
  final consults = consultsAsync.valueOrNull ?? [];
  final temps = List<Map<String, dynamic>>.from(tempsAsync.valueOrNull ?? []);
  
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
      status: (r['status'] as String) == 'in_progress' ? ConsultationStatus.inProgress : ConsultationStatus.completed,
      notes: r['notes'] as String?,
      diagnosis: r['diagnosis'] as String?,
      recommendations: r['recommendations'] as String?,
      vitals: ConsultationVitals(temperatureCelsius: temperature),
    );
  }).toList();
  
  return AsyncData(list);
});

/// Supabase Realtime stream of active prescriptions
final realtimePrescriptionsStreamProvider = StreamProvider.autoDispose<List<Prescription>>((ref) {
  if (Env.isMockMode) {
    ref.watch(prescriptionsRevisionProvider);
    final db = ref.watch(mockDatabaseProvider);
    return Stream.value(db.prescriptions.where((p) => p.status == PrescriptionStatus.active).toList());
  }
  return ref.watch(supabasePharmacistDataSourceProvider).watchPrescriptions();
});

/// Stream of the latest **unassigned** IoT temperature scan (patient_id IS NULL).
/// Only unclaimed scans are surfaced so the clinic assistant can explicitly
/// link one to a specific patient � preventing cross-patient contamination.
final latestTemperatureLogProvider = StreamProvider.autoDispose<Map<String, dynamic>?>((ref) {
  if (Env.isMockMode) {
    // Simulated stream for mock mode
    return (() async* {
      yield null;
      final temps = [36.6, 36.8, 37.0, 36.5, 36.7];
      var idx = 0;
      while (true) {
        await Future.delayed(const Duration(seconds: 6));
        yield {
          'temperature': temps[idx % temps.length],
          'device': 'ESP8266',
          'status': 'normal',
          'created_at': DateTime.now(),
        };
        idx++;
      }
    })();
  }
  return ref.watch(supabasePharmacistDataSourceProvider).watchUnassignedTemperatureScans();
});

final realtimeQueueStreamProvider = StreamProvider.autoDispose<int>((ref) async* {
  var count = 0;
  while (true) {
    await Future.delayed(const Duration(seconds: 3));
    yield ++count;
  }
});

final consultationProvider = FutureProvider.family<Consultation?, String>((ref, consultationId) async {
  ref.watch(appointmentsRevisionProvider);
  if (Env.isMockMode) {
    final db = ref.watch(mockDatabaseProvider);
    return db.consultations.where((c) => c.id == consultationId).firstOrNull;
  }
  final client = ref.watch(supabaseClientProvider);
  final res = await client.from('consultations').select().eq('id', consultationId).maybeSingle();
  if (res == null) return null;

  final appointmentId = res['appointment_id'] as String;
  final tempRes = await client
      .from('temperature_logs')
      .select('temperature')
      .eq('appointment_id', appointmentId)
      .order('created_at', ascending: false)
      .limit(1)
      .maybeSingle();
  final temp = (tempRes?['temperature'] as num?)?.toDouble();

  return Consultation(
    id: res['id'] as String,
    appointmentId: appointmentId,
    patientId: res['patient_id'] as String,
    doctorId: res['doctor_id'] as String,
    status: (res['status'] as String) == 'in_progress' ? ConsultationStatus.inProgress : ConsultationStatus.completed,
    vitals: ConsultationVitals(temperatureCelsius: temp),
    notes: res['notes'] as String?,
    diagnosis: res['diagnosis'] as String?,
    recommendations: res['recommendations'] as String?,
  );
});

final consultationForAppointmentProvider = FutureProvider.family<Consultation?, String>((ref, appointmentId) async {
  ref.watch(appointmentsRevisionProvider);
  if (Env.isMockMode) {
    final db = ref.watch(mockDatabaseProvider);
    return db.consultations.where((c) => c.appointmentId == appointmentId).firstOrNull;
  }
  final client = ref.watch(supabaseClientProvider);
  final res = await client.from('consultations').select().eq('appointment_id', appointmentId).maybeSingle();
  if (res == null) return null;

  final tempRes = await client
      .from('temperature_logs')
      .select('temperature')
      .eq('appointment_id', appointmentId)
      .order('created_at', ascending: false)
      .limit(1)
      .maybeSingle();
  final temp = (tempRes?['temperature'] as num?)?.toDouble();

  return Consultation(
    id: res['id'] as String,
    appointmentId: res['appointment_id'] as String,
    patientId: res['patient_id'] as String,
    doctorId: res['doctor_id'] as String,
    status: (res['status'] as String) == 'in_progress' ? ConsultationStatus.inProgress : ConsultationStatus.completed,
    vitals: ConsultationVitals(temperatureCelsius: temp),
    notes: res['notes'] as String?,
    diagnosis: res['diagnosis'] as String?,
    recommendations: res['recommendations'] as String?,
  );
});

/// Track consultations that have been verified & dispensed,
/// ensuring they immediately disappear from the queue without waiting for network/socket latency.
final dispensedConsultationsProvider = StateProvider<Set<String>>((ref) => <String>{});

final pharmacyQueueProvider = Provider.family<List<Prescription>, String>((ref, pharmacyId) {
  ref.watch(prescriptionsRevisionProvider);
  return ref.watch(pharmacistRepositoryProvider).getQueue(pharmacyId);
});

final awaitingPrescriptionProvider = Provider<List<Consultation>>((ref) {
  ref.watch(prescriptionsRevisionProvider);
  ref.watch(appointmentsRevisionProvider);
  return ref.watch(pharmacistRepositoryProvider).getAwaitingPrescription();
});
