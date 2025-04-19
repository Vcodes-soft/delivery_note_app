import 'package:delivery_note_app/models/item_model.dart';
import 'package:flutter/material.dart';

class ItemCard extends StatelessWidget {
  final Item item;
  final String soNumber;
  final VoidCallback? onAddLotPressed;

  const ItemCard({
    super.key,
    required this.item,
    this.soNumber = '',
    this.onAddLotPressed,
  });

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
                    item.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  'Stock: ${item.stock}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(item.code),
            const SizedBox(height: 8),
            Text(
              'Qty Ordered: ${item.orderedQuantity}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (item.isSerialized && onAddLotPressed != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onAddLotPressed,
                    child: const Text('Add Lot'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}