import 'package:delivery_note_app/models/sales_order_model.dart';
import 'package:delivery_note_app/utils/app_alerts.dart';
import 'package:flutter/material.dart';
import 'package:delivery_note_app/models/item_model.dart'; // Assuming this exports SalesOrderItem

class ItemCard extends StatefulWidget {
  final SalesOrderItem item;
  final String soNumber;
  final VoidCallback? onAddLotPressed;
  final Function(double)? onQuantityChanged;

  const ItemCard({
    super.key,
    required this.item,
    this.soNumber = '',
    this.onAddLotPressed,
    this.onQuantityChanged,
  });

  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    widget.item.itemName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  'Stock: ${widget.item.stockQty}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(widget.item.itemCode),
            const SizedBox(height: 8),
            Text(
              'Qty Ordered: ${widget.item.qtyOrdered}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (widget.item.serialYN && widget.onAddLotPressed != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.onAddLotPressed,
                    child: const Text('Add Lot'),
                  ),
                ),
              ),
            if (!widget.item.serialYN)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Text('Qty: '),
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () {
                        if (widget.item.qtyIssued > 0) {
                          setState(() {
                            widget.item.qtyIssued--;
                          });
                          widget.onQuantityChanged?.call(widget.item.qtyIssued);
                        }
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '${widget.item.qtyIssued}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        if (widget.item.qtyIssued >= widget.item.qtyOrdered) {
                          AppAlerts.appToast(message: 'Cannot exceed ordered quantity (${widget.item.qtyOrdered})');
                        } else if (widget.item.qtyIssued >= widget.item.stockQty) {
                          AppAlerts.appToast(message: 'Insufficient stock (${widget.item.stockQty} available)');
                        } else {
                          setState(() {
                            widget.item.qtyIssued++;
                          });
                          widget.onQuantityChanged?.call(widget.item.qtyIssued);
                        }
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const Spacer(),
                    SizedBox(),
                  ],
                ),
              ),
            if (widget.item.serials.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Added Serials:'),
                    ...widget.item.serials.map((serial) => Text(
                      '${serial.sNo}. ${serial.serialNo}',
                      style: Theme.of(context).textTheme.bodySmall,
                    )),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}