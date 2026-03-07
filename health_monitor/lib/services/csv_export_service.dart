import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/imu_sample.dart';

/// Handles writing IMU data to CSV files and sharing them.
class CsvExportService {
  static final DateFormat _fmt = DateFormat('yyyyMMdd_HHmmss');

  /// Returns the app's documents directory path.
  Future<String> get _docsDir async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  /// Builds a file path like:
  ///   <docs>/imu_trial_1_20240315_143022.csv
  Future<String> imuFilePath(int trialNumber) async {
    final base = await _docsDir;
    final stamp = _fmt.format(DateTime.now());
    return '$base/imu_trial_${trialNumber}_$stamp.csv';
  }

  /// Builds a file path like:
  ///   <docs>/audio_trial_1_20240315_143022.m4a
  Future<String> audioFilePath(int trialNumber) async {
    final base = await _docsDir;
    final stamp = _fmt.format(DateTime.now());
    return '$base/audio_trial_${trialNumber}_$stamp.m4a';
  }

  /// Writes [samples] to a new CSV file and returns the file path.
  Future<String> writeCsv(int trialNumber, List<ImuSample> samples) async {
    final path = await imuFilePath(trialNumber);
    final file = File(path);

    final buffer = StringBuffer();
    buffer.writeln(ImuSample.csvHeader);
    for (final s in samples) {
      buffer.writeln(s.toCsvRow());
    }

    await file.writeAsString(buffer.toString());
    return path;
  }

  /// Opens the system share sheet for a list of file paths.
  Future<void> shareFiles(List<String> paths) async {
    final xFiles = paths.map((p) => XFile(p)).toList();
    await Share.shareXFiles(xFiles, text: 'Health Monitor – Recording Data');
  }

  /// Lists all previously saved IMU CSV files in the docs directory.
  Future<List<File>> listCsvFiles() async {
    final base = await _docsDir;
    final dir = Directory(base);
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.csv'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path)); // newest first
  }

  /// Lists all previously saved audio files.
  Future<List<File>> listAudioFiles() async {
    final base = await _docsDir;
    final dir = Directory(base);
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.m4a'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
  }
}
