// lib/routes.dart
import 'package:delivery_note_app/screens/auth_screen.dart';
import 'package:delivery_note_app/screens/dashboard_screen.dart';
import 'package:delivery_note_app/screens/purchase_order/purchase_order.dart';
import 'package:delivery_note_app/screens/purchase_order/purchase_order_detail.dart';
import 'package:delivery_note_app/screens/sales_order/sales_order.dart';
import 'package:delivery_note_app/screens/sales_order/sales_order_detail.dart';
import 'package:delivery_note_app/screens/screens.dart';
import 'package:delivery_note_app/screens/server_configuration.dart';
import 'package:flutter/material.dart';

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const ServerConfigScreen());
      case '/auth':
        return MaterialPageRoute(builder: (_) => const AuthScreen());
      case '/dashboard':
        return MaterialPageRoute(builder: (_) => const DashboardScreen());
      case '/sales-orders':
        return MaterialPageRoute(builder: (_) => const SalesOrdersScreen());
      case '/purchase-orders':
        return MaterialPageRoute(builder: (_) => const PurchaseOrdersScreen());
      case '/sales-order-detail':
        return MaterialPageRoute(
          builder: (_) => SalesOrderDetailScreen(
            orderId: settings.arguments as String,
          ),
        );
      case '/purchase-order-detail':
        return MaterialPageRoute(
          builder: (_) => PurchaseOrderDetailScreen(
            orderId: settings.arguments as String,
          ),
        );
      case '/add-lot':
        return MaterialPageRoute(builder: (_) => const AddLotScreen());
      default:
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