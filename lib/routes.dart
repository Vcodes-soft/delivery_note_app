// lib/routes.dart
import 'package:delivery_note_app/screens/auth_screen.dart';
import 'package:delivery_note_app/screens/dashboard_screen.dart';
import 'package:delivery_note_app/screens/purchase_order/purchase_order.dart';
import 'package:delivery_note_app/screens/purchase_order/purchase_order_detail.dart';
import 'package:delivery_note_app/screens/sales_order/sales_order.dart';
import 'package:delivery_note_app/screens/sales_order/sales_order_detail.dart';
import 'package:delivery_note_app/screens/add_lot_screen.dart';
import 'package:delivery_note_app/screens/server_configuration.dart';
import 'package:delivery_note_app/screens/log_list_screen.dart';
import 'package:delivery_note_app/screens/serial_search/serial_search_screen.dart';
import 'package:delivery_note_app/services/app_logger.dart';
import 'package:flutter/material.dart';

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        AppLogger.log(
          providerName: 'RouteGenerator',
          screenName: 'ServerConfigScreen',
          functionName: 'generateRoute',
          action: 'Navigated to Server Configuration',
        );
        return MaterialPageRoute(builder: (_) => const ServerConfigScreen());
      case '/auth':
        AppLogger.log(
          providerName: 'RouteGenerator',
          screenName: 'AuthScreen',
          functionName: 'generateRoute',
          action: 'Navigated to Auth Screen',
        );
        return MaterialPageRoute(builder: (_) => const AuthScreen());
      case '/dashboard':
        AppLogger.log(
          providerName: 'RouteGenerator',
          screenName: 'DashboardScreen',
          functionName: 'generateRoute',
          action: 'Navigated to Dashboard',
        );
        return MaterialPageRoute(builder: (_) => const DashboardScreen());
      case '/sales-orders':
        AppLogger.log(
          providerName: 'RouteGenerator',
          screenName: 'SalesOrdersScreen',
          functionName: 'generateRoute',
          action: 'Navigated to Sales Orders List',
        );
        return MaterialPageRoute(builder: (_) => const SalesOrdersScreen());
      case '/purchase-orders':
        AppLogger.log(
          providerName: 'RouteGenerator',
          screenName: 'PurchaseOrdersScreen',
          functionName: 'generateRoute',
          action: 'Navigated to Purchase Orders List',
        );
        return MaterialPageRoute(builder: (_) => const PurchaseOrdersScreen());
      case '/serial-search':
        AppLogger.log(
          providerName: 'RouteGenerator',
          screenName: 'SerialSearchScreen',
          functionName: 'generateRoute',
          action: 'Navigated to Serial No Search',
        );
        return MaterialPageRoute(builder: (_) => const SerialSearchScreen());
      case '/sales-order-detail':
        final soNumber = settings.arguments as String;
        AppLogger.log(
          providerName: 'RouteGenerator',
          screenName: 'SalesOrderDetailScreen',
          functionName: 'generateRoute',
          action: 'Navigated to Sales Order Detail',
          additionalInfo: 'SO Number: $soNumber',
        );
        return MaterialPageRoute(
          builder: (_) => SalesOrderDetailScreen(soNumber: soNumber),
        );
      case '/purchase-order-detail':
        final poNumber = settings.arguments as String;
        AppLogger.log(
          providerName: 'RouteGenerator',
          screenName: 'PurchaseOrderDetailScreen',
          functionName: 'generateRoute',
          action: 'Navigated to Purchase Order Detail',
          additionalInfo: 'PO Number: $poNumber',
        );
        return MaterialPageRoute(
          builder: (_) => PurchaseOrderDetailScreen(
            poNumber: poNumber,
          ),
        );
      case '/add-lot':
        AppLogger.log(
          providerName: 'RouteGenerator',
          screenName: 'AddLotScreen',
          functionName: 'generateRoute',
          action: 'Navigated to Add Lot Screen',
        );
        return MaterialPageRoute(builder: (_) => const AddLotScreen());
      default:
        AppLogger.log(
          providerName: 'RouteGenerator',
          screenName: 'Unknown',
          functionName: 'generateRoute',
          action: 'Page not found - Error Route',
          additionalInfo: 'Requested route: ${settings.name}',
        );
        return _errorRoute();
    }
  }

  static Route<dynamic> _errorRoute() {
    return MaterialPageRoute(builder: (_) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Page not found!')),
      );
    });
  }
}
