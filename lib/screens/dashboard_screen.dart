import 'package:delivery_note_app/providers/auth_provider.dart';
import 'package:delivery_note_app/providers/order_provider.dart';
import 'package:delivery_note_app/widgets/dashboard_card.dart';
import 'package:delivery_note_app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout(context);
              // Navigator.of(context).pushReplacementNamed('/');
            },
          ),
        ],
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
        children: [
          DashboardCard(
            title: 'Total Sales Orders',
            value: "",
            icon: Icons.shopping_cart,
            color: Colors.blue,
            onTap: () => Navigator.of(context).pushNamed('/sales-orders'),
          ),
          DashboardCard(
            title: 'Pending Sales Orders',
            value: "",
            icon: Icons.pending_actions,
            color: Colors.orange,
            onTap: () => Navigator.of(context).pushNamed('/sales-orders'),
          ),
          DashboardCard(
            title: 'Total Purchase Orders',
            value: "",
            icon: Icons.inventory,
            color: Colors.green,
            onTap: () => Navigator.of(context).pushNamed('/purchase-orders'),
          ),
          DashboardCard(
            title: 'Pending Purchase Orders',
            value: "123",
            icon: Icons.pending,
            color: Colors.red,
            onTap: () => Navigator.of(context).pushNamed('/purchase-orders'),
          ),
        ],
      ),
    );
  }
}