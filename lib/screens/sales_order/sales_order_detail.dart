import 'package:delivery_note_app/models/delivery_note_header.dart';
import 'package:delivery_note_app/providers/order_provider.dart';
import 'package:delivery_note_app/widgets/add_lot_dialog.dart';
import 'package:delivery_note_app/widgets/item_card.dart';
import 'package:delivery_note_app/widgets/summary_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/item_model.dart';

class SalesOrderDetailScreen extends StatefulWidget {
  final String soNumber;

  const SalesOrderDetailScreen({super.key, required this.soNumber});

  @override
  State<SalesOrderDetailScreen> createState() => _SalesOrderDetailScreenState();
}

class _SalesOrderDetailScreenState extends State<SalesOrderDetailScreen> {
  @override
  void initState() {
    // TODO: implement initState
    WidgetsBinding.instance.addPostFrameCallback((e) {
      Provider.of<OrderProvider>(context, listen: false).resetValidation();
    });
    super.initState();
  }

  void _showValidationDialog(BuildContext context, String message) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange[700],
                      size: 28),
                  const SizedBox(width: 12),
                  Text('Validation Required',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[700],
                      )),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _formatValidationMessage(message),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.4,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange[700],
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Got It'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// Helper function to format the message
  String _formatValidationMessage(String rawMessage) {
    // Add bullet points for each line if multiline
    if (rawMessage.contains('\n')) {
      return rawMessage.split('\n')
          .map((line) => line.trim().isNotEmpty ? '• $line' : '')
          .join('\n');
    }
    return rawMessage;
  }

  @override
  Widget build(BuildContext context) {
    final order =
        Provider.of<OrderProvider>(context).getSalesOrderById(widget.soNumber);

    if (order == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Order not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('SO #${order.soNumber}'),
        actions: [
          Consumer<OrderProvider>(
            builder: (context, provider, _) {
              if (provider.validationMessage.isNotEmpty) {
                return IconButton(
                  onPressed: () => _showValidationDialog(context, provider.validationMessage),
                  icon: const Icon(Icons.error_outline, color: Colors.redAccent),
                  tooltip: 'View validation details',
                );
              }
              return const SizedBox.shrink();
            },
          )        ],
      ),
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
                  item: item,
                  soNumber: order.soNumber,
                  onAddLotPressed: item.serialYN
                      ? () => showDialog(
                            context: context,
                            builder: (context) => AddLotDialog(
                              soNumber: order.soNumber,
                              itemCode: item.itemCode,
                              orderedQty: item.qtyOrdered,
                              availableStock: item.stockQty,
                            ),
                          )
                      : null,
                )),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Provider.of<OrderProvider>(context, listen: false)
                      .postDeliveryNote(context, widget.soNumber);
                },
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Post Delivery Note',
                    style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
