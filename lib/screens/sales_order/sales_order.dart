import 'package:delivery_note_app/providers/order_provider.dart';
import 'package:delivery_note_app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SalesOrdersScreen extends StatelessWidget {
  const SalesOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final salesOrders = Provider.of<OrderProvider>(context).salesOrders;

    return Scaffold(
      appBar: AppBar(title: const Text('Sales Orders')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: salesOrders.length,
        itemBuilder: (context, index) {
          final order = salesOrders[index];
          return OrderCard(
            order: order,
            onTap: () => Navigator.of(context).pushNamed(
              '/sales-order-detail',
              arguments: order.id,
            ),
          );
        },
      ),
    );
  }
}