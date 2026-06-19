import 'dart:async';

import 'package:delivery_note_app/models/serial_search_group.dart';
import 'package:delivery_note_app/models/serial_search_model.dart';
import 'package:delivery_note_app/providers/order_provider.dart';
import 'package:delivery_note_app/providers/serial_search_provider.dart';
import 'package:delivery_note_app/services/app_logger.dart';
import 'package:delivery_note_app/utils/app_alerts.dart';
import 'package:delivery_note_app/utils/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class SerialSearchScreen extends StatefulWidget {
  const SerialSearchScreen({super.key});

  @override
  State<SerialSearchScreen> createState() => _SerialSearchScreenState();
}

class _SerialSearchScreenState extends State<SerialSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _keystrokeScanController =
      TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _keystrokeScanFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Timer? _keystrokeDebounce;
  bool _isProcessingScan = false;
  final Color themeColor = const Color.fromRGBO(251, 212, 18, 1.0);

  SerialSearchProvider? _serialProvider;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (AppConstants.scanningMode == 'keystroke') {
        _initializeKeystrokeScanning();
      } else {
        _startDataWedgeScanning();
        Provider.of<OrderProvider>(context, listen: false)
            .addListener(_handleDataWedgeScan);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _serialProvider ??=
        Provider.of<SerialSearchProvider>(context, listen: false);
  }

  @override
  void dispose() {
    _keystrokeDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _stopScanning(isDisposing: true);
    if (AppConstants.scanningMode == 'datawedge' && mounted) {
      try {
        Provider.of<OrderProvider>(context, listen: false)
            .removeListener(_handleDataWedgeScan);
      } catch (_) {}
    }
    _searchController.dispose();
    _keystrokeScanController.dispose();
    _searchFocusNode.dispose();
    _keystrokeScanFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeKeystrokeScanning() {
    _keystrokeScanFocusNode.requestFocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    _keystrokeScanFocusNode.addListener(() {
      if (!_keystrokeScanFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && !_searchFocusNode.hasFocus) {
            _keystrokeScanFocusNode.requestFocus();
            SystemChannels.textInput.invokeMethod('TextInput.hide');
          }
        });
      }
    });
  }

  void _returnFocusToScanner() {
    if (AppConstants.scanningMode != 'keystroke' || !mounted) return;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && !_searchFocusNode.hasFocus) {
        _keystrokeScanFocusNode.requestFocus();
        SystemChannels.textInput.invokeMethod('TextInput.hide');
      }
    });
  }

  Future<void> _startDataWedgeScanning() async {
    if (!mounted) return;
    try {
      final orderProvider =
          Provider.of<OrderProvider>(context, listen: false);
      await orderProvider.startScanning();
    } catch (e) {
      if (mounted) {
        AppAlerts.appToast(
            message: 'Failed to start scanner: ${e.toString()}');
      }
    }
  }

  Future<void> _stopScanning({bool isDisposing = false}) async {
    if (AppConstants.scanningMode == 'keystroke') {
      _keystrokeScanFocusNode.unfocus();
      return;
    }
    if (!mounted && !isDisposing) return;
    try {
      final orderProvider =
          Provider.of<OrderProvider>(context, listen: false);
      await orderProvider.stopScanner();
    } catch (_) {}
  }

  void _handleDataWedgeScan() {
    if (!mounted) return;
    final orderProvider =
        Provider.of<OrderProvider>(context, listen: false);
    final barcode = orderProvider.scannedBarcode;
    if (barcode != null && barcode.isNotEmpty) {
      _handleScannedSerial(barcode);
      orderProvider.clearScannedBarcode();
    }
  }

  Future<void> _processKeystrokeScan(String scannedValue) async {
    final value = scannedValue.trim();
    if (_isProcessingScan || value.isEmpty) return;

    _isProcessingScan = true;
    _keystrokeDebounce?.cancel();

    try {
      await _handleScannedSerial(value);
      if (mounted) {
        _keystrokeScanController.clear();
        _returnFocusToScanner();
      }
    } finally {
      _isProcessingScan = false;
    }
  }

  Future<void> _handleScannedSerial(String serial) async {
    final normalized = serial.trim().toUpperCase();
    _searchController.text = normalized;
    await _performSearch(fromScan: true);
    await AppLogger.log(
      providerName: 'SerialSearchScreen',
      screenName: 'SerialSearchScreen',
      functionName: '_handleScannedSerial',
      action: 'Serial scanned for search',
      additionalInfo: 'Serial: $serial',
    );
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.positions.length != 1) {
      return;
    }
    final position = _scrollController.positions.first;
    if (position.pixels < position.maxScrollExtent - 200) return;

    final provider =
        Provider.of<SerialSearchProvider>(context, listen: false);
    if (provider.hasMore &&
        !provider.isLoadingMore &&
        !provider.isLoading &&
        provider.hasSearched) {
      provider.loadMore();
    }
  }

  Future<void> _performSearch({bool fromScan = false}) async {
    final query = _searchController.text.trim().toUpperCase();
    if (query != _searchController.text) {
      _searchController.text = query;
    }
    if (query.isEmpty) {
      Provider.of<SerialSearchProvider>(context, listen: false)
          .resetResults();
      return;
    }

    final provider =
        Provider.of<SerialSearchProvider>(context, listen: false);
    try {
      await provider.searchSerials(query);
    } catch (e) {
      if (mounted) {
        AppAlerts.appToast(message: e.toString());
      }
    }

    if (!fromScan && mounted) {
      _searchFocusNode.unfocus();
    }
    _returnFocusToScanner();
  }

  Future<void> _runSearch() => _performSearch();

  void _clearSearch() {
    _searchController.clear();
    Provider.of<SerialSearchProvider>(context, listen: false).resetResults();
    _returnFocusToScanner();
  }

  Widget _buildSearchBar(SerialSearchProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                labelText: 'Enter Serial No',
                hintText: 'Scan or type serial number...',
                hintStyle: const TextStyle(fontSize: 14),
                prefixIcon: const Icon(Icons.qr_code_scanner),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _runSearch(),
              onTap: () {
                if (AppConstants.scanningMode == 'keystroke') {
                  _keystrokeScanFocusNode.unfocus();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: provider.isLoading ? null : _runSearch,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.search, size: 18),
            label: const Text('Search'),
          ),
        ],
      ),
    );
  }

  Widget _buildKeystrokeCaptureField() {
    if (AppConstants.scanningMode != 'keystroke') {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 0,
      width: 0,
      child: Focus(
        onFocusChange: (hasFocus) {
          if (hasFocus) {
            SystemChannels.textInput.invokeMethod('TextInput.hide');
          }
        },
        child: TextFormField(
          controller: _keystrokeScanController,
          focusNode: _keystrokeScanFocusNode,
          showCursor: false,
          enableInteractiveSelection: false,
          keyboardType: TextInputType.none,
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          style: const TextStyle(fontSize: 0, height: 0),
          onChanged: (value) {
            _keystrokeDebounce?.cancel();
            _keystrokeDebounce = Timer(const Duration(milliseconds: 50), () {
              if (!mounted || value.isEmpty) return;
              if (value.endsWith('\n') || value.endsWith('\r')) {
                _processKeystrokeScan(value.trim());
              }
            });
          },
          onEditingComplete: () {
            final scannedValue = _keystrokeScanController.text.trim();
            if (scannedValue.isNotEmpty && !_isProcessingScan) {
              _processKeystrokeScan(scannedValue);
            }
          },
          onFieldSubmitted: (value) {
            final scannedValue = value.trim();
            if (scannedValue.isNotEmpty && !_isProcessingScan) {
              _processKeystrokeScan(scannedValue);
            }
          },
        ),
      ),
    );
  }

  Widget _buildEntryTile(SerialSearchRecord record, bool isDark) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      margin: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
      shadowColor: isDark ? Colors.black45 : Colors.grey.withOpacity(0.2),
      child: ListTile(
        title: Text(
          record.docNoAndDate,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.customerAndClient,
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                record.itemAndLoc,
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSerialGroup(SerialSearchGroup group, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: themeColor.withOpacity(0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: themeColor.withOpacity(0.6)),
          ),
          child: Row(
            children: [
              const Icon(Icons.qr_code_2, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  group.serialNo,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${group.entries.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...group.entries.map((entry) => _buildEntryTile(entry, isDark)),
      ],
    );
  }

  Widget _buildResultsList(SerialSearchProvider provider, bool isDark) {
    final groups = provider.groupedRecords;

    return RefreshIndicator(
      onRefresh: () async {
        if (provider.searchQuery.isNotEmpty) {
          await provider.searchSerials(provider.searchQuery);
        }
      },
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: groups.length + (provider.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= groups.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          return _buildSerialGroup(groups[index], isDark);
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(backgroundColor: themeColor),
                child: Text(actionLabel,
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: themeColor,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios,
              color: Colors.white, size: 18),
        ),
        title: const Text(
          'Serial No Search',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        elevation: 1,
      ),
      body: Stack(
        children: [
          Consumer<SerialSearchProvider>(
            builder: (context, provider, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSearchBar(provider),
                  if (provider.isLoading && provider.records.isEmpty)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (!provider.hasSearched)
                    Expanded(
                      child: _buildEmptyState(
                        icon: Icons.qr_code_scanner,
                        message:
                            'Scan a serial number or enter one above, then tap Search.',
                      ),
                    )
                  else if (provider.records.isEmpty)
                    Expanded(
                      child: _buildEmptyState(
                        icon: Icons.search_off,
                        message:
                            'No results for "${provider.searchQuery}"',
                        actionLabel: 'Clear',
                        onAction: _clearSearch,
                      ),
                    )
                  else
                    Expanded(child: _buildResultsList(provider, isDark)),
                ],
              );
            },
          ),
          _buildKeystrokeCaptureField(),
        ],
      ),
    );
  }
}
