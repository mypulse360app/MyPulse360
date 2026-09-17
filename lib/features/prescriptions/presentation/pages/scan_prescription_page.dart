import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/barcode_scanner_sheet.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/prescription.dart';
import '../../domain/entities/prescription_item.dart';
import '../../domain/scanned_prescription_ocr.dart';
import '../../domain/scanned_prescription_parser.dart';
import '../providers/prescriptions_providers.dart';

/// Digitizes a paper prescription from an outside prescriber: the patient
/// scans a QR/barcode or takes a photo, then reviews (and, when needed,
/// fills in) the details before saving. Most real-world codes — a barcode
/// off a medicine box, say — aren't in MyPulse360's own JSON schema and
/// can't encode things like expiry date at all, so both paths land on the
/// same editable draft rather than presenting a guess as fact. This never
/// touches the pharmacist's own verification queue; it's purely the
/// patient's own copy of something prescribed elsewhere.
class ScanPrescriptionPage extends ConsumerStatefulWidget {
  const ScanPrescriptionPage({super.key});

  @override
  ConsumerState<ScanPrescriptionPage> createState() => _ScanPrescriptionPageState();
}

enum _ScanState { idle, error }

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
  _ScanState _state = _ScanState.idle;
  ScannedPrescriptionPayload? _payload;
  final TextEditingController _prescriberController = TextEditingController();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startScan();
    });
  }

  @override
  void dispose() {
    _prescriberController.dispose();
    for (final c in _medControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _startScan() async {
    final code = await showBarcodeScanner(
      context,
      title: 'Scan prescription',
      instructions: 'Point the camera at your prescription\'s QR code or barcode',
    );
    if (!mounted) return;
    
    if (code == null) {
      if (_payload == null) {
        Navigator.of(context).pop();
      }
      return;
    }

    if (code == 'PICK_PHOTO') {
      _takePhoto(fromGallery: true);
      return;
    } else if (code == 'STRIP_OCR') {
      _takePhoto(fromGallery: false); // Use camera for strip OCR
      return;
    } else if (code == 'MANUAL') {
      _applyPayload(buildFallbackScannedPayload(''));
      return;
    }

    if (code.trim().isEmpty) {
      setState(() => _state = _ScanState.error);
      if (_payload == null) _startScan(); // Retry if we were on the initial empty screen
      return;
    }

    final payload = parseScannedPrescriptionPayload(code) ?? buildFallbackScannedPayload(code);
    _applyPayload(payload);
  }

  Future<void> _takePhoto({bool fromGallery = false}) async {
    XFile? photo;
    try {
      photo = await ImagePicker().pickImage(
        source: fromGallery ? ImageSource.gallery : ImageSource.camera, 
        maxWidth: 2000,
      );
    } catch (_) {
      photo = null;
    }
    if (!mounted) return;
    if (photo == null) {
      if (_payload == null) {
        Navigator.of(context).pop();
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

    final payload =
        recognizedText.trim().isEmpty ? buildFallbackScannedPayload('') : buildPayloadFromOcrText(recognizedText);
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
      _state = _ScanState.idle;
      _validationError = null;
      _issuedDate = payload.issuedDate;
      _expiryDate = payload.expiryDate;
      _prescriberController.text = payload.prescriberName ?? '';
      _medControllers = payload.medications.map(_MedFormControllers.new).toList();
    });
  }

  void _rescan() {
    for (final c in _medControllers) {
      c.dispose();
    }
    setState(() {
      _payload = null;
      _medControllers = [];
      _validationError = null;
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

    final prescriberName = _prescriberController.text.trim();
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
            externalDoctorName: prescriberName.isEmpty ? null : prescriberName,
          ),
        );
    ref.read(prescriptionsRevisionProvider.notifier).state++;
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final payload = _payload;

    return Scaffold(
      appBar: LargeTitleAppBar(
        title: 'Scan Prescription',
        onBack: payload != null ? () {
          _rescan();
          _startScan();
        } : null,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: payload != null ? _buildReview(context, colors) : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildReview(BuildContext context, AppSemanticColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review before saving', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          "These are our best guesses, not confirmed facts — double-check everything, especially the expiry "
          'date, and fix anything before saving. This will be kept as a permanent record in your prescriptions.',
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 120),
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
                    TextField(
                      controller: _prescriberController,
                      decoration: const InputDecoration(labelText: 'Prescriber (optional)', isDense: true),
                    ),
                    const SizedBox(height: 8),
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
              const SizedBox(height: 14),
              Text('Medications', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              for (var i = 0; i < _medControllers.length; i++) ...[
                _medicationCard(context, colors, _medControllers[i], i + 1),
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
                    child: OutlinedButton(
                      onPressed: _saving ? null : () {
                        _rescan();
                        _startScan();
                      },
                      child: const Text('Rescan'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: PrimaryButton(
                      label: 'Save', 
                      onPressed: (!_confirmedDetails || _saving) ? null : _save, 
                      loading: _saving
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
    ValueChanged<DateTime> onChanged,
  ) {
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
          Text(label, style: TextStyle(fontSize: 10.5, color: colors.textTertiary)),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                DateFormatters.short(value),
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.textPrimary),
              ),
              const SizedBox(width: 4),
              Icon(Icons.edit_calendar_outlined, size: 13, color: colors.textTertiary),
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
            const Color(0xFF4A3BB1), // Vibrant Purple/Blue
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
              Text(
                '#$index',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _darkTextField(c.name, 'Medication name'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _darkTextField(c.strength, 'Strength')),
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
                  c.packagingType == 'strip' ? 'Number of strips' : 
                  c.packagingType == 'box' ? 'Number of boxes' :
                  c.packagingType == 'bottle' ? 'Number of bottles' :
                  c.packagingType == 'sachet' ? 'Number of sachets' :
                  c.packagingType == 'tube' ? 'Number of tubes' : 'Quantity', 
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
          _darkTextField(c.durationDays, 'Duration (days)', keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          _darkTextField(c.instructions, 'Instructions', maxLines: 3),
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
      value: value,
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
