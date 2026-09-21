import 'package:flutter/material.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/utils/id_generator.dart';
import '../../../prescriptions/domain/entities/prescription_item.dart';

class PrescriptionItemForm extends StatefulWidget {
  const PrescriptionItemForm({super.key, required this.onAdd});

  final ValueChanged<PrescriptionItem> onAdd;

  @override
  State<PrescriptionItemForm> createState() => _PrescriptionItemFormState();
}

class _PrescriptionItemFormState extends State<PrescriptionItemForm> {
  final _name = TextEditingController();
  final _strength = TextEditingController();
  final _frequency = TextEditingController();
  final _duration = TextEditingController(text: '7');
  final _instructions = TextEditingController();
  bool _isExpanded = false;
  final String _selectedForm = 'tablet';

  @override
  void dispose() {
    _name.dispose();
    _strength.dispose();
    _frequency.dispose();
    _duration.dispose();
    _instructions.dispose();
    super.dispose();
  }

  void _add() {
    if (_name.text.trim().isEmpty) return;
    widget.onAdd(
      PrescriptionItem(
        id: generateId(),
        medicationName: _name.text.trim(),
        strength: _strength.text.trim().isEmpty ? '—' : _strength.text.trim(),
        form: _selectedForm,
        quantity: (int.tryParse(_duration.text) ?? 7) * 2,
        unit: _selectedForm == 'syrup' ? 'ml' : 'tablets',
        frequency: _frequency.text.trim().isEmpty ? 'As directed' : _frequency.text.trim(),
        durationDays: int.tryParse(_duration.text) ?? 7,
        instructions: _instructions.text.trim().isEmpty ? 'As directed' : _instructions.text.trim(),
      ),
    );
    _name.clear();
    _strength.clear();
    _frequency.clear();
    _instructions.clear();
    _duration.text = '7';
    setState(() => _isExpanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (!_isExpanded) {
      return OutlinedButton.icon(
        onPressed: () => setState(() => _isExpanded = true),
        icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
        label: const Text('Add Additional Medication'),
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.clinicianAccent,
          side: BorderSide(color: colors.clinicianAccent.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.clinicianAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.medication_liquid_outlined, size: 18, color: colors.clinicianAccent),
              const SizedBox(width: 8),
              Text(
                'New Medication Item',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                visualDensity: VisualDensity.compact,
                color: colors.textSecondary,
                onPressed: () => setState(() => _isExpanded = false),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(flex: 3, child: _field('Medication Name', _name, hint: 'e.g. Paracetamol')),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: _field('Strength', _strength, hint: 'e.g. 500mg')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(flex: 3, child: _field('Frequency', _frequency, hint: 'e.g. TDS / 3x daily')),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: _field('Duration (Days)', _duration, numeric: true)),
            ],
          ),
          const SizedBox(height: 10),
          _field('Instructions & Notes', _instructions, hint: 'e.g. Take after meals with water'),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _isExpanded = false),
                child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Add to Prescription'),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.clinicianAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, {bool numeric = false, String? hint}) {
    return TextField(
      controller: controller,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 11),
        labelStyle: const TextStyle(fontSize: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
