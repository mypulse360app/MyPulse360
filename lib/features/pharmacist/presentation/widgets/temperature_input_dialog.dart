import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/router/route_paths.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/presentation/providers/appointments_providers.dart';
import '../providers/pharmacist_providers.dart';

class TemperatureInputDialog extends ConsumerStatefulWidget {
  const TemperatureInputDialog({
    super.key,
    required this.appointment,
    required this.patientName,
  });

  final Appointment appointment;
  final String patientName;

  @override
  ConsumerState<TemperatureInputDialog> createState() => _TemperatureInputDialogState();
}

class _TemperatureInputDialogState extends ConsumerState<TemperatureInputDialog> {
  final _tempController = TextEditingController();
  bool _saving = false;
  late final DateTime _openedAt;
  Map<String, dynamic>? _detectedScan;

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
  }

  @override
  void dispose() {
    _tempController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final tempStr = _tempController.text.trim();
    if (tempStr.isEmpty) return;

    final temp = double.tryParse(tempStr);
    if (temp == null) return;

    setState(() => _saving = true);
    
    final consultationId = await ref.read(pharmacistRepositoryProvider).logTemperature(
      widget.appointment.id,
      widget.appointment.patientId,
      widget.appointment.doctorId,
      temp,
    );
    
    ref.read(appointmentsRevisionProvider.notifier).state++;
    
    if (!mounted) return;
    Navigator.of(context).pop();
    
    // Navigate to Process Prescription after logging vitals
    if (consultationId.isNotEmpty) {
      context.push(RoutePaths.processPrescription(consultationId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    
    return AlertDialog(
      title: Text('Log Vitals for ${widget.patientName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Scan the patient\'s temperature using the clinic scanner. The reading will appear below automatically in real-time.'),
          const SizedBox(height: 16),
          Consumer(
            builder: (context, ref, child) {
              final tempScan = ref.watch(latestTemperatureLogProvider).valueOrNull;
              
              // Accept scans from the last 2 minutes or any new scan after dialog opened
              if (tempScan != null) {
                final scanTime = tempScan['created_at'] as DateTime?;
                final cutoff = _openedAt.subtract(const Duration(minutes: 2));
                if (scanTime != null && scanTime.isAfter(cutoff)) {
                  // Recent scan detected — always update
                  if (_detectedScan == null || _detectedScan!['created_at'] != scanTime) {
                    _detectedScan = tempScan;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _tempController.text = tempScan['temperature'].toString();
                      }
                    });
                  }
                }
              }
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_detectedScan != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: colors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.success),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: colors.success, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Scanner detected: ${_detectedScan!['temperature']} °C from ${_detectedScan!['device']}',
                              style: TextStyle(color: colors.success, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: colors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.warning),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.sensors, color: colors.warning, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Waiting for scanner input...',
                              style: TextStyle(color: colors.warning, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  TextField(
                    controller: _tempController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Temperature (°C)',
                      hintText: 'e.g. 37.5',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        PrimaryButton(
          label: 'Save',
          fullWidth: false,
          color: colors.clinicianAccent,
          onPressed: _saving ? () {} : _submit,
          loading: _saving,
        ),
      ],
    );
  }
}
