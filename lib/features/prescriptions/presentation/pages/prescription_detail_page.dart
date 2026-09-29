import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../../shared/presentation/widgets/status_badge.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/prescription.dart';
import '../../domain/entities/prescription_item.dart';
import '../providers/prescriptions_providers.dart';

/// Displays full details for a prescription, reusing the exact medication
/// card styling and fields from the Add Prescription flow.
class PrescriptionDetailPage extends ConsumerWidget {
  const PrescriptionDetailPage({super.key, required this.prescription});

  final Prescription prescription;

  StatusTone get _tone => switch (prescription.status) {
        PrescriptionStatus.active => StatusTone.success,
        PrescriptionStatus.expiring => StatusTone.warning,
        PrescriptionStatus.expired => StatusTone.danger,
        PrescriptionStatus.dispensed => StatusTone.info,
        PrescriptionStatus.cancelled => StatusTone.neutral,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final isScanned = prescription.source == PrescriptionSource.scannedExternal;
    final isManual = prescription.source == PrescriptionSource.manualExternal;
    final prescriberName = (isScanned || isManual)
        ? (prescription.externalDoctorName ?? 'Self-recorded')
        : ref.watch(userProfileProvider(prescription.doctorId)).valueOrNull?.fullName;

    return Scaffold(
      appBar: LargeTitleAppBar(
        title: 'Prescription Details',
        onBack: () => Navigator.of(context).pop(),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: colors.danger),
            tooltip: 'Delete prescription',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          // ── Overview Card ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colors.patientAccent.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.medication_liquid_rounded,
                            size: 20,
                            color: colors.patientAccent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isScanned
                              ? 'Scanned Prescription'
                              : isManual
                                  ? 'Manual Entry'
                                  : 'Doctor Prescription',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    StatusBadge(label: prescription.status.label, tone: _tone),
                  ],
                ),
                if (prescriberName != null && prescriberName.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 15, color: colors.textTertiary),
                      const SizedBox(width: 6),
                      Text(
                        isScanned || isManual ? prescriberName : 'Dr. $prescriberName',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Divider(height: 1, color: colors.border),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Issued', style: TextStyle(fontSize: 11, color: colors.textTertiary)),
                          const SizedBox(height: 2),
                          Text(
                            DateFormatters.short(prescription.issuedDate),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Valid Until', style: TextStyle(fontSize: 11, color: colors.textTertiary)),
                          const SizedBox(height: 2),
                          Text(
                            DateFormatters.short(prescription.expiryDate),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Medications Section Header ────────────────────────────
          Row(
            children: [
              Text(
                'Medications (${prescription.items.length})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (prescription.items.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              child: Center(
                child: Text(
                  'No medication items recorded for this prescription.',
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
              ),
            )
          else
            for (var i = 0; i < prescription.items.length; i++) ...[
              _medicationCard(context, colors, prescription.items[i], i),
              const SizedBox(height: 14),
            ],
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.danger,
              side: BorderSide(color: colors.danger.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            label: const Text('Delete Prescription', style: TextStyle(fontWeight: FontWeight.w600)),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Prescription'),
        content: const Text(
          'Are you sure you want to delete this prescription? All medications recorded under this prescription will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(prescriptionsRepositoryProvider).delete(prescription.id);
      ref.read(prescriptionsRevisionProvider.notifier).state++;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prescription deleted successfully')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  /// Reuses the exact medication card design, styling, and fields from Add Prescription.
  Widget _medicationCard(
    BuildContext context,
    AppSemanticColors colors,
    PrescriptionItem item,
    int index,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : colors.textPrimary;
    final textMuted = isDark ? Colors.white60 : colors.textSecondary;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : colors.border;
    final bgGradientColors = isDark
        ? [
            const Color(0xFF10B981),
            const Color(0xFF10B981).withValues(alpha: 0.4),
            const Color(0xFF101015),
          ]
        : [
            colors.surfaceMuted,
            colors.surfaceSubtle,
            colors.surfaceSubtle,
          ];

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
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.25),
                  blurRadius: 30,
                  spreadRadius: -10,
                  offset: const Offset(0, 10),
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
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
              Text(
                '#${index + 1}',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                  color: textColor,
                  height: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Medication name
          _displayField('Medication name', item.medicationName, textColor, textMuted, borderColor),
          const SizedBox(height: 12),

          // Strength & Packaging Type
          Row(
            children: [
              Expanded(
                child: _displayField(
                  'Strength',
                  item.strength.isNotEmpty ? item.strength : '—',
                  textColor,
                  textMuted,
                  borderColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _displayField(
                  'Packaging Type',
                  item.packagingType.isNotEmpty
                      ? '${item.packagingType[0].toUpperCase()}${item.packagingType.substring(1)}'
                      : 'Box',
                  textColor,
                  textMuted,
                  borderColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Number of packages & Units per package
          Row(
            children: [
              Expanded(
                child: _displayField(
                  'Number of ${item.packagingType}${item.packagingType == 'box' ? 'es' : 's'}',
                  '${item.quantity}',
                  textColor,
                  textMuted,
                  borderColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _displayField(
                  'Units per ${item.packagingType}',
                  '${item.unitQuantity}',
                  textColor,
                  textMuted,
                  borderColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Unit & Frequency
          Row(
            children: [
              Expanded(
                child: _displayField('Unit', item.unit, textColor, textMuted, borderColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _displayField('Frequency', item.frequency, textColor, textMuted, borderColor),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Medication Expiry & Duration
          Row(
            children: [
              Expanded(
                child: _displayField(
                  'Medication Expiry',
                  item.expiryDate != null ? DateFormatters.short(item.expiryDate!) : '—',
                  textColor,
                  textMuted,
                  borderColor,
                  icon: Icons.calendar_today_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _displayField(
                  'Duration (days)',
                  '${item.durationDays}',
                  textColor,
                  textMuted,
                  borderColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Instructions
          _displayField(
            'Instructions',
            item.instructions.isNotEmpty ? item.instructions : 'As directed',
            textColor,
            textMuted,
            borderColor,
          ),
        ],
      ),
    );
  }

  Widget _displayField(
    String label,
    String value,
    Color textColor,
    Color textMuted,
    Color borderColor, {
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: textMuted, fontSize: 11)),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(color: textColor, fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
              if (icon != null) Icon(icon, size: 14, color: textMuted),
            ],
          ),
        ],
      ),
    );
  }
}
