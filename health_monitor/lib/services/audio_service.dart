import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

/// Wraps the `record` package to capture microphone audio as M4A/AAC.
class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  /// Requests microphone permission. Returns [true] if granted.
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Starts recording to [outputPath] (should end in `.m4a`).
  /// Returns [true] on success.
  Future<bool> startRecording(String outputPath) async {
    if (_isRecording) return false;

    final hasPermission = await requestPermission();
    if (!hasPermission) return false;

    final config = RecordConfig(
      encoder: AudioEncoder.aacLc,
      sampleRate: 44100,
      numChannels: 1, // mono is sufficient for breath/heart analysis
      bitRate: 128000,
    );

    await _recorder.start(config, path: outputPath);
    _isRecording = true;
    return true;
  }

  /// Stops recording and returns the path to the saved file,
  /// or [null] if recording was not active.
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    final path = await _recorder.stop();
    _isRecording = false;
    return path;
  }

  Future<void> dispose() async {
    if (_isRecording) await stopRecording();
    await _recorder.dispose();
  }
}
