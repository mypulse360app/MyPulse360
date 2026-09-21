import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/env/env.dart';
import '../../../../shared/mock/mock_database.dart';
import '../../../appointments/presentation/providers/appointments_providers.dart';
import '../../data/datasources/mock_health_metrics_datasource.dart';
import '../../data/repositories/health_metrics_repository_impl.dart';
import '../../domain/entities/health_metric.dart';
import '../../domain/entities/health_platform_connection.dart';
import '../../domain/entities/metric_type.dart';
import '../../domain/entities/vital_summary.dart';
import '../../domain/repositories/health_metrics_repository.dart';

final healthMetricsRepositoryProvider = Provider<HealthMetricsRepository>((ref) {
  return HealthMetricsRepositoryImpl(MockHealthMetricsDataSource(ref.watch(mockDatabaseProvider)));
});

/// Bumped after logging a new reading so dependent providers refresh.
final healthMetricsRevisionProvider = StateProvider<int>((ref) => 0);

final dashboardSummariesProvider = Provider.family<List<VitalSummary>, String>((ref, patientId) {
  ref.watch(healthMetricsRevisionProvider);
  return ref.watch(healthMetricsRepositoryProvider).getDashboardSummaries(patientId);
});

final metricHistoryProvider =
    Provider.family<List<HealthMetric>, (String patientId, MetricType type)>((ref, args) {
  ref.watch(healthMetricsRevisionProvider);
  return ref.watch(healthMetricsRepositoryProvider).getHistory(args.$1, args.$2);
});

final healthPlatformConnectionProvider = Provider.family<HealthPlatformConnection?, String>((ref, patientId) {
  ref.watch(healthMetricsRevisionProvider);
  return ref.watch(healthMetricsRepositoryProvider).getConnection(patientId);
});

/// Fetches the latest temperature reading for this patient.
/// Works across both mock fixtures and live Supabase temperature_logs.
final patientLatestTemperatureProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, patientId) async {
  ref.watch(healthMetricsRevisionProvider);
  ref.watch(appointmentsRevisionProvider);

  if (Env.isMockMode) {
    final db = ref.watch(mockDatabaseProvider);
    final consultation = db.consultations
        .where((c) => c.patientId == patientId && c.vitals.temperatureCelsius != null)
        .firstOrNull;
    if (consultation != null) {
      return {
        'temperature': consultation.vitals.temperatureCelsius,
        'status': (consultation.vitals.temperatureCelsius ?? 36.5) > 37.5 ? 'fever' : 'normal',
        'device': 'Lobby Scanner',
        'created_at': DateTime.now().toIso8601String(),
      };
    }
    return null;
  }

  try {
    final client = Supabase.instance.client;
    // 1. First check directly by patient_id
    final row = await client
        .from('temperature_logs')
        .select()
        .eq('patient_id', patientId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row != null) return row;

    // 2. Also check if recent appointments have a linked temperature reading
    final appts = await client
        .from('appointments')
        .select('id')
        .eq('patient_id', patientId)
        .order('scheduled_at', ascending: false)
        .limit(5);

    for (final appt in appts as List) {
      final apptId = appt['id'] as String;
      final temp = await client
          .from('temperature_logs')
          .select()
          .eq('appointment_id', apptId)
          .maybeSingle();
      if (temp != null) return temp;
    }
  } catch (_) {}

  return null;
});
