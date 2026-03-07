/// Model representing a single row of IMU data.
class ImuSample {
  final double timestampMs;

  // Accelerometer (m/s²)
  final double accX;
  final double accY;
  final double accZ;

  // Gyroscope (rad/s)
  final double gyroX;
  final double gyroY;
  final double gyroZ;

  const ImuSample({
    required this.timestampMs,
    required this.accX,
    required this.accY,
    required this.accZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
  });

  /// CSV header line.
  static String get csvHeader =>
      'timestamp_ms,acc_x,acc_y,acc_z,gyro_x,gyro_y,gyro_z';

  /// Serialises the sample to a CSV row (no trailing newline).
  String toCsvRow() =>
      '${timestampMs.toStringAsFixed(3)},'
      '${accX.toStringAsFixed(6)},'
      '${accY.toStringAsFixed(6)},'
      '${accZ.toStringAsFixed(6)},'
      '${gyroX.toStringAsFixed(6)},'
      '${gyroY.toStringAsFixed(6)},'
      '${gyroZ.toStringAsFixed(6)}';
}

/// Metadata about a completed recording trial.
class RecordingTrial {
  final int trialNumber;
  final DateTime startTime;
  final DateTime endTime;
  final String csvFilePath;
  final String? audioFilePath;
  final int sampleCount;

  const RecordingTrial({
    required this.trialNumber,
    required this.startTime,
    required this.endTime,
    required this.csvFilePath,
    this.audioFilePath,
    required this.sampleCount,
  });

  Duration get duration => endTime.difference(startTime);
}
