import 'entities/prescription_item.dart';
import 'scanned_prescription_payload.dart';

/// Best-effort extraction from text recognized via OCR off a paper prescription,
/// medication box, or pharmacy bottle label.
///
/// Always editable and reviewed by the patient on the subsequent screen.
/// Never treated as absolute truth, but provides sensible pre-filled fields
/// for single medications or multi-item paper prescriptions.
ScannedPrescriptionPayload buildPayloadFromOcrText(String recognizedText) {
  final lines = recognizedText
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  final now = DateTime.now();
  final prescriber = _guessPrescriber(lines);
  final dates = _extractDates(lines);
  final issuedDate = dates.issuedDate ?? now;
  final expiryDate = dates.expiryDate ?? now.add(const Duration(days: 30));

  final medications = _extractMedications(lines);

  return ScannedPrescriptionPayload(
    prescriberName: prescriber,
    issuedDate: issuedDate,
    expiryDate: expiryDate,
    medications: medications.isNotEmpty
        ? medications
        : [
            const PrescriptionItem(
              id: 'scanned-item-0',
              medicationName: '',
              strength: '',
              form: 'tablet',
              quantity: 1,
              unit: 'units',
              frequency: 'As directed',
              durationDays: 30,
              instructions: '',
            ),
          ],
  );
}

// ---------------------------------------------------------------------------
// Prescriber Extraction
// ---------------------------------------------------------------------------

final _prescriberPrefixes = RegExp(
  r'^(?:(?:Dr\.?|Doctor|MD|Physician|Prescriber)[\s:]+|Prescribed\s+by[\s:]+)',
  caseSensitive: false,
);

String? _guessPrescriber(List<String> lines) {
  for (final line in lines) {
    if (_prescriberPrefixes.hasMatch(line)) {
      final cleaned = line
          .replaceAll(RegExp(r'^(?:Prescriber|Physician|Prescribed\s+by)[\s:]+', caseSensitive: false), '')
          .trim();
      if (cleaned.isNotEmpty && cleaned.length >= 3) {
        return _truncate(cleaned, 60);
      }
    } else if (RegExp(r'\b(?:Dr\.?|Doctor)\s+[A-Z][a-zA-Z]+(?:\s+[A-Z][a-zA-Z]+)*\b').hasMatch(line)) {
      final match = RegExp(r'\b(?:Dr\.?|Doctor)\s+[A-Z][a-zA-Z]+(?:\s+[A-Z][a-zA-Z]+)*\b').firstMatch(line);
      if (match != null) {
        return _truncate(match.group(0)!, 60);
      }
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Date Extraction
// ---------------------------------------------------------------------------

final _expiryKeywords = RegExp(
  r'\b(EXP|EXPIRY|EXPIRES?|BEST\s*BEFORE|BB|USE\s*BY|USE\s*BEFORE)\b',
  caseSensitive: false,
);

final _issuedKeywords = RegExp(
  r'\b(DATE|ISSUED|PRESCRIBED|VISIT\s*DATE|CONSULT\s*DATE|DOS)\b',
  caseSensitive: false,
);

final _isoDatePattern = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})');
final _monthNamePattern = RegExp(
  r'\b(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[A-Z]*\.?\s+(\d{4}|\d{2})\b',
  caseSensitive: false,
);
final _fullDatePattern = RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})');
final _monthYearPattern = RegExp(r'(\d{1,2})[/\-](\d{2,4})(?!\d)');

const _monthAbbrevs = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

class _ExtractedDates {
  const _ExtractedDates({this.issuedDate, this.expiryDate});
  final DateTime? issuedDate;
  final DateTime? expiryDate;
}

_ExtractedDates _extractDates(List<String> lines) {
  DateTime? explicitIssued;
  DateTime? explicitExpiry;
  final allFoundDates = <DateTime>[];

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];

    if (_expiryKeywords.hasMatch(line)) {
      final date = _extractDate(line) ?? (i + 1 < lines.length ? _extractDate(lines[i + 1]) : null);
      if (date != null && explicitExpiry == null) explicitExpiry = date;
    } else if (_issuedKeywords.hasMatch(line)) {
      final date = _extractDate(line) ?? (i + 1 < lines.length ? _extractDate(lines[i + 1]) : null);
      if (date != null && explicitIssued == null) explicitIssued = date;
    }

    final date = _extractDate(line);
    if (date != null) {
      allFoundDates.add(date);
    }
  }

  if (explicitIssued != null || explicitExpiry != null) {
    return _ExtractedDates(issuedDate: explicitIssued, expiryDate: explicitExpiry);
  }

  if (allFoundDates.isEmpty) {
    return const _ExtractedDates();
  }

  allFoundDates.sort();
  if (allFoundDates.length == 1) {
    final single = allFoundDates.first;
    if (single.isAfter(DateTime.now())) {
      return _ExtractedDates(expiryDate: single);
    } else {
      return _ExtractedDates(issuedDate: single);
    }
  }

  return _ExtractedDates(
    issuedDate: allFoundDates.first,
    expiryDate: allFoundDates.last,
  );
}

DateTime? _extractDate(String line) {
  final iso = _isoDatePattern.firstMatch(line);
  if (iso != null) {
    return _tryBuildDate(int.parse(iso.group(1)!), int.parse(iso.group(2)!), int.parse(iso.group(3)!));
  }

  final monthName = _monthNamePattern.firstMatch(line);
  if (monthName != null) {
    final month = _monthAbbrevs.indexOf(monthName.group(1)!.toUpperCase()) + 1;
    final year = _normalizeYear(int.parse(monthName.group(2)!));
    return _lastDayOfMonth(year, month);
  }

  final full = _fullDatePattern.firstMatch(line);
  if (full != null) {
    final a = int.parse(full.group(1)!);
    final b = int.parse(full.group(2)!);
    final year = _normalizeYear(int.parse(full.group(3)!));
    return _tryBuildDate(year, a, b) ?? _tryBuildDate(year, b, a);
  }

  final monthYear = _monthYearPattern.firstMatch(line);
  if (monthYear != null) {
    final month = int.parse(monthYear.group(1)!);
    final year = _normalizeYear(int.parse(monthYear.group(2)!));
    if (month < 1 || month > 12) return null;
    return _lastDayOfMonth(year, month);
  }

  return null;
}

DateTime? _tryBuildDate(int year, int month, int day) {
  if (month < 1 || month > 12) return null;
  if (day < 1 || day > 31) return null;
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

DateTime _lastDayOfMonth(int year, int month) => DateTime(year, month + 1, 0);

int _normalizeYear(int year) => year < 100 ? 2000 + year : year;

// ---------------------------------------------------------------------------
// Medication Extraction
// ---------------------------------------------------------------------------

const _boilerplateWords = [
  'BATCH', 'LOT', 'MFG', 'MFD', 'EXP', 'NDC', 'RX', 'STORE', 'KEEP',
  'CHILDREN', 'WARNING', 'CAUTION', 'DIRECTIONS', 'MANUFACTURED', 'PATIENT',
  'CLINIC', 'HOSPITAL', 'PHARMACY', 'ADDRESS', 'TEL', 'PHONE', 'DATE',
];

final _strengthPattern = RegExp(
  r'\b(\d+(?:\.\d+)?\s*(?:mg|mcg|g|ml|iu|%)(?:\/\d*(?:\.\d+)?\s*(?:ml|mg))?)\b',
  caseSensitive: false,
);

final _formKeywords = {
  'capsule': ['capsule', 'caps', 'cap'],
  'tablet': ['tablet', 'tablets', 'tabs', 'tab'],
  'syrup': ['syrup', 'liquid', 'suspension', 'solution', 'oral solution'],
  'sachet': ['sachet', 'powder', 'granules'],
  'tube': ['cream', 'ointment', 'gel'],
  'bottle': ['drops', 'eye drops', 'ear drops', 'spray', 'lotion'],
};

final _frequencyPatterns = [
  RegExp(r'\b(once\s+daily|1x\s+daily|qd|every\s+day)\b', caseSensitive: false),
  RegExp(r'\b(twice\s+daily|2x\s+daily|bid|b\.i\.d\.)\b', caseSensitive: false),
  RegExp(r'\b(three\s+times\s+daily|3x\s+daily|tid|t\.i\.d\.)\b', caseSensitive: false),
  RegExp(r'\b(four\s+times\s+daily|4x\s+daily|qid|q\.i\.d\.)\b', caseSensitive: false),
  RegExp(r'\b(as\s+needed|prn|p\.r\.n\.)\b', caseSensitive: false),
  RegExp(r'\b(every\s+\d+\s+hours?|q\d+h)\b', caseSensitive: false),
  RegExp(r'\b(at\s+bedtime|qhs)\b', caseSensitive: false),
];

List<PrescriptionItem> _extractMedications(List<String> lines) {
  final items = <PrescriptionItem>[];

  // Strategy 1: Look for numbered or bulleted list lines (e.g. "1. Metformin 500mg...")
  final listPattern = RegExp(r'^(?:(?:\d+[\.\)]|[-•*])\s+)(.+)$');

  for (final line in lines) {
    final listMatch = listPattern.firstMatch(line);
    if (listMatch != null) {
      final content = listMatch.group(1)!.trim();
      final item = _parseMedicationFromLine(content, items.length, isNumbered: true);
      if (item != null) {
        items.add(item);
      }
    }
  }

  // Strategy 2: If no numbered list matched, check if multiple lines have drug strengths
  if (items.isEmpty) {
    final candidateLines = lines.where((l) => !_isHeaderOrBoilerplate(l) && _strengthPattern.hasMatch(l)).toList();
    if (candidateLines.length > 1) {
      for (final line in candidateLines) {
        final item = _parseMedicationFromLine(line, items.length);
        if (item != null) {
          items.add(item);
        }
      }
    }
  }

  // Strategy 3: Single medication fallback (e.g. medicine box or strip)
  if (items.isEmpty) {
    final name = _guessName(lines);
    if (name.isNotEmpty) {
      final detectedForm = _inferForm(name);
      final detectedPackaging = _inferPackaging(detectedForm);
      final strengthMatch = _strengthPattern.firstMatch(name);

      items.add(
        PrescriptionItem(
          id: 'scanned-item-0',
          medicationName: name,
          strength: strengthMatch?.group(1) ?? '',
          form: detectedForm,
          packagingType: detectedPackaging,
          quantity: 1,
          unit: 'units',
          frequency: 'As directed',
          durationDays: 30,
          instructions: '',
        ),
      );
    }
  }

  return items;
}

PrescriptionItem? _parseMedicationFromLine(String line, int index, {bool isNumbered = false}) {
  if (_isHeaderOrBoilerplate(line)) return null;

  final letters = line.replaceAll(RegExp(r'[^A-Za-z]'), '');
  if (letters.length < 3) return null;

  final strengthMatch = _strengthPattern.firstMatch(line);
  final strength = strengthMatch?.group(1) ?? '';

  final form = _inferForm(line);
  final packaging = _inferPackaging(form);

  var frequency = 'As directed';
  for (final p in _frequencyPatterns) {
    final match = p.firstMatch(line);
    if (match != null) {
      frequency = _normalizeFrequency(match.group(0)!);
      break;
    }
  }

  var instructions = '';
  final instMatch = RegExp(r'\b(?:with|after|before)\s+(?:food|meals?)\b', caseSensitive: false).firstMatch(line);
  if (instMatch != null) {
    instructions = instMatch.group(0) ?? '';
  }

  String medName;
  final hasDirections = frequency != 'As directed' || instructions.isNotEmpty;
  if (isNumbered || hasDirections) {
    final parts = line.split(RegExp(r'\s*[-–—:]\s*'));
    var namePart = parts.first;
    if (strength.isNotEmpty) {
      namePart = namePart.replaceFirst(strength, ' ');
    }
    for (final p in _frequencyPatterns) {
      namePart = namePart.replaceAll(p, ' ');
    }
    if (instructions.isNotEmpty) {
      namePart = namePart.replaceAll(instructions, ' ');
    }
    medName = namePart.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (medName.isEmpty) {
      medName = parts.first.trim();
    }
  } else {
    medName = line.trim();
  }

  return PrescriptionItem(
    id: 'scanned-item-$index',
    medicationName: _truncate(medName, 60),
    strength: strength,
    form: form,
    packagingType: packaging,
    quantity: 1,
    unit: form == 'syrup' ? 'bottle' : 'units',
    frequency: frequency,
    durationDays: 30,
    instructions: instructions,
  );
}

String _inferForm(String text) {
  final lower = text.toLowerCase();
  for (final entry in _formKeywords.entries) {
    for (final keyword in entry.value) {
      if (lower.contains(keyword)) {
        return entry.key;
      }
    }
  }
  return 'tablet';
}

String _inferPackaging(String form) {
  return switch (form) {
    'capsule' || 'tablet' => 'box',
    'syrup' => 'bottle',
    'sachet' => 'sachet',
    'tube' => 'tube',
    _ => 'box',
  };
}

String _normalizeFrequency(String raw) {
  final lower = raw.toLowerCase().replaceAll('.', '');
  if (lower.contains('once') || lower == 'qd' || lower.contains('1x')) return '1x daily';
  if (lower.contains('twice') || lower == 'bid' || lower.contains('2x')) return '2x daily';
  if (lower.contains('three') || lower == 'tid' || lower.contains('3x')) return '3x daily';
  if (lower.contains('four') || lower == 'qid' || lower.contains('4x')) return '4x daily';
  if (lower.contains('needed') || lower == 'prn') return 'As needed';
  return raw;
}

bool _isHeaderOrBoilerplate(String line) {
  final upper = line.toUpperCase();
  if (_expiryKeywords.hasMatch(line) || _issuedKeywords.hasMatch(line)) return true;
  return _boilerplateWords.any((w) => upper == w || upper.startsWith('$w '));
}

String _guessName(List<String> lines) {
  for (final line in lines) {
    final letters = line.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (letters.length < 3) continue;
    if (_isHeaderOrBoilerplate(line)) continue;
    return _truncate(line, 60);
  }
  return '';
}

String _truncate(String value, int maxLength) =>
    value.length <= maxLength ? value : value.substring(0, maxLength);
