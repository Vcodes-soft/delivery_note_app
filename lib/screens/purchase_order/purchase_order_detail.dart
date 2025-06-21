// purchase_order_detail_screen.dart
import 'package:delivery_note_app/models/purchase_order_model.dart';
import 'package:delivery_note_app/providers/purchase_order_provider.dart';
import 'package:delivery_note_app/widgets/add_lot_dialog.dart';
import 'package:delivery_note_app/widgets/item_card.dart';
import 'package:delivery_note_app/widgets/summary_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PurchaseOrderDetailScreen extends StatefulWidget {
  final String poNumber;

  const PurchaseOrderDetailScreen({super.key, required this.poNumber});

  @override
  State<PurchaseOrderDetailScreen> createState() => _PurchaseOrderDetailScreenState();
}

class _PurchaseOrderDetailScreenState extends State<PurchaseOrderDetailScreen> {
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((e) {
      Provider.of<PurchaseOrderProvider>(context, listen: false).resetValidation();
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

  String _formatValidationMessage(String rawMessage) {
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
    Provider.of<PurchaseOrderProvider>(context).getPurchaseOrderById(widget.poNumber);

    if (order == null) {
      return Scaffold(
        appBar: AppBar(

        ),
        body: const Center(child: Text('Order not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(order.poNumber),
        actions: [
          Consumer<PurchaseOrderProvider>(
            builder: (context, provider, _) {
              if (provider.validationMessage.isNotEmpty) {
                return IconButton(
                  onPressed: () => _showValidationDialog(context, provider.validationMessage),
                  icon: const Icon(Icons.error_outline, color: Colors.redAccent),
                  tooltip: 'View validation details',
                );
              }
              // return const SizedBox.shrink();
              return IconButton(onPressed: (){
                provider.getNextGrnNumber();
              }, icon: Icon(Icons.abc));
            },

          )        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SummaryCard(
              title: order.supplierName,
              subtitle: 'Ref No: ${order.refNo}',
              details: [
                'PO Date: ${order.poDate.day}-${order.poDate.month}-${order.poDate.year}',
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
              soNumber: order.poNumber,
              onAddLotPressed: item.serialYN
                  ? () => showDialog(
                context: context,
                builder: (context) => POAddLotScreen(
                  poNumber: order.poNumber,
                  itemCode: item.itemCode,
                  orderedQty: item.qtyOrdered,
                  availableStock: item.qtyOrdered, // For PO, we use ordered qty as reference
                ),
              )
                  : null,
            )),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Provider.of<PurchaseOrderProvider>(context, listen: false)
                      .postGoodsReceipt(context, widget.poNumber);
                },
                style: ElevatedButton.styleFrom(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Post GRN',
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