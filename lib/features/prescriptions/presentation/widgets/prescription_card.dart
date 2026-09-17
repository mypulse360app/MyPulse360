import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/presentation/widgets/status_badge.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/prescription.dart';

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
    final prescriberName = isScanned
        ? (prescription.externalDoctorName ?? 'Unknown prescriber')
        : ref.watch(userProfileProvider(prescription.doctorId)).valueOrNull?.fullName;

    final isExpired = prescription.status == PrescriptionStatus.expired;
    final isExpiring = prescription.status == PrescriptionStatus.expiring;
    
    // Choose a vibrant background color based on status
    final Color baseColor;
    if (isExpired) {
      baseColor = const Color(0xFF4A4A52); // Muted dark grey/purple
    } else if (isExpiring) {
      baseColor = const Color(0xFFE88A1A); // Vibrant orange
    } else {
      baseColor = const Color(0xFF0F7A4A); // Vibrant green
    }

    return GestureDetector(
      onTap: () {
        // Future: view details
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 2.0,
            colors: [
              baseColor,
              baseColor.withValues(alpha: 0.6),
              const Color(0xFF101015),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: baseColor.withValues(alpha: 0.2),
              blurRadius: 24,
              spreadRadius: -8,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.medication_liquid_rounded, size: 22, color: Colors.white),
                ),
                Row(
                  children: [
                    if (isScanned) ...[
                      const StatusBadge(label: 'Scanned', tone: StatusTone.neutral),
                      const SizedBox(width: 6),
                    ],
                    StatusBadge(label: prescription.status.label, tone: _tone),
                  ],
                ),
              ],
            ),
            if (prescriberName != null) ...[
              const SizedBox(height: 16),
              Text(
                isScanned ? prescriberName : 'Prescribed by $prescriberName',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9)),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  for (final item in prescription.items) 
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(color: Colors.white, fontSize: 16)),
                          Expanded(
                            child: Text(
                              '${item.medicationName} ${item.strength} ${item.form}\n${item.frequency}',
                              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  isExpired ? Icons.event_busy : Icons.event_available,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Text(
                  isExpired
                      ? 'Expired ${prescription.expiryDate.toLocal().toString().split(' ').first}'
                      : 'Valid until ${prescription.expiryDate.toLocal().toString().split(' ').first}',
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
