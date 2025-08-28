// item_card.dart
import 'package:delivery_note_app/models/purchase_order_model.dart';
import 'package:delivery_note_app/models/sales_order_model.dart';
import 'package:delivery_note_app/utils/app_alerts.dart';
import 'package:flutter/material.dart';


class ItemCard extends StatefulWidget {
  final dynamic item;
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
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    bool isSalesOrderItem = widget.item is SalesOrderItem;
    double stockQty = isSalesOrderItem
        ? (widget.item as SalesOrderItem).stockQty
        : (widget.item as PurchaseOrderItem).qtyOrdered;
    double qtyOrdered = widget.item.qtyOrdered;
    double qtyIssued = isSalesOrderItem
        ? (widget.item as SalesOrderItem).qtyIssued
        : (widget.item as PurchaseOrderItem).qtyReceived;

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Item Name + Stock
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: GestureDetector(
                    onTap: () => setState(() => _isExpanded = !_isExpanded),
                    child: Text(
                      widget.item.itemName,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: _isExpanded ? null : 1,
                      overflow: _isExpanded ? null : TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Text(
                  'Stock: $stockQty',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 6),

            /// Item Code
            Text(
              widget.item.itemCode,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),

            const Divider(height: 20),

            /// Qty Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Qty Ordered: $qtyOrdered',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (!widget.item.serialYN)
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: () {
                          if (qtyIssued > 0) {
                            setState(() {
                              isSalesOrderItem
                                  ? (widget.item as SalesOrderItem).qtyIssued--
                                  : (widget.item as PurchaseOrderItem).qtyReceived--;
                            });
                            widget.onQuantityChanged?.call(qtyIssued - 1);
                          }
                        },
                      ),
                      Text(
                        '$qtyIssued',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          if (qtyIssued >= qtyOrdered) {
                            AppAlerts.appToast(
                                message:
                                'Cannot exceed ordered quantity ($qtyOrdered)');
                          } else if (isSalesOrderItem &&
                              qtyIssued >= stockQty) {
                            AppAlerts.appToast(
                                message:
                                'Insufficient stock ($stockQty available)');
                          } else {
                            setState(() {
                              isSalesOrderItem
                                  ? (widget.item as SalesOrderItem).qtyIssued++
                                  : (widget.item as PurchaseOrderItem).qtyReceived++;
                            });
                            widget.onQuantityChanged?.call(qtyIssued + 1);
                          }
                        },
                      ),
                    ],
                  ),
              ],
            ),

            /// Add Lot Button
            if (widget.item.serialYN && widget.onAddLotPressed != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.onAddLotPressed,
                    icon:  Icon(Icons.add,color: Colors.blue[700],),
                    label: Text('Add Lot',style: TextStyle(color: Colors.blue[700]),),
                  ),
                ),
              ),

            /// Serials List
            if (widget.item.serials.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Added Serials:'),
                    const SizedBox(height: 4),
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
