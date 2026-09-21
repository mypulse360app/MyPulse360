import 'package:flutter/material.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';

const kVerificationSteps = [
  'Patient identity confirmed (Name & ID)',
  'Dosage, frequency & duration verified',
  'Known allergies & contraindications checked',
  'Packaging labeled with counseling instructions',
];

/// Premium verification checklist with progress tracking and tactile check cards.
class VerificationChecklist extends StatelessWidget {
  const VerificationChecklist({
    super.key,
    required this.checked,
    required this.onChanged,
  });

  final Set<int> checked;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final total = kVerificationSteps.length;
    final count = checked.length;
    final isAllChecked = count == total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with dynamic progress badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isAllChecked
                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                : colors.surfaceSubtle,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAllChecked
                  ? const Color(0xFF10B981).withValues(alpha: 0.4)
                  : colors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isAllChecked ? Icons.verified_rounded : Icons.checklist_rounded,
                size: 18,
                color: isAllChecked ? const Color(0xFF10B981) : colors.clinicianAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isAllChecked
                      ? 'All verification checks passed'
                      : 'Mandatory clinical safety checks',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isAllChecked
                        ? const Color(0xFF10B981)
                        : colors.textSecondary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isAllChecked
                      ? const Color(0xFF10B981)
                      : colors.clinicianAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count / $total Verified',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isAllChecked
                        ? Colors.white
                        : colors.clinicianAccent,
                  ),
                ),
              ),
            ],
          ),
        ),

        // List of interactive check tiles
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: colors.border),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                for (var i = 0; i < kVerificationSteps.length; i++) ...[
                  InkWell(
                    onTap: () => onChanged(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: checked.contains(i)
                                  ? const Color(0xFF10B981)
                                  : Colors.transparent,
                              border: Border.all(
                                color: checked.contains(i)
                                    ? const Color(0xFF10B981)
                                    : colors.border,
                                width: 2,
                              ),
                            ),
                            child: checked.contains(i)
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              kVerificationSteps[i],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: checked.contains(i)
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: checked.contains(i)
                                    ? colors.textPrimary
                                    : colors.textSecondary,
                              ),
                            ),
                          ),
                          Text(
                            'Step ${i + 1}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: colors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (i != kVerificationSteps.length - 1)
                    Divider(height: 1, indent: 48, color: colors.border),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
