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
  final Function(String, double)? onQuantityUpdated;

  const ItemCard({
    super.key,
    required this.item,
    this.soNumber = '',
    this.onAddLotPressed,
    this.onQuantityChanged,
    this.onQuantityUpdated,
  });

  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  bool _isExpanded = false;
  late TextEditingController _quantityController;

  @override
  void initState() {
    super.initState();
    bool isSalesOrderItem = widget.item is SalesOrderItem;
    double currentQty = isSalesOrderItem
        ? (widget.item as SalesOrderItem).qtyIssued
        : (widget.item as PurchaseOrderItem).qtyReceived;
    _quantityController = TextEditingController(text: currentQty.toString());
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _updateQuantityController() {
    bool isSalesOrderItem = widget.item is SalesOrderItem;
    double currentQty = isSalesOrderItem
        ? (widget.item as SalesOrderItem).qtyIssued
        : (widget.item as PurchaseOrderItem).qtyReceived;
    _quantityController.text = currentQty.toString();
  }

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
    
    // Update the text field if the quantity has changed externally
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_quantityController.text != qtyIssued.toString()) {
        _quantityController.text = qtyIssued.toString();
      }
    });

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

            /// SO Qty / PO Qty (just above Qty Ordered)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                isSalesOrderItem
                    ? 'SO Qty: ${(widget.item as SalesOrderItem).soQty}'
                    : 'PO Qty: ${(widget.item as PurchaseOrderItem).poQty}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),

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
                            _updateQuantityController();
                            widget.onQuantityChanged?.call(qtyIssued - 1);
                          }
                        },
                      ),
                      SizedBox(
                        width: 60,
                        child: TextField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            isDense: true,
                          ),
                          onSubmitted: (value) {
                            final newQty = double.tryParse(value) ?? 0;
                            widget.onQuantityUpdated?.call(widget.item.itemCode, newQty);
                          },
                        ),
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
                            _updateQuantityController();
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
