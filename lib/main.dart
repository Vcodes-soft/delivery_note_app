import 'package:delivery_note_app/helpers/mssqldb_helper.dart';
import 'package:delivery_note_app/providers/auth_provider.dart';
import 'package:delivery_note_app/providers/order_provider.dart';
import 'package:delivery_note_app/providers/theme_provider.dart';
import 'package:delivery_note_app/routes.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() async{
  await WidgetsFlutterBinding.ensureInitialized();
  final mssqlHelper = MSSQLHelper();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
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