import 'entities/prescription_item.dart';

/// A prescription decoded from an OCR scan of a paper prescription, medicine box,
/// or bottle label.
///
/// Contains best-effort extracted fields (prescriber, dates, medications) which
/// are reviewed and editable by the patient before being saved to their records.
class ScannedPrescriptionPayload {
  const ScannedPrescriptionPayload({
    required this.medications,
    required this.issuedDate,
    required this.expiryDate,
    this.prescriberName,
  });

  final String? prescriberName;
  final DateTime issuedDate;
  final DateTime expiryDate;
  final List<PrescriptionItem> medications;
}
