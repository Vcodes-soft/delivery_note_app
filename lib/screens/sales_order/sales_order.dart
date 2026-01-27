// sales_orders_screen.dart
import 'package:delivery_note_app/models/sales_order_model.dart';
import 'package:delivery_note_app/providers/order_provider.dart';
import 'package:delivery_note_app/widgets/order_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:advanced_searchable_dropdown/advanced_searchable_dropdown.dart';
import 'package:advanced_searchable_dropdown/advanced_searchable_dropdown.dart';

class SalesOrdersScreen extends StatefulWidget {
  const SalesOrdersScreen({super.key});

  @override
  State<SalesOrdersScreen> createState() => _SalesOrdersScreenState();
}

class _SalesOrdersScreenState extends State<SalesOrdersScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isInitialLoad = true;
  final Color themeColor = const Color.fromRGBO(251, 212, 18, 1.0);
  OrderProvider? _provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSalesOrders();
      _initializeSearchController();
    });
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider ??= Provider.of<OrderProvider>(context, listen: false);
  }

  @override
  void dispose() {
    _provider?.clearFilters(notify: false);
    _searchController.dispose();
    super.dispose();
  }

  void _initializeSearchController() {
    final provider = Provider.of<OrderProvider>(context, listen: false);
    // Sync the search controller with the provider's current search query
    _searchController.text = provider.searchQuery;
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
      provider.clearFilters(notify: true);
      await provider.fetchSalesOrders();
    } catch (e) {
      // Handle error if needed
      rethrow;
    }
  }

  void _clearSearch() {
    final provider = Provider.of<OrderProvider>(context, listen: false);
    _searchController.clear();
    provider.searchSalesOrders('');
  }

  void _clearAllFilters() {
    final provider = Provider.of<OrderProvider>(context, listen: false);
    _searchController.clear();
    provider.clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: (){
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: themeColor,
          leading: IconButton(
            onPressed: () {
              // Clear all filters when navigating back
              final provider = Provider.of<OrderProvider>(context, listen: false);
              provider.clearFilters();
              Navigator.pop(context);
            },
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

            final ordersToDisplay = (provider.searchQuery.isEmpty &&
                provider.selectedLocationCode == null &&
                provider.selectedCustomerName == null)
                ? provider.salesOrders
                : provider.filteredSalesOrders;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by SO#',
                      hintStyle: const TextStyle(fontSize: 14),
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      suffixIcon: provider.searchQuery.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      )
                          : null,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: SearchableDropDown(
                          menuList: [
                            SearchableDropDownItem(label: 'All Locations', value: null),
                            ...provider.uniqueLocations.map((loc) =>
                              SearchableDropDownItem(label: loc, value: loc)
                            ),
                          ],
                          value: provider.selectedLocationCode,
                          textStyle: TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            label: Text('Location', style: TextStyle(fontSize: 12)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white,
                            isDense: true,
                          ),
                          onSelected: (item) {
                            provider.setLocationFilter(item.value);
                          },
                          menuMaxHeight: 300,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SearchableDropDown(
                          menuList: [
                            SearchableDropDownItem(label: 'All Customers', value: null),
                            ...provider.uniqueCustomers.map((customer) =>
                              SearchableDropDownItem(label: customer, value: customer)
                            ),
                          ],
                          value: provider.selectedCustomerName,
                          textStyle: TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            label: Text('Customer', style: TextStyle(fontSize: 12)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white,
                            isDense: true,
                          ),
                          onSelected: (item) {
                            provider.setCustomerFilter(item.value);
                          },
                          menuMaxHeight: 300,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (ordersToDisplay.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.assignment, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            (provider.searchQuery.isEmpty &&
                             provider.selectedLocationCode == null &&
                             provider.selectedCustomerName == null)
                                ? 'No sales orders found'
                                : 'No results found',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: _refreshSalesOrders,
                                style: ElevatedButton.styleFrom(backgroundColor: themeColor),
                                child: const Text('Refresh', style: TextStyle(color: Colors.white)),
                              ),
                              if (provider.searchQuery.isNotEmpty ||
                                  provider.selectedLocationCode != null ||
                                  provider.selectedCustomerName != null)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: ElevatedButton(
                                    onPressed: _clearAllFilters,
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                                    child: const Text('Clear Filters', style: TextStyle(color: Colors.white)),
                                  ),
                                ),
                            ],
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
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Customer: ${order.customerName}',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Location: ${order.locationCode}',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ],
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
      ),
    );
  }

}