import 'package:delivery_note_app/providers/order_provider.dart';
import 'package:delivery_note_app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PurchaseOrdersScreen extends StatelessWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final purchaseOrders = Provider.of<OrderProvider>(context).purchaseOrders;

    return Scaffold(
      appBar: AppBar(title: const Text('Purchase Orders')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: purchaseOrders.length,
        itemBuilder: (context, index) {
          final order = purchaseOrders[index];
          return OrderCard(
            order: order,
            onTap: () => Navigator.of(context).pushNamed(
              '/purchase-order-detail',
              arguments: order.id,
            ),
          );
        },
      ),
    );
  }
}