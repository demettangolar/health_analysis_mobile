import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/imu_sample.dart';
import '../services/sensor_service.dart';
import '../services/audio_service.dart';
import '../services/csv_export_service.dart';
import '../widgets/timer_widget.dart';
import '../widgets/sensor_display.dart';

/// Result returned to [HomeScreen] after a trial finishes.
class RecordingResult {
  final String csvPath;
  final String? audioPath;
  final int sampleCount;

  const RecordingResult({
    required this.csvPath,
    this.audioPath,
    required this.sampleCount,
  });
}

/// Full-screen recording UI for a single 5-minute trial.
class RecordingScreen extends StatefulWidget {
  final int trialNumber;
  final Duration duration;

  const RecordingScreen({
    super.key,
    required this.trialNumber,
    required this.duration,
  });

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

enum _ScreenState { ready, countdown, recording, saving, done, error }

class _RecordingScreenState extends State<RecordingScreen> {
  final SensorService _sensorService = SensorService();
  final AudioService _audioService = AudioService();
  final CsvExportService _exportService = CsvExportService();

  _ScreenState _state = _ScreenState.ready;
  String? _statusMessage;
  ImuSample? _latestSample;
  int _sampleCount = 0;
  RecordingResult? _result;
  bool _recordAudio = true;

  Timer? _sampleUpdateTimer;

  // 3-second countdown before the actual 5-minute recording
  static const Duration _countdownDuration = Duration(seconds: 3);

  @override
  void dispose() {
    _sensorService.dispose();
    _audioService.dispose();
    _sampleUpdateTimer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Recording flow
  // ---------------------------------------------------------------------------

  Future<void> _beginCountdown() async {
    setState(() => _state = _ScreenState.countdown);
    await Future.delayed(_countdownDuration);
    if (!mounted) return;
    _startRecording();
  }

  Future<void> _startRecording() async {
    setState(() => _state = _ScreenState.recording);
    WakelockPlus.enable();

    // Start sensors
    _sensorService.startRecording();

    // Start audio (bonus – silently skip if permission denied)
    if (_recordAudio) {
      final audioPath =
          await _exportService.audioFilePath(widget.trialNumber);
      final started = await _audioService.startRecording(audioPath);
      if (!started) setState(() => _recordAudio = false);
    }

    // UI update timer – refresh sensor display ~10 Hz
    _sampleUpdateTimer =
        Timer.periodic(const Duration(milliseconds: 100), (_) {
      final samples = _sensorService.samples;
      if (samples.isEmpty) return;
      setState(() {
        _latestSample = samples.last;
        _sampleCount = samples.length;
      });
    });
  }

  Future<void> _finishRecording() async {
    _sampleUpdateTimer?.cancel();
    WakelockPlus.disable();

    setState(() {
      _state = _ScreenState.saving;
      _statusMessage = 'Saving data…';
    });

    // Stop sensors
    final samples = _sensorService.stopRecording();

    // Stop audio
    final audioPath = await _audioService.stopRecording();

    try {
      final csvPath =
          await _exportService.writeCsv(widget.trialNumber, samples);

      _result = RecordingResult(
        csvPath: csvPath,
        audioPath: audioPath,
        sampleCount: samples.length,
      );

      setState(() => _state = _ScreenState.done);
    } catch (e) {
      setState(() {
        _state = _ScreenState.error;
        _statusMessage = 'Error saving data: $e';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _state == _ScreenState.ready ||
          _state == _ScreenState.done ||
          _state == _ScreenState.error,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Trial ${widget.trialNumber}'),
          leading: (_state == _ScreenState.ready ||
                  _state == _ScreenState.done ||
                  _state == _ScreenState.error)
              ? const BackButton()
              : const SizedBox.shrink(),
        ),
        body: SafeArea(
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return switch (_state) {
      _ScreenState.ready => _ReadyView(
          trialNumber: widget.trialNumber,
          duration: widget.duration,
          recordAudio: _recordAudio,
          onToggleAudio: (v) => setState(() => _recordAudio = v),
          onStart: _beginCountdown,
        ),
      _ScreenState.countdown => _CountdownView(
          seconds: _countdownDuration.inSeconds,
        ),
      _ScreenState.recording => _RecordingView(
          duration: widget.duration,
          latestSample: _latestSample,
          sampleCount: _sampleCount,
          audioEnabled: _recordAudio,
          onTimerFinished: _finishRecording,
        ),
      _ScreenState.saving => _SavingView(message: _statusMessage ?? 'Saving…'),
      _ScreenState.done => _DoneView(
          result: _result!,
          onFinish: () => Navigator.pop(context, _result),
        ),
      _ScreenState.error => _ErrorView(
          message: _statusMessage ?? 'Unknown error',
          onBack: () => Navigator.pop(context),
        ),
    };
  }
}

// ---------------------------------------------------------------------------
// Sub-views
// ---------------------------------------------------------------------------

class _ReadyView extends StatelessWidget {
  final int trialNumber;
  final Duration duration;
  final bool recordAudio;
  final ValueChanged<bool> onToggleAudio;
  final VoidCallback onStart;

  const _ReadyView({
    required this.trialNumber,
    required this.duration,
    required this.recordAudio,
    required this.onToggleAudio,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sensors,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Ready to Record',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Trial $trialNumber — ${duration.inMinutes} minutes',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Before you start:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Lie down or sit still.\n'
                    '• Place the phone flat on your chest.\n'
                    '• Minimise movement for the full 5 minutes.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Record Microphone (Bonus)'),
            subtitle: const Text('Saves an M4A audio file alongside the CSV'),
            value: recordAudio,
            onChanged: onToggleAudio,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.fiber_manual_record, color: Colors.red),
              label: const Text('Start Recording'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownView extends StatefulWidget {
  final int seconds;
  const _CountdownView({required this.seconds});

  @override
  State<_CountdownView> createState() => _CountdownViewState();
}

class _CountdownViewState extends State<_CountdownView> {
  late int _count;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _count = widget.seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_count <= 1) {
        t.cancel();
      } else {
        setState(() => _count--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Get Ready',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),
          Text(
            '$_count',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 16),
          const Text('Place phone flat on your chest now'),
        ],
      ),
    );
  }
}

class _RecordingView extends StatelessWidget {
  final Duration duration;
  final ImuSample? latestSample;
  final int sampleCount;
  final bool audioEnabled;
  final VoidCallback onTimerFinished;

  const _RecordingView({
    required this.duration,
    required this.latestSample,
    required this.sampleCount,
    required this.audioEnabled,
    required this.onTimerFinished,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
              const SizedBox(width: 6),
              Text(
                'Recording',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (audioEnabled) ...[
                const SizedBox(width: 12),
                const Icon(Icons.mic, color: Colors.red, size: 14),
                const SizedBox(width: 4),
                const Text('Audio', style: TextStyle(color: Colors.red)),
              ],
            ],
          ),
          const SizedBox(height: 24),
          TimerWidget(
            duration: duration,
            onFinished: onTimerFinished,
          ),
          const SizedBox(height: 24),
          SensorDisplay(
            latestSample: latestSample,
            sampleCount: sampleCount,
          ),
          const Spacer(),
          const Text(
            'Keep still. Recording will stop automatically.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SavingView extends StatelessWidget {
  final String message;
  const _SavingView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(message, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _DoneView extends StatelessWidget {
  final RecordingResult result;
  final VoidCallback onFinish;

  const _DoneView({required this.result, required this.onFinish});

  String _basename(String path) => path.split('/').last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 80),
          const SizedBox(height: 16),
          Text(
            'Trial Complete!',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    label: 'IMU samples',
                    value: result.sampleCount.toString(),
                  ),
                  _InfoRow(
                    label: 'CSV file',
                    value: _basename(result.csvPath),
                  ),
                  if (result.audioPath != null)
                    _InfoRow(
                      label: 'Audio file',
                      value: _basename(result.audioPath!),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onFinish,
              child: const Text('Back to Home'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onBack;

  const _ErrorView({required this.message, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: onBack,
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
