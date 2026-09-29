import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/presentation/widgets/status_badge.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/prescription.dart';
import '../pages/prescription_detail_page.dart';
import '../providers/prescriptions_providers.dart';

class PrescriptionCard extends ConsumerWidget {
  const PrescriptionCard({super.key, required this.prescription});

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
    final isScanned = prescription.source == PrescriptionSource.scannedExternal;
    final isManual = prescription.source == PrescriptionSource.manualExternal;
    final prescriberName = (isScanned || isManual)
        ? prescription.externalDoctorName
        : ref.watch(userProfileProvider(prescription.doctorId)).valueOrNull?.fullName;

    final isExpired = prescription.status == PrescriptionStatus.expired;
    final isExpiring = prescription.status == PrescriptionStatus.expiring;

    // Vibrant background gradient matching Today's Medication Reminder
    final Color baseColor;
    if (isExpired) {
      baseColor = const Color(0xFF383842); // Muted dark slate
    } else if (isExpiring) {
      baseColor = const Color(0xFFC76D0E); // Warm amber
    } else {
      baseColor = const Color(0xFF10B981); // Emerald Green (same as Today's Reminders)
    }

    // Determine card title from items or fallback
    final titleText = prescription.items.isNotEmpty
        ? (prescription.items.first.strength.isNotEmpty
            ? '${prescription.items.first.medicationName} ${prescription.items.first.strength}'
            : prescription.items.first.medicationName)
        : (isScanned
            ? 'Scanned Prescription'
            : isManual
                ? 'Manual Prescription'
                : 'Doctor Prescription');

    final moreItemsCount = prescription.items.length - 1;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PrescriptionDetailPage(prescription: prescription),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              baseColor,
              baseColor.withValues(alpha: 0.4),
              const Color(0xFF101015),
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: baseColor.withValues(alpha: 0.25),
              blurRadius: 20,
              spreadRadius: -6,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Top Header Row ─────────────────────────────────────────
            Row(
              children: [
                // Compact icon pill
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.medication_liquid_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),

                // Medication Name / Title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              titleText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          if (moreItemsCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '+$moreItemsCount more',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (prescriberName != null && prescriberName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          isScanned || isManual ? prescriberName : 'Dr. $prescriberName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Status Badge
                StatusBadge(label: prescription.status.label, tone: _tone),

                const SizedBox(width: 4),

                // Delete Icon Button
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 19,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  tooltip: 'Delete prescription',
                  onPressed: () => _confirmDelete(context, ref),
                ),
              ],
            ),

            // ── Middle Medication Info (if items exist) ───────────────
            if (prescription.items.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Packaging, duration, frequency
                    Text(
                      '${prescription.items.first.packagingType.isNotEmpty ? prescription.items.first.packagingType[0].toUpperCase() + prescription.items.first.packagingType.substring(1) : 'Box'} · ${prescription.items.first.durationDays} days · ${prescription.items.first.frequency}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    if (prescription.items.first.instructions.isNotEmpty &&
                        prescription.items.first.instructions != 'As directed') ...[
                      const SizedBox(height: 3),
                      Text(
                        prescription.items.first.instructions,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),

            // ── Bottom Row: Date & Action ─────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isExpired ? Icons.event_busy : Icons.event_available,
                      size: 13,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isExpired
                          ? 'Expired ${DateFormatters.short(prescription.expiryDate)}'
                          : 'Valid until ${DateFormatters.short(prescription.expiryDate)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'Details',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
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
      ref.invalidate(patientPrescriptionsProvider);
      ref.read(prescriptionsRevisionProvider.notifier).state++;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prescription deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
