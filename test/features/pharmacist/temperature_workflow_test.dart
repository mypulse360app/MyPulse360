import 'package:flutter_test/flutter_test.dart';
import 'package:mypulse360/features/doctor/domain/entities/consultation.dart';
import 'package:mypulse360/features/pharmacist/data/datasources/mock_pharmacist_datasource.dart';
import 'package:mypulse360/features/pharmacist/data/repositories/pharmacist_repository_impl.dart';
import 'package:mypulse360/shared/mock/mock_database.dart';

void main() {
  late MockDatabase db;
  late MockPharmacistDataSource datasource;
  late PharmacistRepositoryImpl repository;

  setUp(() {
    db = MockDatabase();
    datasource = MockPharmacistDataSource(db);
    repository = PharmacistRepositoryImpl(datasource);
  });

  group('Patient-Linked Temperature Workflow', () {
    test('Test 1: Multiple Patients - temperatures are linked to specific patient visits', () async {
      // Setup patient visits
      const sarvinAppt = 'appt-sarvin-001';
      const sarvinId = 'patient-sarvin';
      const aliAppt = 'appt-ali-002';
      const aliId = 'patient-ali';
      const kumarAppt = 'appt-kumar-003';
      const kumarId = 'patient-kumar';
      const docId = 'doc-001';

      // Sarvin scans 35.0°C
      await repository.logTemperature(sarvinAppt, sarvinId, docId, 35.0);
      // Ali scans 36.0°C
      await repository.logTemperature(aliAppt, aliId, docId, 36.0);
      // Kumar scans 37.2°C
      await repository.logTemperature(kumarAppt, kumarId, docId, 37.2);

      // Verify each patient has only their own temperature in their consultation
      final sarvinConsultation = db.consultations.firstWhere((c) => c.appointmentId == sarvinAppt);
      final aliConsultation = db.consultations.firstWhere((c) => c.appointmentId == aliAppt);
      final kumarConsultation = db.consultations.firstWhere((c) => c.appointmentId == kumarAppt);

      expect(sarvinConsultation.patientId, equals(sarvinId));
      expect(sarvinConsultation.vitals.temperatureCelsius, equals(35.0));

      expect(aliConsultation.patientId, equals(aliId));
      expect(aliConsultation.vitals.temperatureCelsius, equals(36.0));

      expect(kumarConsultation.patientId, equals(kumarId));
      expect(kumarConsultation.vitals.temperatureCelsius, equals(37.2));
    });

    test('Test 2: Out of Order Scans - order of scanning does not alter patient associations', () async {
      const sarvinAppt = 'appt-sarvin-001';
      const sarvinId = 'patient-sarvin';
      const aliAppt = 'appt-ali-002';
      const aliId = 'patient-ali';
      const kumarAppt = 'appt-kumar-003';
      const kumarId = 'patient-kumar';
      const docId = 'doc-001';

      // Scan in reverse order: Kumar, Sarvin, Ali
      await repository.logTemperature(kumarAppt, kumarId, docId, 37.2);
      await repository.logTemperature(sarvinAppt, sarvinId, docId, 35.0);
      await repository.logTemperature(aliAppt, aliId, docId, 36.0);

      final sarvin = db.consultations.firstWhere((c) => c.appointmentId == sarvinAppt);
      final ali = db.consultations.firstWhere((c) => c.appointmentId == aliAppt);
      final kumar = db.consultations.firstWhere((c) => c.appointmentId == kumarAppt);

      expect(sarvin.vitals.temperatureCelsius, equals(35.0));
      expect(ali.vitals.temperatureCelsius, equals(36.0));
      expect(kumar.vitals.temperatureCelsius, equals(37.2));
    });

    test('Test 3: Repeat Scan - rescan updates only targeted patient without cross-contamination', () async {
      const sarvinAppt = 'appt-sarvin-001';
      const sarvinId = 'patient-sarvin';
      const aliAppt = 'appt-ali-002';
      const aliId = 'patient-ali';
      const kumarAppt = 'appt-kumar-003';
      const kumarId = 'patient-kumar';
      const docId = 'doc-001';

      // Initial scans
      await repository.logTemperature(sarvinAppt, sarvinId, docId, 35.0);
      await repository.logTemperature(aliAppt, aliId, docId, 36.0);
      await repository.logTemperature(kumarAppt, kumarId, docId, 37.2);

      // Ali re-scans at 36.5°C
      await repository.logTemperature(aliAppt, aliId, docId, 36.5);

      final sarvin = db.consultations.firstWhere((c) => c.appointmentId == sarvinAppt);
      final ali = db.consultations.firstWhere((c) => c.appointmentId == aliAppt);
      final kumar = db.consultations.firstWhere((c) => c.appointmentId == kumarAppt);

      // Sarvin and Kumar are UNCHANGED
      expect(sarvin.vitals.temperatureCelsius, equals(35.0));
      expect(kumar.vitals.temperatureCelsius, equals(37.2));
      // Only Ali is updated
      expect(ali.vitals.temperatureCelsius, equals(36.5));
    });

    test('Test 4: Visit Lifecycle - past completed visit temperatures are never overwritten', () async {
      const sarvinAppt = 'appt-sarvin-historical';
      const sarvinId = 'patient-sarvin';
      const aliAppt = 'appt-ali-new';
      const aliId = 'patient-ali';
      const docId = 'doc-001';

      // Sarvin's visit finishes
      await repository.logTemperature(sarvinAppt, sarvinId, docId, 35.0);
      final sarvinConsultation = db.consultations.firstWhere((c) => c.appointmentId == sarvinAppt);
      final completedSarvin = Consultation(
        id: sarvinConsultation.id,
        appointmentId: sarvinConsultation.appointmentId,
        patientId: sarvinConsultation.patientId,
        doctorId: sarvinConsultation.doctorId,
        status: ConsultationStatus.completed,
        vitals: sarvinConsultation.vitals,
      );
      db.upsertConsultation(completedSarvin);

      // Later, Ali has an active visit and scans
      await repository.logTemperature(aliAppt, aliId, docId, 36.8);

      // Verify Sarvin's historical record is strictly preserved
      final historicalSarvin = db.consultations.firstWhere((c) => c.appointmentId == sarvinAppt);
      expect(historicalSarvin.vitals.temperatureCelsius, equals(35.0));
      expect(historicalSarvin.status, equals(ConsultationStatus.completed));

      final activeAli = db.consultations.firstWhere((c) => c.appointmentId == aliAppt);
      expect(activeAli.vitals.temperatureCelsius, equals(36.8));
    });
  });
}
