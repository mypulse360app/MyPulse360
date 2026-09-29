import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/empty_state_view.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/prescription.dart';
import '../providers/prescriptions_providers.dart';
import '../widgets/prescription_card.dart';
import 'add_prescription_manually_page.dart';
import 'scan_prescription_page.dart';

enum _PrescriptionFilter { all, doctor, self }

/// P7 — Prescriptions: shows both doctor-prescribed medications and
/// patient's scanned/manually entered medications with convenient filtering.
class PrescriptionsListPage extends ConsumerStatefulWidget {
  const PrescriptionsListPage({super.key});

  @override
  ConsumerState<PrescriptionsListPage> createState() => _PrescriptionsListPageState();
}

class _PrescriptionsListPageState extends ConsumerState<PrescriptionsListPage> {
  _PrescriptionFilter _filter = _PrescriptionFilter.all;

  void _scan(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ScanPrescriptionPage()),
    );
  }

  void _addManually(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddPrescriptionManuallyPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final allPrescriptions = ref.watch(patientPrescriptionsProvider(user.id));
    final colors = context.colors;

    final doctorPrescriptions = allPrescriptions
        .where((p) => p.source == PrescriptionSource.inApp)
        .toList();
    final selfPrescriptions = allPrescriptions
        .where((p) =>
            p.source == PrescriptionSource.scannedExternal ||
            p.source == PrescriptionSource.manualExternal)
        .toList();

    final displayedPrescriptions = switch (_filter) {
      _PrescriptionFilter.all => allPrescriptions,
      _PrescriptionFilter.doctor => doctorPrescriptions,
      _PrescriptionFilter.self => selfPrescriptions,
    };

    return Scaffold(
      appBar: LargeTitleAppBar(
        title: 'Prescriptions',
        showBack: false,
        actions: [
          IconButton(
            onPressed: () => _addManually(context),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add prescription manually',
          ),
          IconButton(
            onPressed: () => _scan(context),
            icon: const Icon(Icons.document_scanner_rounded),
            tooltip: 'Scan prescription (OCR)',
          ),
        ],
      ),
      body: allPrescriptions.isEmpty
          ? EmptyStateView(
              title: 'No prescriptions yet',
              message:
                  'Prescriptions from your doctor will show up here — or scan/add a prescription manually.',
              icon: Icons.medication_outlined,
              actionLabel: 'Scan Prescription',
              onAction: () => _scan(context),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Filter Chips ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip(
                          label: 'All (${allPrescriptions.length})',
                          selected: _filter == _PrescriptionFilter.all,
                          onSelected: () => setState(() => _filter = _PrescriptionFilter.all),
                          colors: colors,
                        ),
                        const SizedBox(width: 8),
                        _filterChip(
                          label: 'Doctor Prescribed (${doctorPrescriptions.length})',
                          selected: _filter == _PrescriptionFilter.doctor,
                          onSelected: () => setState(() => _filter = _PrescriptionFilter.doctor),
                          colors: colors,
                        ),
                        const SizedBox(width: 8),
                        _filterChip(
                          label: 'My Scanned & Manual (${selfPrescriptions.length})',
                          selected: _filter == _PrescriptionFilter.self,
                          onSelected: () => setState(() => _filter = _PrescriptionFilter.self),
                          colors: colors,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // ── Prescriptions List ────────────────────────────────
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(patientPrescriptionsProvider);
                      ref.read(prescriptionsRevisionProvider.notifier).state++;
                      await Future.delayed(const Duration(milliseconds: 300));
                    },
                    child: displayedPrescriptions.isEmpty
                        ? LayoutBuilder(
                            builder: (context, constraints) => SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.medication_outlined, size: 40, color: colors.textTertiary),
                                        const SizedBox(height: 10),
                                        Text(
                                          _filter == _PrescriptionFilter.doctor
                                              ? 'No doctor prescriptions yet'
                                              : 'No scanned or manual prescriptions yet',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: displayedPrescriptions.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, i) =>
                                PrescriptionCard(prescription: displayedPrescriptions[i]),
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
    required AppSemanticColors colors,
  }) {
    return FilterChip(
      selected: selected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
        color: selected ? Colors.white : colors.textPrimary,
      ),
      backgroundColor: colors.surfaceSubtle,
      selectedColor: colors.patientAccent,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? colors.patientAccent : colors.border,
        ),
      ),
      onSelected: (_) => onSelected(),
    );
  }
}
