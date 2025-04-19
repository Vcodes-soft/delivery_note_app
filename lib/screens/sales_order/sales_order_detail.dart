import 'package:delivery_note_app/providers/order_provider.dart';
import 'package:delivery_note_app/widgets/item_card.dart';
import 'package:delivery_note_app/widgets/summary_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/item_model.dart';

class SalesOrderDetailScreen extends StatelessWidget {
  final String soNumber;

  const SalesOrderDetailScreen({super.key, required this.soNumber});

  @override
  Widget build(BuildContext context) {
    final order = Provider.of<OrderProvider>(context).getSalesOrderById(soNumber);

    if (order == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Order not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('SO #${order.soNumber}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SummaryCard(
              title: order.customerName,
              subtitle: 'Ref No: ${order.refNo}',
              details: [
                'SO Date: ${order.soDate.day}-${order.soDate.month}-${order.soDate.year}',
                'Salesman: ${order.salesmanName}',
                'Location: ${order.locationCode}',
                'Total Items: ${order.items.length}',
              ],
              status: order.isPending ? 'PENDING' : 'COMPLETED',
              statusColor: order.isPending ? Colors.orange : Colors.green,
            ),
            const SizedBox(height: 24),
            const Text('Item Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // Display all items in the order
            ...order.items.map((item) => ItemCard(
              item: Item(
                id: item.itemCode,
                name: item.itemName,
                code: item.itemCode,
                stock: item.stockQty,
                orderedQuantity: item.qtyOrdered,
                unit: item.unit,
                isSerialized: item.serialYN,
                isNonInventory: item.nonInventory,
              ),
              soNumber: order.soNumber,
              onAddLotPressed: item.serialYN
                  ? () => Navigator.of(context).pushNamed(
                '/add-lot',
                arguments: {
                  'soNumber': order.soNumber,
                  'itemCode': item.itemCode,
                  'orderedQty': item.qtyOrdered,
                  'availableStock': item.stockQty,
                },
              )
                  : null,
            )),
          ],
        ),
      ),
    );
  }
}