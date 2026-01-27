// purchase_orders_screen.dart
import 'package:delivery_note_app/models/purchase_order_model.dart';
import 'package:delivery_note_app/providers/purchase_order_provider.dart';
import 'package:delivery_note_app/widgets/order_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:advanced_searchable_dropdown/advanced_searchable_dropdown.dart';

class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isInitialLoad = true;
  final Color themeColor = const Color.fromRGBO(251, 212, 18, 1.0);
  PurchaseOrderProvider? _provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPurchaseOrders();
      _initializeSearchController();
    });
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider ??= Provider.of<PurchaseOrderProvider>(context, listen: false);
  }

  @override
  void dispose() {
    _provider?.clearFilters(notify: false);
    _searchController.dispose();
    super.dispose();
  }

  void _initializeSearchController() {
    final provider = Provider.of<PurchaseOrderProvider>(context, listen: false);
    // Sync the search controller with the provider's current search query
    _searchController.text = provider.searchQuery;
  }

  void _onSearchChanged() {
    final provider = Provider.of<PurchaseOrderProvider>(context, listen: false);
    provider.searchPurchaseOrders(_searchController.text);
  }

  Future<void> _loadPurchaseOrders() async {
    final provider = Provider.of<PurchaseOrderProvider>(context, listen: false);
    try {
      provider.initializeScanner();
      await provider.fetchPurchaseOrders();
    } catch (e) {
      // Handle error if needed
    } finally {
      if (mounted) {
        setState(() => _isInitialLoad = false);
      }
    }
  }

  Future<void> _refreshPurchaseOrders() async {
    final provider = Provider.of<PurchaseOrderProvider>(context, listen: false);
    try {
      provider.clearFilters(notify: true);
      await provider.fetchPurchaseOrders();
    } catch (e) {
      // Handle error if needed
      rethrow;
    }
  }

  void _clearSearch() {
    final provider = Provider.of<PurchaseOrderProvider>(context, listen: false);
    _searchController.clear();
    provider.searchPurchaseOrders('');
  }

  void _clearAllFilters() {
    final provider = Provider.of<PurchaseOrderProvider>(context, listen: false);
    _searchController.clear();
    provider.clearFilters();
  }

  @override
  Widget build(BuildContext context) {
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
              final provider = Provider.of<PurchaseOrderProvider>(context, listen: false);
              provider.clearFilters();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
          ),
          title: const Text('Purchase Orders', style: TextStyle(color: Colors.white, fontSize: 16)),
          elevation: 1,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
              tooltip: 'Refresh Orders',
              onPressed: _refreshPurchaseOrders,
            ),
          ],
        ),
        body: Consumer<PurchaseOrderProvider>(
          builder: (context, provider, child) {
            if (_isInitialLoad) {
              return const Center(child: CircularProgressIndicator());
            }

            final ordersToDisplay = (provider.searchQuery.isEmpty &&
                provider.selectedLocationCode == null &&
                provider.selectedSupplierName == null)
                ? provider.purchaseOrders
                : provider.filteredPurchaseOrders;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by PO#',
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
                            SearchableDropDownItem(label: 'All Suppliers', value: null),
                            ...provider.uniqueSuppliers.map((supplier) =>
                              SearchableDropDownItem(label: supplier, value: supplier)
                            ),
                          ],
                          value: provider.selectedSupplierName,
                          textStyle: TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            label: Text('Supplier', style: TextStyle(fontSize: 12)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white,
                            isDense: true,
                          ),
                          onSelected: (item) {
                            provider.setSupplierFilter(item.value);
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
                             provider.selectedSupplierName == null)
                                ? 'No purchase orders found'
                                : 'No results found',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: _refreshPurchaseOrders,
                                style: ElevatedButton.styleFrom(backgroundColor: themeColor),
                                child: const Text('Refresh', style: TextStyle(color: Colors.white)),
                              ),
                              if (provider.searchQuery.isNotEmpty ||
                                  provider.selectedLocationCode != null ||
                                  provider.selectedSupplierName != null)
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
                            onRefresh: _refreshPurchaseOrders,
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
                                      order.poNumber,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Supplier: ${order.supplierName}',
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
                                      '/purchase-order-detail',
                                      arguments: order.poNumber,
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