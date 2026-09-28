import 'package:flutter/material.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/app_card.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../../shared/presentation/widgets/status_badge.dart';

class BodyTemperatureCard extends StatelessWidget {
  final double temperature;
  final String device;
  final bool hasData;

  const BodyTemperatureCard({
    super.key,
    required this.temperature,
    required this.device,
    this.hasData = true,
  });

  StatusTone get _tone {
    if (!hasData) return StatusTone.neutral;
    if (temperature > 37.5) return StatusTone.danger;
    if (temperature < 36.0) return StatusTone.warning;
    return StatusTone.success;
  }

  String get _statusLabel {
    if (!hasData) return 'No Data';
    if (temperature > 37.5) return 'Fever';
    if (temperature < 36.0) return 'Low';
    return 'Normal';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      child: Row(
        children: [
          AvatarWidget(name: 'Temperature', color: const Color(0xFFF28C38)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Body Temperature', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  hasData ? '$temperature °C' : '-- °C',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Device: ${hasData ? device.split(' ').first : '--'}',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          StatusBadge(label: _statusLabel, tone: _tone),
        ],
      ),
    );
  }
}


