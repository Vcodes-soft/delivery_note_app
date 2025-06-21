import 'package:delivery_note_app/models/sales_order_model.dart';
import 'package:delivery_note_app/providers/order_provider.dart';
import 'package:delivery_note_app/widgets/order_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SalesOrdersScreen extends StatefulWidget {
  const SalesOrdersScreen({super.key});

  @override
  State<SalesOrdersScreen> createState() => _SalesOrdersScreenState();
}

class _SalesOrdersScreenState extends State<SalesOrdersScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<SalesOrder> _filteredOrders = [];

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(context, listen: false).initializeScanner();
      Provider.of<OrderProvider>(context, listen: false).fetchSalesOrders();

    });
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterOrders(String query) {
    final provider = Provider.of<OrderProvider>(context, listen: false);

    setState(() {
      _filteredOrders = provider.salesOrders.where((order) {
        return order.soNumber.toLowerCase().contains(query.toLowerCase()) ||
            order.customerName.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Orders'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _filterOrders,
              decoration: InputDecoration(
                hintText: 'Search by SO# or Customer',
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
      body: Consumer<OrderProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CupertinoActivityIndicator());
          }

          final ordersToDisplay = _searchController.text.isEmpty
              ? provider.salesOrders
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
                  '/sales-order-detail',
                  arguments: ordersToDisplay[index].soNumber,
                ),
              );
            },
          );
        },
      ),
    );
  }
}