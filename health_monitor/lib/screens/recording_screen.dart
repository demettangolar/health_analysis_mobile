import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/sensor_service.dart';
import '../services/audio_service.dart';
import '../services/csv_export_service.dart';
import '../widgets/timer_widget.dart';

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

enum _ScreenState { recording, saving, done, error }

class _RecordingScreenState extends State<RecordingScreen> {
  final SensorService _sensorService = SensorService();
  final AudioService _audioService = AudioService();
  final CsvExportService _exportService = CsvExportService();

  _ScreenState _state = _ScreenState.recording;
  String? _statusMessage;
  RecordingResult? _result;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  @override
  void dispose() {
    _sensorService.dispose();
    _audioService.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Recording flow
  // ---------------------------------------------------------------------------

  Future<void> _startRecording() async {
    WakelockPlus.enable();

    // Start sensors
    _sensorService.startRecording();

    // Always record audio (silently skip if permission denied)
    final audioPath = await _exportService.audioFilePath(widget.trialNumber);
    await _audioService.startRecording(audioPath);
  }

  Future<void> _finishRecording() async {
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
      canPop: _state == _ScreenState.done ||
          _state == _ScreenState.error,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Trial ${widget.trialNumber}'),
          leading: (_state == _ScreenState.done ||
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
      _ScreenState.recording => _RecordingView(
          duration: widget.duration,
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

class _RecordingView extends StatelessWidget {
  final Duration duration;
  final VoidCallback onTimerFinished;

  const _RecordingView({
    required this.duration,
    required this.onTimerFinished,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
            ],
          ),
          const SizedBox(height: 32),
          TimerWidget(
            duration: duration,
            onFinished: onTimerFinished,
          ),
          const SizedBox(height: 32),
          const Text(
            'Keep still. Recording will stop automatically.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
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
