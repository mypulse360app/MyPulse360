import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B2C19), Color(0xFF2E110A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Body Temperature Card',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Low', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
              Text('Normal', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
              Text('High', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          // Scale visualization
          SizedBox(
            height: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(21, (index) {
                // simple static indicator just like the mockup
                bool isNormalCenter = index == 10;
                bool isLowEdge = index == 0;
                bool isHighEdge = index == 20;
                bool isCurrent = hasData ? (temperature > 37.5 ? index == 16 : (temperature < 36.0 ? index == 4 : index == 10)) : index == 10;

                double height = isNormalCenter || isLowEdge || isHighEdge || isCurrent ? 16 : 8;
                Color color = isCurrent ? const Color(0xFFF28C38) : Colors.white.withValues(alpha: 0.2);

                return Container(
                  width: 2,
                  height: height,
                  color: color,
                );
              }),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MetricItem(
                label: 'Current Temp',
                value: hasData ? "$temperature" : '--',
                unit: '°C',
              ),
              _MetricItem(
                label: 'Status',
                value: hasData ? (temperature > 37.5 ? 'Fever' : 'Normal') : '--',
                unit: '',
              ),
              _MetricItem(
                label: 'Device',
                value: hasData ? device.split(' ').first : '--',
                unit: '',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _MetricItem({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w300,
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ]
          ],
        ),
      ],
    );
  }
}

