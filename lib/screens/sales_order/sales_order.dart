// sales_orders_screen.dart
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
  bool _isInitialLoad = true;
  final Color themeColor = const Color.fromRGBO(251, 212, 18, 1.0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSalesOrders();
    });
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final provider = Provider.of<OrderProvider>(context, listen: false);
    provider.searchSalesOrders(_searchController.text);
  }

  Future<void> _loadSalesOrders() async {
    final provider = Provider.of<OrderProvider>(context, listen: false);
    try {
      provider.initializeScanner();
      await provider.fetchSalesOrders();
    } catch (e) {
      // Handle error if needed
    } finally {
      if (mounted) {
        setState(() => _isInitialLoad = false);
      }
    }
  }

  Future<void> _refreshSalesOrders() async {
    final provider = Provider.of<OrderProvider>(context, listen: false);
    try {
      await provider.fetchSalesOrders();
    } catch (e) {
      // Handle error if needed
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: themeColor,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
        ),
        title: const Text('Sales Orders', style: TextStyle(color: Colors.white, fontSize: 16)),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
            tooltip: 'Refresh Orders',
            onPressed: _refreshSalesOrders,
          ),
        ],
      ),
      body: Consumer<OrderProvider>(
        builder: (context, provider, child) {
          if (_isInitialLoad) {
            return const Center(child: CircularProgressIndicator());
          }

          final ordersToDisplay = provider.searchQuery.isEmpty
              ? provider.salesOrders
              : provider.filteredSalesOrders;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by SO# or Customer',
                    hintStyle: const TextStyle(fontSize: 14),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    suffixIcon: provider.searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        provider.searchSalesOrders('');
                      },
                    )
                        : null,
                  ),
                ),
              ),
              if (ordersToDisplay.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.assignment, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          provider.searchQuery.isEmpty
                              ? 'No sales orders found'
                              : 'No results for "${provider.searchQuery}"',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _refreshSalesOrders,
                          style: ElevatedButton.styleFrom(backgroundColor: themeColor),
                          child: const Text('Refresh', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Showing ${ordersToDisplay.length} orders',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _refreshSalesOrders,
                          edgeOffset: 20,
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            itemCount: ordersToDisplay.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final order = ordersToDisplay[index];

                              return Card(
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 3,
                                margin: EdgeInsets.zero,
                                shadowColor: isDark ? Colors.black45 : Colors.grey.withOpacity(0.2),
                                child: ListTile(
                                  title: Text(
                                    order.soNumber,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    'Customer: ${order.customerName}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  onTap: () => Navigator.of(context).pushNamed(
                                    '/sales-order-detail',
                                    arguments: order.soNumber,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}