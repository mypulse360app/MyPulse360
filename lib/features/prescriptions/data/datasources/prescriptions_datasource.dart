import '../../domain/entities/drug_interaction.dart';
import '../../domain/entities/prescription.dart';

abstract class PrescriptionsDataSource {
  List<Prescription> getForPatient(String patientId);

  List<Prescription> getPendingVerification();

  Future<Prescription> create(Prescription prescription);

  Future<Prescription> updateStatus(String prescriptionId, PrescriptionStatus status);

  Future<void> delete(String prescriptionId);

  List<DrugInteraction> checkInteractions(List<String> medicationNames);
}
