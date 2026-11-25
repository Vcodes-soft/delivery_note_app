import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

/// Writes structured activity logs to a plain-text file keyed purely by the
/// calendar date. Every call independently opens the file in append mode,
/// writes one line, and closes it again - there is no persistent session or
/// handle carried across app restarts, so a relaunch can never lose track of
/// the current day's file (the bug that the old `flutter_logs`-based
/// implementation had).
class AppLogger {
  static const String _logsDirName = 'Logs';
  static final DateFormat _fileDateFormat = DateFormat('ddMMyyyy');
  static final DateFormat _timestampFormat = DateFormat('dd-MM-yyyy hh:mm:ss a');

  static Future<void> _writeQueue = Future.value();

  static Future<Directory> logsDirectory() async {
    final baseDir = await getExternalStorageDirectory();
    final dir = Directory('${baseDir!.path}/$_logsDirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static String fileNameForDate(DateTime date) =>
      '${_fileDateFormat.format(date)}.log';

  static Future<void> _appendLine(String line) async {
    final dir = await logsDirectory();
    final file = File('${dir.path}/${fileNameForDate(DateTime.now())}');
    await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
  }

  static Future<void> _enqueueWrite(String line) {
    _writeQueue = _writeQueue.then((_) => _appendLine(line));
    return _writeQueue;
  }

  static String _buildLine({
    required String level,
    required String providerName,
    required String screenName,
    required String functionName,
    required String action,
    String? details,
  }) {
    final timestamp = _timestampFormat.format(DateTime.now());
    final fields = [
      timestamp,
      level,
      providerName,
      screenName,
      functionName,
      action,
      details ?? '',
    ];
    return fields.join('\t');
  }

  static Future<void> log({
    required String providerName,
    required String screenName,
    required String functionName,
    required String action,
    String? additionalInfo,
  }) async {
    final line = _buildLine(
      level: 'INFO',
      providerName: providerName,
      screenName: screenName,
      functionName: functionName,
      action: action,
      details: additionalInfo,
    );
    await _enqueueWrite(line);
  }

  Future<void> logInfo({
    required String providerName,
    required String screenName,
    required String functionName,
    required String action,
    String? additionalInfo,
  }) async {
    await AppLogger.log(
      providerName: providerName,
      screenName: screenName,
      functionName: functionName,
      action: action,
      additionalInfo: additionalInfo,
    );
  }

  static Future<void> logError({
    required String providerName,
    required String screenName,
    required String functionName,
    required String action,
    required String errorMessage,
    String? stackTrace,
  }) async {
    final details = stackTrace != null && stackTrace.isNotEmpty
        ? 'ERROR: $errorMessage | StackTrace: $stackTrace'
        : 'ERROR: $errorMessage';
    final line = _buildLine(
      level: 'ERROR',
      providerName: providerName,
      screenName: screenName,
      functionName: functionName,
      action: action,
      details: details,
    );
    await _enqueueWrite(line);
  }

  Future<void> logErrorInstance({
    required String providerName,
    required String screenName,
    required String functionName,
    required String action,
    required String errorMessage,
    String? stackTrace,
  }) async {
    await AppLogger.logError(
      providerName: providerName,
      screenName: screenName,
      functionName: functionName,
      action: action,
      errorMessage: errorMessage,
      stackTrace: stackTrace,
    );
  }
}
