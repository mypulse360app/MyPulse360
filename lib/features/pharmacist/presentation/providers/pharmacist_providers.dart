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

final supabasePharmacistDataSourceProvider = Provider<SupabasePharmacistDataSource>((ref) {
  return SupabasePharmacistDataSource(ref.watch(supabaseClientProvider));
});

final pharmacistRepositoryProvider = Provider<PharmacistRepository>((ref) {
  final ds = Env.isMockMode
      ? MockPharmacistDataSource(ref.watch(mockDatabaseProvider))
      : ref.watch(supabasePharmacistDataSourceProvider);
  return PharmacistRepositoryImpl(ds);
});

final pharmacistProfileProvider = Provider.family<PharmacistProfile?, String>((ref, pharmacistId) {
  return ref.watch(pharmacistRepositoryProvider).getProfile(pharmacistId);
});

final pharmacyQueueProvider = Provider.family<List<Prescription>, String>((ref, pharmacyId) {
  ref.watch(prescriptionsRevisionProvider);
  return ref.watch(pharmacistRepositoryProvider).getQueue(pharmacyId);
});

final awaitingPrescriptionProvider = Provider<List<Consultation>>((ref) {
  ref.watch(prescriptionsRevisionProvider);
  ref.watch(appointmentsRevisionProvider);
  return ref.watch(pharmacistRepositoryProvider).getAwaitingPrescription();
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

/// Supabase Realtime stream of consultations
final realtimeConsultationsStreamProvider = StreamProvider.autoDispose<List<Consultation>>((ref) {
  if (Env.isMockMode) {
    ref.watch(appointmentsRevisionProvider);
    final db = ref.watch(mockDatabaseProvider);
    return Stream.value(db.consultations);
  }
  return ref.watch(supabasePharmacistDataSourceProvider).watchConsultations();
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

/// Supabase Realtime stream of hardware IoT temperature scans
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
          'device': 'Lobby Scanner 01',
          'status': 'normal',
          'timestamp': DateTime.now(),
        };
        idx++;
      }
    })();
  }
  return ref.watch(supabasePharmacistDataSourceProvider).watchLatestTemperatureLog();
});

final realtimeQueueStreamProvider = StreamProvider.autoDispose<int>((ref) async* {
  var count = 0;
  while (true) {
    await Future.delayed(const Duration(seconds: 3));
    yield ++count;
  }
});

final consultationProvider = FutureProvider.family<Consultation?, String>((ref, consultationId) async {
  if (Env.isMockMode) {
    final db = ref.watch(mockDatabaseProvider);
    return db.consultations.where((c) => c.id == consultationId).firstOrNull;
  }
  final client = ref.watch(supabaseClientProvider);
  final res = await client.from('consultations').select().eq('id', consultationId).maybeSingle();
  if (res == null) return null;
  return Consultation(
    id: res['id'] as String,
    appointmentId: res['appointment_id'] as String,
    patientId: res['patient_id'] as String,
    doctorId: res['doctor_id'] as String,
    status: (res['status'] as String) == 'in_progress' ? ConsultationStatus.inProgress : ConsultationStatus.completed,
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
  return Consultation(
    id: res['id'] as String,
    appointmentId: res['appointment_id'] as String,
    patientId: res['patient_id'] as String,
    doctorId: res['doctor_id'] as String,
    status: (res['status'] as String) == 'in_progress' ? ConsultationStatus.inProgress : ConsultationStatus.completed,
    notes: res['notes'] as String?,
    diagnosis: res['diagnosis'] as String?,
    recommendations: res['recommendations'] as String?,
  );
});

/// Track consultations that have been verified & dispensed,
/// ensuring they immediately disappear from the queue without waiting for network/socket latency.
final dispensedConsultationsProvider = StateProvider<Set<String>>((ref) => <String>{});

