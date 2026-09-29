import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/mock/mock_database.dart';
import '../../../../shared/mock/mock_ids.dart';
import '../../../../shared/data/supabase_providers.dart';
import '../../../../config/env/env.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../patient/domain/entities/patient_profile.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class AddPatientDialog extends ConsumerStatefulWidget {
  const AddPatientDialog({super.key});

  @override
  ConsumerState<AddPatientDialog> createState() => _AddPatientDialogState();
}

class _AddPatientDialogState extends ConsumerState<AddPatientDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final user = ref.read(currentUserProvider);
      
      final newPatientId = const Uuid().v4();
      final newAppointmentId = const Uuid().v4();
      
      if (!Env.isMockMode) {
        final client = ref.read(supabaseClientProvider);
        
        final doctorRes = await client.from('profiles')
          .select('id')
          .eq('role', 'doctor')
          .limit(1)
          .maybeSingle();
        final realDoctorId = doctorRes?['id'] as String?;

        if (realDoctorId == null) {
          throw Exception('No doctor found in the database to assign this patient to.');
        }

        // 1. Insert into profiles
        await client.from('profiles').insert({
          'id': newPatientId,
          'email': 'walkin_$newPatientId@example.com',
          'full_name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'role': 'patient',
          'clinic_id': user?.clinicId,
          'is_active': true,
          'must_change_password': false,
        });

        // 2. Insert into patient_profiles
        await client.from('patient_profiles').insert({
          'id': newPatientId,
          'height_cm': 170,
          'weight_kg': 70,
          'assigned_doctor_id': realDoctorId,
        });

        // 3. Insert into appointments
        await client.from('appointments').insert({
          'id': newAppointmentId,
          'patient_id': newPatientId,
          'doctor_id': realDoctorId,
          'clinic_id': user?.clinicId,
          'scheduled_at': DateTime.now().toUtc().toIso8601String(),
          'duration_minutes': 15,
          'appointment_type': 'walk-in',
          'status': 'confirmed',
        });
      } else {
        final db = ref.read(mockDatabaseProvider);
        
        final newUser = AppUser(
          id: newPatientId,
          email: 'walkin_$newPatientId@example.com',
          fullName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          role: UserRole.patient,
          clinicId: user?.clinicId ?? MockIds.defaultClinicId,
        );
        
        final newProfile = PatientProfile(
          id: newPatientId,
          heightCm: 170,
          weightKg: 70,
          allergies: const [],
          chronicConditions: const [],
          currentMedications: const [],
          assignedDoctorId: MockIds.drAhmedDoctorId,
        );
        
        final newAppointment = Appointment(
          id: newAppointmentId,
          patientId: newPatientId,
          doctorId: MockIds.drAhmedDoctorId,
          clinicId: user?.clinicId ?? MockIds.defaultClinicId,
          scheduledAt: DateTime.now(),
          durationMinutes: 15,
          appointmentType: 'walk-in',
          status: AppointmentStatus.confirmed,
        );
        
        db.users.add(newUser);
        db.patients.add(newProfile);
        db.appointments.add(newAppointment);
      }
      
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient added to queue')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding patient: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Patient to Queue'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              enabled: !_isLoading,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Add'),
        ),
      ],
    );
  }
}
