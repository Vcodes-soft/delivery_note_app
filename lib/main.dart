import 'package:delivery_note_app/helpers/mssqldb_helper.dart';
import 'package:delivery_note_app/providers/auth_provider.dart';
import 'package:delivery_note_app/providers/order_provider.dart';
import 'package:delivery_note_app/providers/theme_provider.dart';
import 'package:delivery_note_app/routes.dart';
import 'package:delivery_note_app/utils/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:provider/provider.dart';

import 'providers/purchase_order_provider.dart';
import 'providers/serial_search_provider.dart';

String logsDirectoryPath = '';

void main() async {
  await WidgetsFlutterBinding.ensureInitialized();

  // Initialize Flutter Logs with default storage
  logsDirectoryPath = await FlutterLogs.initLogs(
    logLevelsEnabled: [
      LogLevel.INFO,
      LogLevel.WARNING,
      LogLevel.ERROR,
      LogLevel.SEVERE
    ],
    timeStampFormat: TimeStampFormat.TIME_FORMAT_READABLE,
    directoryStructure: DirectoryStructure.SINGLE_FILE_FOR_DAY,
    logTypesEnabled: ["app_actions", "scanning", "errors"],
    logFileExtension: LogFileExtension.LOG,
    logsWriteDirectoryName: "Logs",
    logsExportDirectoryName: "Logs/Exported",
    debugFileOperations: true,
    isDebuggable: true,
    logsRetentionPeriodInDays: 14,
    zipsRetentionPeriodInDays: 3,
    autoDeleteZipOnExport: false,
    autoClearLogs: true,
    enabled: true,
  );

  debugPrint('Logs directory: $logsDirectoryPath');

  // Log app startup
  FlutterLogs.logInfo("DeliveryNoteApp", "main", "Application started");

  // Load scanning mode preference
  await AppConstants.loadScanningMode();
  final mssqlHelper = MSSQLHelper();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => PurchaseOrderProvider()),
        ChangeNotifierProvider(create: (_) => SerialSearchProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Delivery Note',
      theme: themeProvider.currentTheme,
      initialRoute: '/',
      onGenerateRoute: RouteGenerator.generateRoute,
      debugShowCheckedModeBanner: false,
    );
  }
}
