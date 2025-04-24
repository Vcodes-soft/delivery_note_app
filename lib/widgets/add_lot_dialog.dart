import 'package:delivery_note_app/models/sales_order_model.dart';
import 'package:delivery_note_app/utils/app_alerts.dart';
import 'package:delivery_note_app/utils/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/item_model.dart';
import '../../providers/order_provider.dart';

class AddLotDialog extends StatefulWidget {
  final String soNumber;
  final String itemCode;
  final double orderedQty;
  final double availableStock;

  const AddLotDialog({
    super.key,
    required this.soNumber,
    required this.itemCode,
    required this.orderedQty,
    required this.availableStock,
  });

  @override
  State<AddLotDialog> createState() => _AddLotDialogState();
}

class _AddLotDialogState extends State<AddLotDialog> {
  final TextEditingController _serialController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final order = orderProvider.getSalesOrderById(widget.soNumber);
    final item = order?.items.firstWhere(
          (i) => i.itemCode == widget.itemCode,
      orElse: () => throw Exception('Item not found'),
    );

    return AlertDialog(
      title: Text('Scan Serial for ${item?.itemName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Global validation toggle

            // Scan button
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Serial Number'),
              onPressed: () => _scanSerial(context),
            ),
            const SizedBox(height: 16),
            const Text('Or enter manually:'),
            TextField(
              controller: _serialController,
              decoration: const InputDecoration(
                labelText: 'Serial Number',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) => _addSerial(context, value),
            ),
            const SizedBox(height: 24),
            // List of already scanned serials
            if (item!.serials.isNotEmpty) ...[
              const Text('Scanned Serials:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...item.serials.map((serial) => ListTile(
                leading: Text('${serial.sNo}.'),
                title: Text(serial.serialNo),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeSerial(context, serial.serialNo),
                ),
              )),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  void _scanSerial(BuildContext context) async {
    final scannedSerial = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Serial Number'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter serial number'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
      ),
    );

    if (scannedSerial != null && scannedSerial.isNotEmpty) {
      await _addSerial(context, scannedSerial);
    }
  }

  Future<void> _addSerial(BuildContext context, String serialNo) async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    try {
      await orderProvider.addSerialToItem(
        soNumber: widget.soNumber,
        itemCode: widget.itemCode,
        serialNo: serialNo,
      );
      _serialController.clear();
    } catch (e) {

      AppAlerts.appToast(message: e.toString());

    }
  }

  void _removeSerial(BuildContext context, String serialNo) {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    try {
      orderProvider.removeSerialFromItem(
        soNumber: widget.soNumber,
        itemCode: widget.itemCode,
        serialNo: serialNo,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  void dispose() {
    _serialController.dispose();
    super.dispose();
  }
}