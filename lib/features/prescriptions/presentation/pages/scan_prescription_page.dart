import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/prescription.dart';
import '../../domain/entities/prescription_item.dart';
import '../../domain/scanned_prescription_ocr.dart';
import '../../domain/scanned_prescription_payload.dart';
import '../providers/prescriptions_providers.dart';
import 'add_prescription_manually_page.dart';

/// Digitizes a paper prescription or medication package from an outside prescriber:
/// the patient takes a photo or selects an image from their gallery, optical
/// character recognition (OCR) extracts medication details, and the patient reviews
/// and edits the details before saving to their permanent records.
class ScanPrescriptionPage extends ConsumerStatefulWidget {
  const ScanPrescriptionPage({super.key});

  @override
  ConsumerState<ScanPrescriptionPage> createState() => _ScanPrescriptionPageState();
}

class _MedFormControllers {
  _MedFormControllers(PrescriptionItem item)
      : name = TextEditingController(text: item.medicationName),
        strength = TextEditingController(text: item.strength),
        quantity = TextEditingController(text: item.quantity.toString()),
        unit = TextEditingController(text: item.unit),
        frequency = TextEditingController(text: item.frequency),
        durationDays = TextEditingController(text: item.durationDays.toString()),
        instructions = TextEditingController(text: item.instructions),
        form = item.form,
        expiryDate = item.expiryDate,
        refillsAllowed = item.refillsAllowed,
        packagingType = item.packagingType,
        unitQuantity = TextEditingController(text: item.unitQuantity.toString());

  final TextEditingController name;
  final TextEditingController strength;
  final TextEditingController quantity;
  final TextEditingController unit;
  final TextEditingController frequency;
  final TextEditingController durationDays;
  final TextEditingController instructions;
  final TextEditingController unitQuantity;
  DateTime? expiryDate;
  final String form;
  final int refillsAllowed;
  String packagingType;

  void dispose() {
    name.dispose();
    strength.dispose();
    quantity.dispose();
    unit.dispose();
    frequency.dispose();
    durationDays.dispose();
    instructions.dispose();
    unitQuantity.dispose();
  }
}

class _ScanPrescriptionPageState extends ConsumerState<ScanPrescriptionPage> {
  ScannedPrescriptionPayload? _payload;
  List<_MedFormControllers> _medControllers = [];
  DateTime _issuedDate = DateTime.now();
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 30));
  String? _validationError;
  bool _saving = false;
  bool _processingPhoto = false;
  bool _confirmedDetails = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    for (final c in _medControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _showScanOptions() {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF16161F) : colors.surfaceSubtle;
    final textColor = isDark ? Colors.white : colors.textPrimary;
    final mutedTextColor = isDark ? Colors.white60 : colors.textSecondary;
    
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Scan Prescription (OCR)',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Take a clear photo of your paper prescription or medication box.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: mutedTextColor, fontSize: 13),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.blueAccent),
                  ),
                  title: Text('Take Photo', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                  subtitle: Text('Capture with device camera', style: TextStyle(color: mutedTextColor, fontSize: 12)),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _takePhoto(fromGallery: false);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: Colors.purpleAccent),
                  ),
                  title: Text('Choose from Photos', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                  subtitle: Text('Upload prescription image from gallery', style: TextStyle(color: mutedTextColor, fontSize: 12)),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _takePhoto(fromGallery: true);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.edit_note_rounded, color: isDark ? Colors.white : Colors.black87),
                  ),
                  title: Text('Enter Manually', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                  subtitle: Text('Type details without scanning', style: TextStyle(color: mutedTextColor, fontSize: 12)),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const AddPrescriptionManuallyPage()),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _takePhoto({bool fromGallery = false}) async {
    XFile? photo;
    try {
      photo = await ImagePicker().pickImage(
        source: fromGallery ? ImageSource.gallery : ImageSource.camera,
        maxWidth: 2400,
      );
    } catch (_) {
      photo = null;
    }
    if (!mounted) return;
    if (photo == null) {
      if (_payload == null) {
        // If user cancelled the initial camera launch, stay on the prompt screen
        setState(() {});
      }
      return;
    }

    setState(() => _processingPhoto = true);

    var recognizedText = '';
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      recognizedText = (await recognizer.processImage(InputImage.fromFilePath(photo.path))).text;
    } catch (_) {
      recognizedText = '';
    } finally {
      await recognizer.close();
    }
    if (!mounted) return;

    final payload = buildPayloadFromOcrText(recognizedText);
    setState(() => _processingPhoto = false);
    _applyPayload(payload);
  }



  void _applyPayload(ScannedPrescriptionPayload payload) {
    for (final c in _medControllers) {
      c.dispose();
    }
    setState(() {
      _confirmedDetails = false;
      _payload = payload;
      _validationError = null;
      _issuedDate = payload.issuedDate;
      _expiryDate = payload.expiryDate;
      _medControllers = payload.medications.map(_MedFormControllers.new).toList();
    });
  }

  void _addMedication() {
    setState(() {
      _medControllers.add(
        _MedFormControllers(
          PrescriptionItem(
            id: 'scanned-item-${_medControllers.length}',
            medicationName: '',
            strength: '',
            form: 'tablet',
            quantity: 1,
            unit: 'units',
            frequency: 'As directed',
            durationDays: 30,
            instructions: '',
          ),
        ),
      );
    });
  }

  void _removeMedication(int index) {
    if (_medControllers.length <= 1) return;
    setState(() {
      final removed = _medControllers.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    if (_payload == null || user == null) return;

    final items = <PrescriptionItem>[];
    for (var i = 0; i < _medControllers.length; i++) {
      final c = _medControllers[i];
      final name = c.name.text.trim();
      if (name.isEmpty) continue;
      items.add(
        PrescriptionItem(
          id: 'scanned-item-$i',
          medicationName: name,
          strength: c.strength.text.trim(),
          form: c.form,
          quantity: int.tryParse(c.quantity.text.trim()) ?? 1,
          unit: c.unit.text.trim().isEmpty ? 'units' : c.unit.text.trim(),
          frequency: c.frequency.text.trim().isEmpty ? 'As directed' : c.frequency.text.trim(),
          durationDays: int.tryParse(c.durationDays.text.trim()) ?? 30,
          instructions: c.instructions.text.trim(),
          expiryDate: c.expiryDate,
          refillsAllowed: c.refillsAllowed,
          packagingType: c.packagingType,
          unitQuantity: int.tryParse(c.unitQuantity.text.trim()) ?? 1,
        ),
      );
    }

    if (items.isEmpty) {
      setState(() => _validationError = 'Enter at least a medication name before saving.');
      return;
    }

    setState(() {
      _validationError = null;
      _saving = true;
    });

    try {
      await ref.read(prescriptionsRepositoryProvider).create(
            Prescription(
              id: '',
              patientId: user.id,
              doctorId: 'external',
              issuedDate: _issuedDate,
              expiryDate: _expiryDate,
              status: PrescriptionStatus.active,
              items: items,
              source: PrescriptionSource.scannedExternal,
            ),
          );
      ref.read(prescriptionsRevisionProvider.notifier).state++;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prescription saved successfully!'),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _validationError = 'Failed to save: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final payload = _payload;

    return Scaffold(
      appBar: LargeTitleAppBar(
        title: 'Scan Prescription',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: _processingPhoto
          ? _buildProcessingState(colors)
          : payload != null
              ? _buildReview(context, colors)
              : _buildPromptState(colors),
    );
  }

  Widget _buildProcessingState(AppSemanticColors colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Analyzing with OCR...',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'Recognizing text and medication fields',
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptState(AppSemanticColors colors) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : colors.textPrimary;
    final mutedTextColor = isDark ? Colors.white60 : colors.textSecondary;
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.document_scanner_rounded, size: 40, color: Colors.blueAccent),
            ),
            const SizedBox(height: 20),
            Text(
              'OCR Prescription Scanner',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Capture a photo of your paper prescription or medication box to automatically extract medication names, dosages, and expiration dates.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: mutedTextColor, height: 1.4),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _takePhoto(fromGallery: false),
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Take Photo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _takePhoto(fromGallery: true),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose from Photos'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textColor,
                  side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.2) : colors.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const AddPrescriptionManuallyPage()),
                );
              },
              child: Text('Enter Details Manually', style: TextStyle(color: mutedTextColor)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReview(BuildContext context, AppSemanticColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Review OCR Results', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Optical character recognition extracts text from your photo. Please verify details, dates, and dosages before saving.',
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _dateField(context, colors, 'Issued', _issuedDate, (d) {
                          setState(() => _issuedDate = d);
                        })),
                        const SizedBox(width: 16),
                        Expanded(child: _dateField(context, colors, 'Expires', _expiryDate, (d) {
                          setState(() => _expiryDate = d);
                        })),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Medications (${_medControllers.length})', style: Theme.of(context).textTheme.titleSmall),
                  TextButton.icon(
                    onPressed: _addMedication,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Medication', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < _medControllers.length; i++) ...[
                _medicationCard(context, colors, _medControllers[i], i),
                const SizedBox(height: 12),
              ],
              if (_validationError != null) ...[
                const SizedBox(height: 4),
                Text(_validationError!, style: TextStyle(fontSize: 12, color: colors.danger)),
              ],
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _confirmedDetails,
                onChanged: (v) => setState(() => _confirmedDetails = v ?? false),
                title: const Text('I have verified the spelling and details of the medication(s) are correct.', style: TextStyle(fontSize: 12)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: colors.patientAccent,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _showScanOptions,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Rescan'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: PrimaryButton(
                      label: 'Save Prescription',
                      onPressed: (!_confirmedDetails || _saving) ? null : _save,
                      loading: _saving,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dateField(
    BuildContext context,
    AppSemanticColors colors,
    String label,
    DateTime value,
    ValueChanged<DateTime> onChanged, {
    bool isDark = false,
  }) {
    final textColor = isDark ? Colors.white : colors.textPrimary;
    final textMuted = isDark ? Colors.white60 : colors.textTertiary;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10.5, color: textMuted)),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                DateFormatters.short(value),
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textColor),
              ),
              const SizedBox(width: 4),
              Icon(Icons.edit_calendar_outlined, size: 13, color: textMuted),
            ],
          ),
        ],
      ),
    );
  }

  Widget _medicationCard(BuildContext context, AppSemanticColors colors, _MedFormControllers c, int index) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: RadialGradient(
          center: Alignment.topLeft,
          radius: 2.0,
          colors: [
            const Color(0xFF4A3BB1),
            const Color(0xFF4A3BB1).withValues(alpha: 0.5),
            const Color(0xFF101015),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A3BB1).withValues(alpha: 0.25),
            blurRadius: 30,
            spreadRadius: -10,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MEDICATION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              Row(
                children: [
                  if (_medControllers.length > 1)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                      onPressed: () => _removeMedication(index),
                      tooltip: 'Remove medication',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    '#${index + 1}',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.5,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          _darkTextField(c.name, 'Medication name'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _darkTextField(c.strength, 'Strength (e.g. 500mg)')),
              const SizedBox(width: 12),
              Expanded(
                child: _darkDropdown(
                  value: c.packagingType,
                  items: const ['box', 'strip', 'bottle', 'sachet', 'tube'],
                  label: 'Packaging Type',
                  onChanged: (val) {
                    if (val != null) setState(() => c.packagingType = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _darkTextField(
                  c.quantity,
                  c.packagingType == 'strip'
                      ? 'Number of strips'
                      : c.packagingType == 'box'
                          ? 'Number of boxes'
                          : c.packagingType == 'bottle'
                              ? 'Number of bottles'
                              : c.packagingType == 'sachet'
                                  ? 'Number of sachets'
                                  : c.packagingType == 'tube'
                                      ? 'Number of tubes'
                                      : 'Quantity',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _darkTextField(c.unitQuantity, 'Units per ${c.packagingType}', keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _darkTextField(c.unit, 'Unit')),
              const SizedBox(width: 12),
              Expanded(child: _darkTextField(c.frequency, 'Frequency')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _dateField(
                  context,
                  colors,
                  'Medication Expiry',
                  c.expiryDate ?? DateTime.now().add(const Duration(days: 365)),
                  (d) => setState(() => c.expiryDate = d),
                  isDark: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _darkTextField(c.durationDays, 'Duration (days)', keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 12),
          _darkTextField(c.instructions, 'Instructions', maxLines: 2),
        ],
      ),
    );
  }

  Widget _darkTextField(TextEditingController controller, String label, {TextInputType? keyboardType, int? maxLines}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: 1,
      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }

  Widget _darkDropdown({
    required String value,
    required List<String> items,
    required String label,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      dropdownColor: const Color(0xFF101015),
      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item[0].toUpperCase() + item.substring(1)),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}
