import 'package:flutter_test/flutter_test.dart';
import 'package:mypulse360/features/prescriptions/domain/scanned_prescription_ocr.dart';

void main() {
  group('Date extraction', () {
    test('extracts an EXP keyword date in MM/YY form as end-of-month', () {
      final payload = buildPayloadFromOcrText('''
      Amoxicillin 500mg
      Batch AB1234
      EXP 08/28
      ''');

      expect(payload.expiryDate, DateTime(2028, 8, 31));
    });

    test('extracts an EXP keyword date on the following line', () {
      final payload = buildPayloadFromOcrText('''
      Paracetamol 500mg
      EXP
      12/2027
      ''');

      expect(payload.expiryDate, DateTime(2027, 12, 31));
    });

    test('extracts a month-name expiry date', () {
      final payload = buildPayloadFromOcrText('''
      Ibuprofen 200mg
      BEST BEFORE AUG 2028
      ''');

      expect(payload.expiryDate, DateTime(2028, 8, 31));
    });

    test('extracts an ISO-formatted expiry date', () {
      final payload = buildPayloadFromOcrText('''
      Metformin 500mg
      Expiry: 2028-08-31
      ''');

      expect(payload.expiryDate, DateTime(2028, 8, 31));
    });

    test('extracts both issued date and expiry date when present', () {
      final payload = buildPayloadFromOcrText('''
      Dr. Sarah Jenkins
      DATE: 2026-08-10
      EXPIRY: 2026-11-10
      Amoxicillin 500mg
      ''');

      expect(payload.issuedDate, DateTime(2026, 8, 10));
      expect(payload.expiryDate, DateTime(2026, 11, 10));
      expect(payload.prescriberName, 'Dr. Sarah Jenkins');
    });

    test('falls back to now + 30 days when no date-shaped text is found', () {
      final before = DateTime.now().add(const Duration(days: 30));
      final payload = buildPayloadFromOcrText('Just some text\nwith no dates at all');
      final after = DateTime.now().add(const Duration(days: 30));

      expect(payload.expiryDate.isAfter(before.subtract(const Duration(minutes: 1))), isTrue);
      expect(payload.expiryDate.isBefore(after.add(const Duration(minutes: 1))), isTrue);
    });
  });

  group('Prescriber extraction', () {
    test('extracts Dr. Name format', () {
      final payload = buildPayloadFromOcrText('''
      City Health Clinic
      Dr. Michael Chang
      Metformin 500mg
      ''');

      expect(payload.prescriberName, 'Dr. Michael Chang');
    });

    test('extracts Prescriber: prefix', () {
      final payload = buildPayloadFromOcrText('''
      Prescriber: Emily Watson MD
      Amoxicillin 500mg
      ''');

      expect(payload.prescriberName, 'Emily Watson MD');
    });
  });

  group('Medication extraction', () {
    test('guesses the medication name from single box packaging', () {
      final payload = buildPayloadFromOcrText('''
      123456789012
      Amoxicillin 500mg Capsules
      Batch AB1234
      EXP 08/28
      ''');

      expect(payload.medications.single.medicationName, 'Amoxicillin 500mg Capsules');
      expect(payload.medications.single.strength, '500mg');
      expect(payload.medications.single.form, 'capsule');
    });

    test('extracts multiple medications from numbered paper prescription', () {
      final payload = buildPayloadFromOcrText('''
      City Medical Center
      Dr. Robert Ross
      Date: 2026-09-01
      1. Amoxicillin 500mg - twice daily with food
      2. Paracetamol 650mg - as needed
      3. Cetirizine 10mg - once daily at bedtime
      ''');

      expect(payload.medications, hasLength(3));

      expect(payload.medications[0].medicationName, 'Amoxicillin');
      expect(payload.medications[0].strength, '500mg');
      expect(payload.medications[0].frequency, '2x daily');
      expect(payload.medications[0].instructions, 'with food');

      expect(payload.medications[1].medicationName, 'Paracetamol');
      expect(payload.medications[1].strength, '650mg');
      expect(payload.medications[1].frequency, 'As needed');

      expect(payload.medications[2].medicationName, 'Cetirizine');
      expect(payload.medications[2].strength, '10mg');
      expect(payload.medications[2].frequency, '1x daily');
    });

    test('skips boilerplate and date-keyword lines when guessing single name', () {
      final payload = buildPayloadFromOcrText('''
      EXP 08/28
      BATCH NO AB1234
      MFG DATE 01/2026
      Metformin 500mg
      ''');

      expect(payload.medications.single.medicationName, 'Metformin 500mg');
    });

    test('returns a blank item when nothing readable was found', () {
      final payload = buildPayloadFromOcrText('123456789012\n9876543210');

      expect(payload.medications, hasLength(1));
      expect(payload.medications.single.medicationName, '');
    });
  });
}
