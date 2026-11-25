import 'package:delivery_note_app/helpers/mssqldb_helper.dart';
import 'package:delivery_note_app/providers/auth_provider.dart';
import 'package:delivery_note_app/providers/order_provider.dart';
import 'package:delivery_note_app/providers/theme_provider.dart';
import 'package:delivery_note_app/routes.dart';
import 'package:delivery_note_app/services/app_logger.dart';
import 'package:delivery_note_app/utils/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/purchase_order_provider.dart';
import 'providers/serial_search_provider.dart';

void main() async {
  await WidgetsFlutterBinding.ensureInitialized();

  // Log app startup
  await AppLogger.log(
    providerName: 'main',
    screenName: 'main',
    functionName: 'main',
    action: 'Application started',
  );

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
