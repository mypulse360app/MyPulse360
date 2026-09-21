import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/appointments/domain/entities/appointment.dart';
import '../../features/auth/domain/entities/app_user.dart';
import '../../features/chatbot/domain/entities/chat_conversation.dart';
import '../../features/doctor/domain/entities/consultation.dart';
import '../../features/doctor/domain/entities/doctor_profile.dart';
import '../../features/health_dashboard/domain/entities/health_metric.dart';
import '../../features/health_dashboard/domain/entities/health_platform_connection.dart';
import '../../features/patient/domain/entities/patient_profile.dart';
import '../../features/patient/domain/entities/wellness_goal.dart';
import '../../features/pharmacist/domain/entities/pharmacist_profile.dart';
import '../../features/prescriptions/domain/entities/prescription.dart';
import '../../features/scheduling/domain/entities/attendance_record.dart';
import '../../features/scheduling/domain/entities/leave_request.dart';
import '../../features/scheduling/domain/entities/staff_notification.dart';
import '../../features/scheduling/domain/entities/staff_unavailability.dart';
import '../domain/entities/clinic.dart';
import 'credentials_store.dart';
import 'fixtures/seed_appointments.dart';
import 'fixtures/seed_chat.dart';
import 'fixtures/seed_credentials.dart';
import 'fixtures/seed_doctors.dart';
import 'fixtures/seed_health_metrics.dart';
import 'fixtures/seed_patients.dart';
import 'fixtures/seed_pharmacists.dart';
import 'fixtures/seed_prescriptions.dart';
import 'fixtures/seed_users.dart';
import 'fixtures/seed_wellness_goals.dart';
import 'mock_ids.dart';

/// Single in-memory "backend" shared by every mock datasource this pass, so
/// e.g. booking an appointment is immediately visible in the doctor's
/// queue, and dispensing a prescription immediately flips its status for
/// the patient. Session lifetime only — resets on relaunch.
class MockDatabase {
  MockDatabase()
      : clinics = [
          const Clinic(
            id: MockIds.defaultClinicId,
            name: 'MyPulse360 Clinic',
            address: '12 Wellness Ave',
            phone: '+1 555-0100',
          ),
          const Clinic(
            id: MockIds.secondClinicId,
            name: 'MyPulse360 Downtown',
            address: '48 Market St',
            phone: '+1 555-0177',
          ),
        ],
        users = seedUsers(),
        patients = seedPatients(),
        doctors = seedDoctors(),
        pharmacists = seedPharmacists(),
        appointments = seedAppointments(),
        prescriptions = seedPrescriptions(),
        healthMetrics = seedHealthMetrics(),
        healthPlatformConnections = [],
        wellnessGoals = seedWellnessGoals(),
        leaveRequests = [],
        unavailability = [],
        attendanceRecords = [],
        staffNotifications = [],
        chatConversations = [seedChat()],
        consultations = [
          const Consultation(
            id: 'consultation-james-today',
            appointmentId: 'appt-today-1',
            patientId: MockIds.patient2Id,
            doctorId: MockIds.drAhmedDoctorId,
            status: ConsultationStatus.completed,
            diagnosis: 'Stage 1 Essential Hypertension',
            notes: 'Patient presented for hypertension follow-up. BP slightly elevated at 142/90 mmHg. Prescribing Lisinopril 10mg once daily in the morning for 30 days. Counselled on low-sodium dietary habits, adequate hydration, and continuous BP monitoring.',
            recommendations: 'Follow up in 30 days for routine blood pressure and kidney function re-evaluation.',
            vitals: ConsultationVitals(
              temperatureCelsius: 36.8,
              systolicBp: 142,
              diastolicBp: 90,
              heartRate: 76,
              weightKg: 78.5,
            ),
          ),
          const Consultation(
            id: 'consultation-sarah-morning',
            appointmentId: 'appt-sarah-morning-test',
            patientId: MockIds.sarahPatientId,
            doctorId: MockIds.drAhmedDoctorId,
            status: ConsultationStatus.completed,
            diagnosis: 'Mild seasonal allergies',
            notes: 'Patient reported minor congestion and sneezing. Prescribed antihistamines.',
            recommendations: 'Avoid outdoor allergens, use air purifier.',
            vitals: ConsultationVitals(
              temperatureCelsius: 36.6,
              systolicBp: 110,
              diastolicBp: 70,
              heartRate: 68,
              weightKg: 60.5,
            ),
          ),
        ],
        credentials = CredentialsStore() {
    seedDemoCredentials(credentials, users);
  }

  final List<Clinic> clinics;
  final List<AppUser> users;
  final CredentialsStore credentials;
  final List<PatientProfile> patients;
  final List<DoctorProfile> doctors;
  final List<PharmacistProfile> pharmacists;
  final List<Appointment> appointments;
  final List<Prescription> prescriptions;
  final List<HealthMetric> healthMetrics;
  final List<HealthPlatformConnection> healthPlatformConnections;
  final List<WellnessGoal> wellnessGoals;
  final List<LeaveRequest> leaveRequests;
  final List<StaffUnavailability> unavailability;
  final List<AttendanceRecord> attendanceRecords;
  final List<StaffNotification> staffNotifications;
  final List<ChatConversation> chatConversations;
  final List<Consultation> consultations;

  AppUser? userById(String id) {
    for (final u in users) {
      if (u.id == id) return u;
    }
    return null;
  }

  void replaceAppointment(Appointment updated) {
    final i = appointments.indexWhere((a) => a.id == updated.id);
    if (i != -1) appointments[i] = updated;
  }

  void replacePrescription(Prescription updated) {
    final i = prescriptions.indexWhere((p) => p.id == updated.id);
    if (i != -1) prescriptions[i] = updated;
  }

  void upsertConsultation(Consultation consultation) {
    final i = consultations.indexWhere((c) => c.id == consultation.id);
    if (i == -1) {
      consultations.add(consultation);
    } else {
      consultations[i] = consultation;
    }
  }
}

final mockDatabaseProvider = Provider<MockDatabase>((ref) => MockDatabase());
