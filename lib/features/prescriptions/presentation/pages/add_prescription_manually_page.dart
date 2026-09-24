import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/prescription.dart';
import '../../domain/entities/prescription_item.dart';
import '../providers/prescriptions_providers.dart';

class AddPrescriptionManuallyPage extends ConsumerStatefulWidget {
  const AddPrescriptionManuallyPage({super.key});

  @override
  ConsumerState<AddPrescriptionManuallyPage> createState() => _AddPrescriptionManuallyPageState();
}

class _MedFormControllers {
  _MedFormControllers()
      : name = TextEditingController(),
        strength = TextEditingController(),
        quantity = TextEditingController(text: '1'),
        unit = TextEditingController(text: 'units'),
        frequency = TextEditingController(text: 'As directed'),
        durationDays = TextEditingController(text: '30'),
        instructions = TextEditingController(),
        unitQuantity = TextEditingController(text: '1'),
        form = 'tablet',
        refillsAllowed = 0,
        packagingType = 'box';

  final TextEditingController name;
  final TextEditingController strength;
  final TextEditingController quantity;
  final TextEditingController unit;
  final TextEditingController frequency;
  final TextEditingController durationDays;
  final TextEditingController instructions;
  final TextEditingController unitQuantity;
  DateTime? expiryDate;
  String form;
  int refillsAllowed;
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

class _AddPrescriptionManuallyPageState extends ConsumerState<AddPrescriptionManuallyPage> {
  final List<_MedFormControllers> _medControllers = [_MedFormControllers()];
  DateTime _issuedDate = DateTime.now();
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 30));
  String? _validationError;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _medControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addMedication() {
    setState(() {
      _medControllers.add(_MedFormControllers());
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
    if (user == null) return;

    final items = <PrescriptionItem>[];
    for (var i = 0; i < _medControllers.length; i++) {
      final c = _medControllers[i];
      final name = c.name.text.trim();
      if (name.isEmpty) continue;
      items.add(
        PrescriptionItem(
          id: 'manual-item-$i',
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
              source: PrescriptionSource.manualExternal,
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

    return Scaffold(
      appBar: LargeTitleAppBar(
        title: 'Add Prescription',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Enter the details of your prescription manually.',
              style: TextStyle(fontSize: 14, color: colors.textSecondary),
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
                PrimaryButton(
                  label: 'Save Prescription',
                  onPressed: _saving ? null : _save,
                  loading: _saving,
                ),
              ],
            ),
          ),
        ],
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF101015) : colors.surfaceSubtle;
    final textColor = isDark ? Colors.white : colors.textPrimary;
    final textMuted = isDark ? Colors.white60 : colors.textSecondary;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : colors.border;
    final bgGradientColors = isDark 
        ? [const Color(0xFF4A3BB1), const Color(0xFF4A3BB1).withValues(alpha: 0.5), const Color(0xFF101015)]
        : [colors.surfaceMuted, colors.surfaceSubtle, colors.surfaceSubtle];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: RadialGradient(
          center: Alignment.topLeft,
          radius: 2.0,
          colors: bgGradientColors,
          stops: const [0.0, 0.5, 1.0],
        ),
        border: Border.all(color: borderColor),
        boxShadow: isDark ? [
          BoxShadow(
            color: const Color(0xFF4A3BB1).withValues(alpha: 0.25),
            blurRadius: 30,
            spreadRadius: -10,
            offset: const Offset(0, 10),
          ),
        ] : [],
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
                  color: textMuted,
                ),
              ),
              Row(
                children: [
                  if (_medControllers.length > 1)
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: textMuted, size: 20),
                      onPressed: () => _removeMedication(index),
                      tooltip: 'Remove medication',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    '#${index + 1}',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.5,
                      color: textColor,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          _themedTextField(c.name, 'Medication name', textColor, textMuted, borderColor),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _themedTextField(c.strength, 'Strength (e.g. 500mg)', textColor, textMuted, borderColor)),
              const SizedBox(width: 12),
              Expanded(
                child: _themedDropdown(
                  value: c.packagingType,
                  items: const ['box', 'strip', 'bottle', 'sachet', 'tube'],
                  label: 'Packaging Type',
                  textColor: textColor,
                  textMuted: textMuted,
                  borderColor: borderColor,
                  dropdownColor: cardColor,
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
                child: _themedTextField(
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
                  textColor, textMuted, borderColor,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _themedTextField(c.unitQuantity, 'Units per ${c.packagingType}', textColor, textMuted, borderColor, keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _themedTextField(c.unit, 'Unit', textColor, textMuted, borderColor)),
              const SizedBox(width: 12),
              Expanded(child: _themedTextField(c.frequency, 'Frequency', textColor, textMuted, borderColor)),
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
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _themedTextField(c.durationDays, 'Duration (days)', textColor, textMuted, borderColor, keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 12),
          _themedTextField(c.instructions, 'Instructions', textColor, textMuted, borderColor, maxLines: 2),
        ],
      ),
    );
  }

  Widget _themedTextField(TextEditingController controller, String label, Color textColor, Color textMuted, Color borderColor, {TextInputType? keyboardType, int? maxLines}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: 1,
      style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textMuted, fontSize: 13),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: borderColor)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: textColor)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }

  Widget _themedDropdown({
    required String value,
    required List<String> items,
    required String label,
    required Color textColor,
    required Color textMuted,
    required Color borderColor,
    required Color dropdownColor,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      dropdownColor: dropdownColor,
      style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textMuted, fontSize: 13),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: borderColor)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: textColor)),
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
