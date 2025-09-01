import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:delivery_note_app/models/sales_order_model.dart';
import 'package:delivery_note_app/providers/order_provider.dart';
import 'package:delivery_note_app/widgets/add_lot_dialog.dart';
import 'package:delivery_note_app/widgets/item_card.dart';
import 'package:delivery_note_app/widgets/summary_card.dart';

class SalesOrderDetailScreen extends StatefulWidget {
  final String soNumber;

  const SalesOrderDetailScreen({super.key, required this.soNumber});

  @override
  State<SalesOrderDetailScreen> createState() => _SalesOrderDetailScreenState();
}

class _SalesOrderDetailScreenState extends State<SalesOrderDetailScreen> {
  final Color themeColor = const Color.fromRGBO(255, 213, 3, 1.0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<OrderProvider>(context, listen: false);
      provider.resetValidation();
      provider.fetchSalesOrderDetails(widget.soNumber);
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final order = orderProvider.getSalesOrderById(widget.soNumber);

    if (order == null || orderProvider.isLoading) {
      return Scaffold(
        appBar: _buildAppBar('Loading...'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Check if all items have qtyOrdered <= 0
    final bool allItemsZeroOrLess = order.items.every((item) => item.qtyOrdered <= 0);

    return Scaffold(
      appBar: _buildAppBar('SO #${order.soNumber}'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Summary Card (Replaces manual layout)
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

            /// Item Details Header
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                'Item Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 12),

            /// Item List
            ...order.items.map((item) => ItemCard(
              item: item,
              soNumber: order.soNumber,
              onAddLotPressed: item.serialYN
                  ? () => showDialog(
                context: context,
                builder: (context) => AddLotScreen(
                  soNumber: order.soNumber,
                  itemCode: item.itemCode,
                  orderedQty: item.qtyOrdered,
                  availableStock: item.stockQty,
                ),
              )
                  : null,
            )),

            const SizedBox(height: 24),

            /// Post Delivery Note Button - Only show if not all items have qtyOrdered <= 0
            if (!allItemsZeroOrLess) Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Provider.of<OrderProvider>(context, listen: false)
                      .postDeliveryNote(context, widget.soNumber);
                },
                icon: const Icon(Icons.local_shipping_outlined, size: 20),
                label: const Text('Post Delivery Note',
                    style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(String titleText) {
    return AppBar(
      backgroundColor: themeColor,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
      ),
      title: Text(titleText,
          style: const TextStyle(color: Colors.white, fontSize: 14)),
      elevation: 1,
      actions: [
        Consumer<OrderProvider>(
          builder: (context, provider, _) {
            if (provider.validationMessage.isNotEmpty) {
              return IconButton(
                onPressed: () => _showValidationDialog(
                    context, provider.validationMessage),
                icon: const Icon(Icons.error_outline,
                    color: Colors.white, size: 18),
                tooltip: 'View validation details',
              );
            }
            return const SizedBox.shrink();
          },
        )
      ],
    );
  }

  void _showValidationDialog(BuildContext context, String message) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Title
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange[700], size: 28),
                  const SizedBox(width: 12),
                  Text('Validation Required',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[700],
                      )),
                ],
              ),
              const SizedBox(height: 16),

              /// Message Body
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

              /// Action Button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange[700],
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 8),
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

  String _formatValidationMessage(String rawMessage) {
    if (rawMessage.contains('\n')) {
      return rawMessage
          .split('\n')
          .map((line) => line.trim().isNotEmpty ? '• $line' : '')
          .join('\n');
    }
    return rawMessage;
  }
}