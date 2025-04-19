import 'package:delivery_note_app/models/purchase_order_model.dart';
import 'package:delivery_note_app/models/sales_order_model.dart';
import 'package:flutter/material.dart';

class OrderCard extends StatelessWidget {
  final dynamic order;
  final VoidCallback onTap;

  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String title;
    String subtitle;
    String status;
    DateTime issueDate;

    if (order is SalesOrder) {
      title = (order as SalesOrder).customerName;
      subtitle = (order as SalesOrder).soNumber;
      status = ((order).isPending ? 'PENDING' : 'COMPLETED').toString();
      issueDate = (order as SalesOrder).soDate;
    } else if (order is PurchaseOrder) {
      title = (order as PurchaseOrder).supplierName;
      subtitle = '${order.id}';
      status = (order as PurchaseOrder).isPending ? 'PENDING' : 'COMPLETED';
      issueDate = (order as PurchaseOrder).issueDate;
    } else {
      throw ArgumentError('Unknown order type');
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: status == 'PENDING'
                          ? Colors.orange.withOpacity(0.2)
                          : Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: status == 'PENDING' ? Colors.orange : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(subtitle),
              const SizedBox(height: 8),
              Text(
                'Issued: ${issueDate.day}-${issueDate.month}-${issueDate.year}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}