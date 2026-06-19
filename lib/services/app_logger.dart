import 'package:flutter_logs/flutter_logs.dart';

class AppLogger {
  static AppLogger get instance => AppLogger();

  AppLogger();

  static Future<void> log({
    required String providerName,
    required String screenName,
    required String functionName,
    required String action,
    String? additionalInfo,
  }) async {
    final buffer = StringBuffer();
    buffer.write('Provider: $providerName | ');
    buffer.write('Screen: $screenName | ');
    buffer.write('Function: $functionName | ');
    buffer.write('Action: $action');
    if (additionalInfo != null && additionalInfo.isNotEmpty) {
      buffer.write(' | Details: $additionalInfo');
    }

    await FlutterLogs.logInfo("AppLog", action, buffer.toString());
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
    final buffer = StringBuffer();
    buffer.write('Provider: $providerName | ');
    buffer.write('Screen: $screenName | ');
    buffer.write('Function: $functionName | ');
    buffer.write('Action: $action | ');
    buffer.write('ERROR: $errorMessage');

    if (stackTrace != null && stackTrace.isNotEmpty) {
      await FlutterLogs.logErrorTrace(
        "AppLog",
        "error",
        "$buffer\nStackTrace: $stackTrace",
        Error(),
      );
    } else {
      await FlutterLogs.logError("AppLog", "error", buffer.toString());
    }
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

  static Future<String> getLogDirectory() async {
    return "DeliveryNoteLogs";
  }

  static Future<void> exportLogs() async {
    await FlutterLogs.exportLogs(exportType: ExportType.ALL);
  }

  static Future<void> clearLogs() async {
    await FlutterLogs.clearLogs();
  }

  static Future<String?> printLogs() async {
    await FlutterLogs.printLogs(exportType: ExportType.ALL);
    return null;
  }
}
