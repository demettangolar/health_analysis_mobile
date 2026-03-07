import 'package:flutter/material.dart';
import '../models/imu_sample.dart';

/// Shows the latest accelerometer and gyroscope readings in a card.
class SensorDisplay extends StatelessWidget {
  final ImuSample? latestSample;
  final int sampleCount;

  const SensorDisplay({
    super.key,
    required this.latestSample,
    required this.sampleCount,
  });

  @override
  Widget build(BuildContext context) {
    final sample = latestSample;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Live IMU Readings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Chip(
                  label: Text('$sampleCount samples'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                ),
              ],
            ),
            const Divider(),
            if (sample == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Waiting for sensor data…',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else ...[
              _SensorRow(
                label: 'Accel X',
                value: sample.accX,
                unit: 'm/s²',
                color: Colors.red.shade400,
              ),
              _SensorRow(
                label: 'Accel Y',
                value: sample.accY,
                unit: 'm/s²',
                color: Colors.green.shade400,
              ),
              _SensorRow(
                label: 'Accel Z',
                value: sample.accZ,
                unit: 'm/s²',
                color: Colors.blue.shade400,
              ),
              const SizedBox(height: 8),
              _SensorRow(
                label: 'Gyro X',
                value: sample.gyroX,
                unit: 'rad/s',
                color: Colors.red.shade200,
              ),
              _SensorRow(
                label: 'Gyro Y',
                value: sample.gyroY,
                unit: 'rad/s',
                color: Colors.green.shade200,
              ),
              _SensorRow(
                label: 'Gyro Z',
                value: sample.gyroZ,
                unit: 'rad/s',
                color: Colors.blue.shade200,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SensorRow extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final Color color;

  const _SensorRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value.toStringAsFixed(4),
              textAlign: TextAlign.right,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 40,
            child: Text(
              unit,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
