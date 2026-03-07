import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/imu_sample.dart';

/// Collects accelerometer and gyroscope readings at ~100 Hz.
class SensorService {
  final List<ImuSample> _samples = [];

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  // Latest raw readings – kept in sync so each sample row has both.
  AccelerometerEvent? _lastAccel;
  GyroscopeEvent? _lastGyro;

  DateTime? _recordingStart;

  bool get isRecording => _accelSub != null;

  List<ImuSample> get samples => List.unmodifiable(_samples);

  /// Starts collecting sensor data. Clears any previously collected samples.
  void startRecording() {
    _samples.clear();
    _recordingStart = DateTime.now();

    // Subscribe to accelerometer
    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval, // ~100 Hz
    ).listen((event) {
      _lastAccel = event;
      _tryAddSample();
    });

    // Subscribe to gyroscope
    _gyroSub = gyroscopeEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen((event) {
      _lastGyro = event;
      _tryAddSample();
    });
  }

  void _tryAddSample() {
    final accel = _lastAccel;
    final gyro = _lastGyro;
    if (accel == null || gyro == null) return;

    final elapsed = DateTime.now()
        .difference(_recordingStart!)
        .inMicroseconds /
        1000.0; // milliseconds

    _samples.add(ImuSample(
      timestampMs: elapsed,
      accX: accel.x,
      accY: accel.y,
      accZ: accel.z,
      gyroX: gyro.x,
      gyroY: gyro.y,
      gyroZ: gyro.z,
    ));

    // Reset so the next sample requires fresh data from both sensors
    _lastAccel = null;
    _lastGyro = null;
  }

  /// Stops recording and returns the collected samples.
  List<ImuSample> stopRecording() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _accelSub = null;
    _gyroSub = null;
    _lastAccel = null;
    _lastGyro = null;
    return List.unmodifiable(_samples);
  }

  void dispose() {
    stopRecording();
  }
}
