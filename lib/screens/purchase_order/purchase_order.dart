// purchase_orders_screen.dart
import 'package:delivery_note_app/models/purchase_order_model.dart';
import 'package:delivery_note_app/providers/purchase_order_provider.dart';
import 'package:delivery_note_app/widgets/order_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<PurchaseOrder> _filteredOrders = [];

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PurchaseOrderProvider>(context, listen: false).initializeScanner();
      Provider.of<PurchaseOrderProvider>(context, listen: false).fetchPurchaseOrders();
    });
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterOrders(String query) {
    final provider = Provider.of<PurchaseOrderProvider>(context, listen: false);

    setState(() {
      _filteredOrders = provider.purchaseOrders.where((order) {
        return order.poNumber.toLowerCase().contains(query.toLowerCase()) ||
            order.supplierName.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Orders'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _filterOrders,
              decoration: InputDecoration(
                hintText: 'Search by PO# or Supplier',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
      ),
      body: Consumer<PurchaseOrderProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CupertinoActivityIndicator());
          }

          final ordersToDisplay = _searchController.text.isEmpty
              ? provider.purchaseOrders
              : _filteredOrders;

          return ordersToDisplay.isEmpty
              ? const Center(child: Text('No orders found'))
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: ordersToDisplay.length,
            itemBuilder: (context, index) {
              return OrderCard(
                order: ordersToDisplay[index],
                onTap: () => Navigator.of(context).pushNamed(
                  '/purchase-order-detail',
                  arguments: ordersToDisplay[index].poNumber,
                ),
              );
            },
          );
        },
      ),
    );
  }
}