import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../models/imu_sample.dart';
import '../services/csv_export_service.dart';
import 'recording_screen.dart';

/// Home screen showing the list of completed trials and a button to start
/// the next trial (up to 3).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CsvExportService _exportService = CsvExportService();
  List<File> _csvFiles = [];
  List<File> _audioFiles = [];
  int _completedTrials = 0;

  static const int _maxTrials = 3;
  static const Duration _trialDuration = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _loadFiles();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final statuses = await [
      Permission.sensors,
      Permission.microphone,
      Permission.storage,
    ].request();

    // Inform the user if the microphone permission was denied so they know
    // the bonus audio feature will be unavailable.
    if (!mounted) return;
    final micStatus = statuses[Permission.microphone];
    if (micStatus != null && micStatus.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Microphone permission denied. '
            'Audio recording (bonus) will be disabled.',
          ),
        ),
      );
    }
  }

  Future<void> _loadFiles() async {
    final csvFiles = await _exportService.listCsvFiles();
    final audioFiles = await _exportService.listAudioFiles();
    setState(() {
      _csvFiles = csvFiles;
      _audioFiles = audioFiles;
      _completedTrials = csvFiles.length.clamp(0, _maxTrials);
    });
  }

  Future<void> _startNextTrial() async {
    final trialNumber = _completedTrials + 1;
    final result = await Navigator.push<RecordingResult>(
      context,
      MaterialPageRoute(
        builder: (_) => RecordingScreen(
          trialNumber: trialNumber,
          duration: _trialDuration,
        ),
      ),
    );
    if (result != null) {
      await _loadFiles();
    }
  }

  Future<void> _shareAll() async {
    final paths = [
      ..._csvFiles.map((f) => f.path),
      ..._audioFiles.map((f) => f.path),
    ];
    if (paths.isEmpty) return;
    await _exportService.shareFiles(paths);
  }

  Future<void> _deleteFile(File file) async {
    await file.delete();
    await _loadFiles();
  }

  String _basename(String path) => path.split('/').last;

  @override
  Widget build(BuildContext context) {
    final canRecord = _completedTrials < _maxTrials;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Monitor'),
        actions: [
          if (_csvFiles.isNotEmpty || _audioFiles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share all files',
              onPressed: _shareAll,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _TrialProgressCard(
            completedTrials: _completedTrials,
            maxTrials: _maxTrials,
          ),
          const SizedBox(height: 16),

          // Instructions card
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instructions',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Lie down or sit still.\n'
                    '2. Place the phone flat on your chest.\n'
                    '3. Press Start Trial and remain as still as possible.\n'
                    '4. Complete 3 × 5-minute trials.\n'
                    '5. Use Share All to export your data.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (canRecord)
            ElevatedButton.icon(
              onPressed: _startNextTrial,
              icon: const Icon(Icons.fiber_manual_record, color: Colors.red),
              label: Text('Start Trial ${_completedTrials + 1}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              ),
            )
          else
            const _AllDoneCard(),

          const SizedBox(height: 24),

          if (_csvFiles.isNotEmpty) ...[
            Text(
              'IMU Data Files',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            ..._csvFiles.map(
              (f) => _FileListTile(
                icon: Icons.table_chart,
                filename: _basename(f.path),
                onShare: () => Share.shareXFiles([XFile(f.path)]),
                onDelete: () => _deleteFile(f),
              ),
            ),
          ],

          if (_audioFiles.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Audio Files (Bonus)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            ..._audioFiles.map(
              (f) => _FileListTile(
                icon: Icons.audio_file,
                filename: _basename(f.path),
                onShare: () => Share.shareXFiles([XFile(f.path)]),
                onDelete: () => _deleteFile(f),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal widgets
// ---------------------------------------------------------------------------

class _TrialProgressCard extends StatelessWidget {
  final int completedTrials;
  final int maxTrials;

  const _TrialProgressCard({
    required this.completedTrials,
    required this.maxTrials,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '$completedTrials / $maxTrials Trials Completed',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(maxTrials, (i) {
                final done = i < completedTrials;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      Icon(
                        done ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: done
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                        size: 32,
                      ),
                      Text('Trial ${i + 1}',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllDoneCard extends StatelessWidget {
  const _AllDoneCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'All 3 trials complete! Use Share All to export your data.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileListTile extends StatelessWidget {
  final IconData icon;
  final String filename;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const _FileListTile({
    required this.icon,
    required this.filename,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(filename, style: const TextStyle(fontSize: 13)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.share, size: 20),
              onPressed: onShare,
              tooltip: 'Share',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: onDelete,
              tooltip: 'Delete',
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }
}
