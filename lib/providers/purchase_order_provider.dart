// purchase_order_provider.dart
import 'dart:async';
import 'dart:convert';
import 'package:delivery_note_app/models/sales_order_model.dart';
import 'package:delivery_note_app/utils/app_alerts.dart';
import 'package:delivery_note_app/utils/extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_datawedge/flutter_datawedge.dart';
import 'package:intl/intl.dart';
import 'package:mssql_connection/mssql_connection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delivery_note_app/models/purchase_order_model.dart';
import 'package:delivery_note_app/services/telegram_logger.dart';

class PurchaseOrderProvider with ChangeNotifier {
  final MssqlConnection _sqlConnection = MssqlConnection.getInstance();
  List<PurchaseOrder> _purchaseOrders = [];
  bool _isLoading = false;
  String? _error;
  List<PurchaseOrder> get purchaseOrders => _purchaseOrders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<PurchaseOrder> filteredPurchaseOrders = [];
  String searchQuery = '';
  String? _selectedLocationCode;
  String? _selectedSupplierName;
  String? get selectedLocationCode => _selectedLocationCode;
  String? get selectedSupplierName => _selectedSupplierName;
  
  // Get unique locations and suppliers from orders
  List<String> get uniqueLocations {
    final locations = _purchaseOrders
        .map((o) => o.locationCode)
        .where((loc) => loc != null && loc.isNotEmpty)
        .toSet()
        .toList();
    locations.sort();
    return locations;
  }
  
  List<String> get uniqueSuppliers {
    final suppliers = _purchaseOrders.map((o) => o.supplierName).toSet().toList();
    suppliers.sort();
    return suppliers;
  }
  
  FlutterDataWedge? dataWedge;
  StreamSubscription? _scanSubscription;
  bool _isScannerActive = false;
  bool _scanCooldown = false;
  int _scanCount = 0;
  bool get isScannerActive => _isScannerActive;
  int get scanCount => _scanCount;
  String? _scannedBarcode;
  String? get scannedBarcode => _scannedBarcode;
  bool isValidForPosting = true;
  String validationMessage = '';

  void setLocationFilter(String? locationCode) {
    _selectedLocationCode = locationCode;
    applyFilters();
  }

  void setSupplierFilter(String? supplierName) {
    _selectedSupplierName = supplierName;
    applyFilters();
  }

  void clearFilters({bool notify = true}) {
    _selectedLocationCode = null;
    _selectedSupplierName = null;
    searchQuery = '';
    if (notify) {
      applyFilters();
    } else {
      // Just update filtered list without notifying listeners
      filteredPurchaseOrders = _purchaseOrders;
    }
  }

  void searchPurchaseOrders(String query) {
    searchQuery = query;
    applyFilters();
  }

  void applyFilters() {
    filteredPurchaseOrders = _purchaseOrders.where((order) {
      // Filter by PO# if search query is provided
      if (searchQuery.isNotEmpty) {
        if (!order.poNumber.toLowerCase().contains(searchQuery.toLowerCase())) {
          return false;
        }
      }
      
      // Filter by location if selected
      if (_selectedLocationCode != null && _selectedLocationCode!.isNotEmpty) {
        if (order.locationCode != _selectedLocationCode) {
          return false;
        }
      }
      
      // Filter by supplier if selected
      if (_selectedSupplierName != null && _selectedSupplierName!.isNotEmpty) {
        if (order.supplierName != _selectedSupplierName) {
          return false;
        }
      }
      
      return true;
    }).toList();
    notifyListeners();
  }

  Future<void> fetchPurchaseOrders() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _sqlConnection.getData("""
      SELECT * FROM VW_DM_PODetails
      ORDER BY SODate DESC
      """);

      final data = jsonDecode(result) as List;

      // Create a map to group orders by PO number
      final ordersMap = <String, PurchaseOrder>{};

      for (var json in data) {
        final poNumber = json['PONumber'].toString();

        if (!ordersMap.containsKey(poNumber)) {
          // Create new order with first item
          ordersMap[poNumber] = PurchaseOrder.fromJson(json);
        } else {
          // Add item to existing order
          ordersMap[poNumber]!.addItem(json);
        }
      }

      // Convert map values to list
      _purchaseOrders = ordersMap.values.toList();
      applyFilters();
    } catch (e) {
      _error = 'Failed to fetch orders: ${e.toString()}';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> initializeScanner() async {
    try {
      setLoading(true);

      if (dataWedge == null) {
        dataWedge = FlutterDataWedge();
        await dataWedge!.initialize();
        await dataWedge!.createDefaultProfile(profileName: "DefaultProfile");
        debugPrint("Scanner initialized");
      }

      setLoading(false);
    } catch (e, stackTrace) {
      setLoading(false);
      debugPrint("Failed to initialize scanner: $e");
      await TelegramLogger.sendLog("❌ [PurchaseOrderProvider] Failed to initialize scanner\nError: $e\nStack: $stackTrace");
      // setErrorMessage("Scanner initialization failed. Please try again.");
      rethrow;
    }
  }

  void clearScannedBarcode() {
    _scannedBarcode = null;
    notifyListeners();
  }

  Future<void> startScanning() async {
    try {
      notifyListeners();

      if (dataWedge == null) {
        await initializeScanner();
      }

      await dataWedge?.activateScanner(true);
      _scanSubscription?.cancel();

      _scanSubscription = dataWedge!.onScanResult.listen((result) async {
        if (_scanCooldown) return;

        final barcode = result.data.trim();
        if (barcode.isEmpty) return;

        _scanCount++;
        _scannedBarcode = barcode; // Store the scanned barcode

        notifyListeners();
        debugPrint('Scanned barcode: $barcode');

        // Add cooldown to prevent multiple scans
        _scanCooldown = true;
        Future.delayed(const Duration(milliseconds: 500), () {
          _scanCooldown = false;
        });
      });

      _isScannerActive = true;
      notifyListeners();
      debugPrint('Scanner started');
    } catch (e, stackTrace) {
      debugPrint('Error starting scanner: $e');
      await TelegramLogger.sendLog("❌ [PurchaseOrderProvider] Error starting scanner\nError: $e\nStack: $stackTrace");
      await stopScanner();
      rethrow;
    }
  }

  Future<void> stopScanner() async {
    try {
      await dataWedge?.activateScanner(false);
      _scanSubscription?.cancel();
      _scanSubscription = null;
      _isScannerActive = false;
      debugPrint('Scanner stopped');
    } catch (e, stackTrace) {
      debugPrint("Failed to stop scanner: $e");
      await TelegramLogger.sendLog("❌ [PurchaseOrderProvider] Failed to stop scanner\nError: $e\nStack: $stackTrace");
      rethrow;
    } finally {
      // notifyListeners();
    }
  }

  Future<List<PurchaseOrder>> getPurchaseOrdersByLocation(
      String locationCode) async {
    try {
      final result = await _sqlConnection.getData("""
        SELECT * FROM VW_DM_PODetails 
        WHERE loccode = '${_escapeSqlString(locationCode)}'
        ORDER BY SODate DESC
      """);

      final data = jsonDecode(result) as List;
      return data.map((json) => PurchaseOrder.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch orders: ${e.toString()}');
    }
  }

  // Helper function to escape SQL strings (replace single quotes with double single quotes)
  String _escapeSqlString(String? value) {
    if (value == null) return '';
    return value.replaceAll("'", "''");
  }

  Future<void> postGoodsReceipt(BuildContext context, String poNumber) async {
    validationMessage = "";
    isValidForPosting = true;
    setLoading(true);
    final order = getPurchaseOrderById(poNumber);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final String companyCode = prefs.getString('companyCode') ?? "";
    final String username = prefs.getString("username") ?? "";
    final String locationCode = prefs.getString('location') ?? "";

    if (order == null) {
      setLoading(false);
      final errorMsg = "Order not found for PO: $poNumber";
      print('ERROR: $errorMsg');
      await TelegramLogger.sendLog(
        "❌ [PurchaseOrderProvider] postGoodsReceipt - Order Not Found\n"
        "PO Number: $poNumber\n"
        "Company Code: $companyCode\n"
        "Location Code: $locationCode\n"
        "Username: $username\n"
        "Timestamp: ${DateTime.now().toIso8601String()}"
      );
      AppAlerts.appToast(message: errorMsg);
      return;
    }

    // Filter items to only those with qtyReceived > 0 for validation
    final itemsToProcess = order.items.where((item) => item.qtyReceived > 0).toList();

    // Validate each item's quantities (only for items with qtyReceived > 0)
    for (var item in itemsToProcess) {
      // Check if qty received is <= qty ordered (but not greater)
      if (item.qtyReceived > item.qtyOrdered) {
        isValidForPosting = false;
        validationMessage +=
        'Quantity received cannot exceed quantity ordered for ${item.itemCode} - ${item.itemName}. Received: ${item.qtyReceived}, Ordered: ${item.qtyOrdered}\n';
      }

      // Check serial numbers for serialized items
      if (item.serialYN && (item.qtyReceived > 0)) {
        if (item.serials.length != item.qtyReceived) {
          isValidForPosting = false;
          validationMessage +=
          'Serial numbers required for ${item.itemCode} - ${item.itemName}. Expected: ${item.qtyReceived}, Provided: ${item.serials.length}\n';
        }

        // Check for duplicate serial numbers in the database (ItemCode + SerialNo combination)
        for (var serial in item.serials) {
          final checkSerialQuery = '''
        SELECT COUNT(*) as count FROM GrnDetailSerials 
        WHERE CmpyCode = '${_escapeSqlString(companyCode)}' AND ItemCode = '${_escapeSqlString(item.itemCode)}' AND SerialNo = '${_escapeSqlString(serial.serialNo)}'
      ''';

          final resultString = await _sqlConnection.getData(checkSerialQuery);
          final count = int.tryParse(resultString) ?? 0;
          if (count > 0) {
            isValidForPosting = false;
            validationMessage +=
            'Serial number ${serial.serialNo} already exists for item ${item.itemCode} in the system\n';
          }
        }
      }
    }

    // If validation fails, show error message and return
    if (!isValidForPosting) {
      setLoading(false);
      final errorMsg = "GRN validation failed: \n $validationMessage";
      print('ERROR: $errorMsg');
      await TelegramLogger.sendLog(
        "❌ [PurchaseOrderProvider] postGoodsReceipt - Validation Failed\n"
        "PO Number: $poNumber\n"
        "Company Code: $companyCode\n"
        "Location Code: $locationCode\n"
        "Username: $username\n"
        "Validation Errors:\n$validationMessage\n"
        "Timestamp: ${DateTime.now().toIso8601String()}"
      );
      AppAlerts.appToast(message: errorMsg);
      return;
    }

    // Check if there are any items with qtyReceived > 0 to process
    if (itemsToProcess.isEmpty) {
      setLoading(false);
      final errorMsg = "No items with quantity received to process";
      print('ERROR: $errorMsg');
      await TelegramLogger.sendLog(
        "❌ [PurchaseOrderProvider] postGoodsReceipt - No Items to Process\n"
        "PO Number: $poNumber\n"
        "Company Code: $companyCode\n"
        "Location Code: $locationCode\n"
        "Username: $username\n"
        "Total Items in Order: ${order.items.length}\n"
        "Items with qtyReceived > 0: ${itemsToProcess.length}\n"
        "Timestamp: ${DateTime.now().toIso8601String()}"
      );
      AppAlerts.appToast(message: errorMsg);
      return;
    }

    try {
      // 1. Get the next GRN number and increment it if necessary
      String nextGrnNumber = await getNextGrnNumber();

      // 2. Create GRNHeader
      final grnHeader = {
        'CmpyCode': companyCode,
        'GrnNumber': nextGrnNumber,
        'LocCode': locationCode,
        'Dates': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'SupplierCode': order.supplierCode,
        'RefNo': order.refNo.toString() == "null"?"":order.refNo.toString(),
        'InvStat': 'N', // Not invoiced
        'Status': 'O', // Open status
        'CurCode': 'AED',
        'ExRate': 1,
        'Discount': 0,
        'GrnType': 'P', // Goods receipt type
        'Qty':
        itemsToProcess.fold(0.0, (double sum, item) => sum + item.qtyReceived),
        'DTime':
        '${TimeOfDay.now().hour.toString().padLeft(2, '0')}:${TimeOfDay.now().minute.toString().padLeft(2, '0')}:00',
        'LoginUser': username,
        'MType': 'P', // Purchase type
        'GrnType1': null
      };

      // Post header
      final headerQuery = '''
  INSERT INTO GrnHeader (
    CmpyCode, GrnNumber, LocCode, Dates, SupplierCode, RefNo, InvStat, 
    Status, CurCode, ExRate, Discount, GrnType, Qty, DTime, LoginUser, 
    MType, GrnType1
  ) VALUES (
    '${_escapeSqlString(grnHeader['CmpyCode']?.toString())}', 
    '${_escapeSqlString(grnHeader['GrnNumber']?.toString())}', 
    '${_escapeSqlString(grnHeader['LocCode']?.toString())}', 
    CONVERT(DATETIME, '${_escapeSqlString(grnHeader['Dates']?.toString())}', 120), 
    '${_escapeSqlString(grnHeader['SupplierCode']?.toString())}', 
    '${_escapeSqlString(grnHeader['RefNo'].toString() == "null" ? "" : grnHeader['RefNo'].toString())}', 
    '${_escapeSqlString(grnHeader['InvStat']?.toString())}', 
    '${_escapeSqlString(grnHeader['Status']?.toString())}', 
    '${_escapeSqlString(grnHeader['CurCode']?.toString())}', 
    ${grnHeader['ExRate']}, 
    ${grnHeader['Discount']}, 
    '${_escapeSqlString(grnHeader['GrnType']?.toString())}', 
    ${grnHeader['Qty']}, 
    '${_escapeSqlString(grnHeader['DTime']?.toString())}', 
    '${_escapeSqlString(grnHeader['LoginUser']?.toString())}', 
    '${_escapeSqlString(grnHeader['MType']?.toString())}', 
    ${grnHeader['GrnType1'] != null ? "'${_escapeSqlString(grnHeader['GrnType1'].toString())}'" : 'NULL'}
  )
  ''';

      print('Posting GRN header with number: $nextGrnNumber...');
      await _sqlConnection.writeData(headerQuery);
      print('Header posted successfully with GRN: $nextGrnNumber');

      // 3. Create and post GRNDetails for each item with qtyReceived > 0
      int bsno = 1;
      int globalSerialSno = 1; // Global counter for serial numbers across all items

      for (var item in itemsToProcess) {
        final detail = {
          'CmpyCode': companyCode,
          'GrnNumber': nextGrnNumber,
          'LocCode': locationCode,
          'Sno': bsno, // bsno is same as sno
          'ItemCode': item.itemCode,
          'Barcode': null,
          'Description': item.itemName,
          'Unit': item.unit,
          'QtyOrdered': item.qtyOrdered,
          'QtyReceived': item.qtyReceived,
          'QtyFree': 0,
          'UnitPrice': item.unitPrice.precised(),
          'GrossTotal':
          ((item.unitPrice).precised() * (item.qtyReceived).precised())
              .precised(),
          'AvgCost': 0,
          'ProjectCode': null,
          'AnalysisCode': null,
          'SrNo': bsno,
          'PoNumber': order.poNumber,
          'DiscountP': 0,
          'Discount': 0,
          'NetAmount': 0,
          'NetPurchase': 0,
          'Bsno': bsno,
          'TaxCode': null,
          'TaxPercentage': 0,
          'BinCode': null
        };

        final detailQuery = '''
    INSERT INTO GrnDetail (
      CmpyCode, GrnNumber, LocCode, Sno, ItemCode, Barcode, Description, 
      Unit, QtyOrdered, QtyReceived, QtyFree, UnitPrice, GrossTotal, 
      AvgCost, ProjectCode, AnalysisCode, SrNo, PoNumber, DiscountP, 
      Discount, NetAmount, NetPurchase, Bsno, TaxCode, TaxPercentage, BinCode
    ) VALUES (
      '${_escapeSqlString(detail['CmpyCode']?.toString())}', 
      '${_escapeSqlString(detail['GrnNumber']?.toString())}', 
      '${_escapeSqlString(detail['LocCode']?.toString())}', 
      ${detail['Sno']}, 
      '${_escapeSqlString(detail['ItemCode']?.toString())}', 
      ${detail['Barcode'] != null ? "'${_escapeSqlString(detail['Barcode'].toString())}'" : 'NULL'}, 
      '${_escapeSqlString(detail['Description']?.toString())}',
      '${_escapeSqlString(detail['Unit']?.toString())}', 
      ${detail['QtyOrdered']}, 
      ${detail['QtyReceived']}, 
      ${detail['QtyFree']}, 
      ${detail['UnitPrice']}, 
      ${detail['GrossTotal']}, 
      ${detail['AvgCost']}, 
      ${detail['ProjectCode'] != null ? "'${_escapeSqlString(detail['ProjectCode'].toString())}'" : 'NULL'}, 
      ${detail['AnalysisCode'] != null ? "'${_escapeSqlString(detail['AnalysisCode'].toString())}'" : 'NULL'}, 
      ${detail['SrNo'] != null ? "'${_escapeSqlString(detail['SrNo'].toString())}'" : 'NULL'}, 
      '${_escapeSqlString(detail['PoNumber']?.toString())}', 
      ${detail['DiscountP']},
      ${detail['Discount']}, 
      ${detail['NetAmount']}, 
      ${detail['NetPurchase']}, 
      ${detail['Bsno'] != null ? "'${_escapeSqlString(detail['Bsno'].toString())}'" : 'NULL'}, 
      ${detail['TaxCode'] != null ? "'${_escapeSqlString(detail['TaxCode'].toString())}'" : 'NULL'}, 
      ${detail['TaxPercentage']},
      ${detail['BinCode'] != null ? "'${_escapeSqlString(detail['BinCode'].toString())}'" : 'NULL'}
    )
    ''';

        print('Posting detail for item ${item.itemCode}...');
        await _sqlConnection.writeData(detailQuery);
        print('Detail posted for item ${item.itemCode}');

        // Update SoDetail table with issued quantity
        final updateSoDetailQuery = '''
      UPDATE PoDetail 
      SET QtyReceived = QtyReceived + ${item.qtyReceived}, 
          SrNo = '${_escapeSqlString(bsno.toString())}'
      WHERE CmpyCode = '${_escapeSqlString(order.companyCode)}' 
        AND PoNumber = '${_escapeSqlString(order.poNumber)}' 
        AND ItemCode = '${_escapeSqlString(item.itemCode)}' 
    ''';

        print('Updating SoDetail for item ${item.itemCode}...');
        await _sqlConnection.writeData(updateSoDetailQuery);
        print('SoDetail updated for item ${item.itemCode}');

        // 4. Post serial numbers if item is serialized with continuous Sno across all items
        if (item.serialYN && item.serials.isNotEmpty) {
          final values = <String>[];

          for (var serial in item.serials) {
            final value = '''
    ('${_escapeSqlString(companyCode)}', 
     '${_escapeSqlString(nextGrnNumber)}', 
     '', 
     '${_escapeSqlString(globalSerialSno.toString())}', 
     '${_escapeSqlString(item.itemCode)}', 
     '${_escapeSqlString(serial.serialNo)}', 
     '${_escapeSqlString(bsno.toString())}', 
     'P', 
     ${false ? 1 : 0})
  ''';
            values.add(value);
            globalSerialSno++; // Increment global serial counter
          }

          final batchQuery = '''
  INSERT INTO GrnDetailSerials (
    CmpyCode, GrnNumber, VbNumber, Sno, ItemCode, SerialNo, SrNo, DocType, ReturnYN
  ) VALUES 
  ${values.join(', ')}
''';

          print('Posting ${item.serials.length} GRN serials...');
          await _sqlConnection.writeData(batchQuery);
          print('All GRN serials posted');
        }

        bsno++; // Increment bsno for next item
      }

      // Update PO status based on whether it's fully received (considering all items in the order)
      bool isFullyReceived = true;
      for (var item in order.items) {
        if (item.qtyReceived < item.qtyOrdered) {
          isFullyReceived = false;
          break;
        }
      }

      // Always set GRNStat = 'Y' when creating GRN against PO (regardless of quantity)
      // Set Status = 'C' only when fully received
      final updatePoQuery = '''
    UPDATE PoHeader 
    SET Status = '${isFullyReceived ? 'C' : 'O'}', 
        GRNStat = 'Y'
    WHERE PoNumber = '${_escapeSqlString(order.poNumber)}' AND CmpyCode = '${_escapeSqlString(order.companyCode)}'
    ''';

      print('Updating PO status...');
      await _sqlConnection.writeData(updatePoQuery);
      print('PO status updated');

      Navigator.pop(context);
      fetchPurchaseOrders();

      AppAlerts.appToast(message: "GRN $nextGrnNumber posted successfully");
    } catch (e, stackTrace) {
      setLoading(false);
      final errorMsg = "Failed to post GRN: ${e.toString()}";
      print('ERROR in postGoodsReceipt:');
      print('Message: $e');
      print('Stack trace: $stackTrace');
      
      // Build detailed error log
      String errorDetails = "❌ [PurchaseOrderProvider] postGoodsReceipt - Exception\n"
          "PO Number: $poNumber\n"
          "Company Code: $companyCode\n"
          "Location Code: $locationCode\n"
          "Username: $username\n"
          "Error Type: ${e.runtimeType}\n"
          "Error Message: $e\n"
          "Stack Trace:\n$stackTrace\n";
      
      // Add order details if available
      if (order != null) {
        errorDetails += "Order Details:\n"
            "  Supplier: ${order.supplierName}\n"
            "  Items Count: ${order.items.length}\n"
            "  Items to Process: ${itemsToProcess.length}\n";
        
        // Add item details
        if (itemsToProcess.isNotEmpty) {
          errorDetails += "  Items:\n";
          for (var item in itemsToProcess) {
            errorDetails += "    - ${item.itemCode} (${item.itemName}): "
                "Ordered: ${item.qtyOrdered}, Received: ${item.qtyReceived}, "
                "Serialized: ${item.serialYN}\n";
          }
        }
      }
      
      errorDetails += "Timestamp: ${DateTime.now().toIso8601String()}";
      
      await TelegramLogger.sendLog(errorDetails);
      AppAlerts.appToast(message: errorMsg);
    } finally {
      setLoading(false);
    }
  }

  Future<String> getNextGrnNumber() async {
    final query = '''
    SELECT GrnNumber 
    FROM GrnHeader 
    WHERE GrnNumber LIKE 'AGRN%'
  ''';

    final result = await _sqlConnection.getData(query);
    final resultJson = jsonDecode(result);

    if (resultJson.isEmpty) {
      return 'AGRN00001';
    } else {
      // Extract all GRN numbers and parse their numeric parts
      final grnNumbers = resultJson
          .map<String>((item) => item['GrnNumber'] as String)
          .toList();

      // Find the maximum number
      int maxNumber = 0;
      for (final grn in grnNumbers) {
        final number = int.tryParse(grn.replaceAll('AGRN', '')) ?? 0;
        if (number > maxNumber) {
          maxNumber = number;
        }
      }

      final nextNumber = maxNumber + 1;
      return 'AGRN${nextNumber.toString().padLeft(5, '0')}';
    }
  }

  PurchaseOrder? getPurchaseOrderById(String poNumber) {
    try {
      return _purchaseOrders.firstWhere((order) => order.poNumber == poNumber);
    } catch (e) {
      return null;
    }
  }

  Future<bool> isSerialUnique({
    required String serialNo,
    required String itemCode,
  }) async {
    try {
      // 1. Check current orders (only for matching itemCode)
      for (var order in purchaseOrders) {
        for (var item in order.items) {
          if (item.itemCode == itemCode && item.hasSerial(serialNo)) {
            return false;
          }
        }
      }

      // 2. Get company code from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final String companyCode = prefs.getString('companyCode') ?? "";

      // 3. DATABASE CHECK - Check for ItemCode + SerialNo combination within the same company
      final result = await _sqlConnection.getData(
          "SELECT TOP 1 1 FROM GrnDetailSerials "
          "WHERE CmpyCode = '${_escapeSqlString(companyCode)}' AND ItemCode = '${_escapeSqlString(itemCode)}' AND SerialNo = '${_escapeSqlString(serialNo)}'");

      return result.isEmpty || result == "[]";
    } catch (e) {
      print('Error checking serial uniqueness: $e');
      return false; // Fail-safe
    }
  }

  Future<void> addSerialToItem({
    required String poNumber,
    required String itemCode,
    required String serialNo,
  }) async {
    try {
      final order = getPurchaseOrderById(poNumber);
      if (order == null) throw Exception('Order not found');

      final item = order.items.firstWhere(
        (i) => i.itemCode == itemCode,
        orElse: () => throw Exception('Item not found'),
      );

      // Check if serial exists for this item in database or current order
      final isUnique =
          await isSerialUnique(itemCode: itemCode, serialNo: serialNo);
      if (!isUnique) {
        return AppAlerts.appToast(
            message: 'Serial number $serialNo already exists for item $itemCode');
      }

      if (item.qtyReceived >= item.qtyOrdered) {
        return AppAlerts.appToast(
            message:
                'Cannot add serial - would exceed Qty ordered (${item.qtyOrdered})');
      }

      item.qtyReceived++;
      item.addSerial(serialNo);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  void removeSerialFromItem({
    required String poNumber,
    required String itemCode,
    required String serialNo,
  }) {
    try {
      final order = getPurchaseOrderById(poNumber);
      if (order == null) throw Exception('Order not found');

      final item = order.items.firstWhere(
            (i) => i.itemCode == itemCode,
        orElse: () => throw Exception('Item not found'),
      );

      // Check if serial exists
      if (!item.hasSerial(serialNo)) {
        throw Exception('Serial number not found');
      }

      // Remove the serial (this also updates the set and recalculates positions)
      item.removeSerial(serialNo);

      // Decrement the quantity received
      item.qtyReceived -= 1;

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to remove serial: ${e.toString()}');
    }
  }

  resetQtyRecieved(
      {
        required String poNumber,
        required String itemCode,
      }
      ){
    final order = getPurchaseOrderById(poNumber);
    if (order == null) throw Exception('Order not found');
    final item = order.items.firstWhere(
          (i) => i.itemCode == itemCode,
      orElse: () => throw Exception('Item not found'),
    );
    item.qtyReceived = 287;
  }

  // Add this method to your OrderProvider class
  bool hasDuplicateSerialsInItem({
    required String poNumber,
    required String itemCode,
  }) {
    final order = getPurchaseOrderById(poNumber);
    if (order == null) return false;

    final item = order.items.firstWhere(
          (i) => i.itemCode == itemCode,
      orElse: () => throw Exception('Item not found'),
    );

    final serialNumbers = item.serials.map((s) => s.serialNo).toList();
    final uniqueSerialNumbers = serialNumbers.toSet();

    return serialNumbers.length != uniqueSerialNumbers.length;
  }

  // Modify this method to return a map with serial numbers and their positions
  Map<String, List<int>> getDuplicateSerialsWithPositions({
    required String poNumber,
    required String itemCode,
  }) {
    final order = getPurchaseOrderById(poNumber);
    if (order == null) return {};

    final item = order.items.firstWhere(
          (i) => i.itemCode == itemCode,
      orElse: () => throw Exception('Item not found'),
    );

    final serialNumbers = item.serials.map((s) => s.serialNo).toList();
    final serialPositions = <String, List<int>>{};

    // Track positions of each serial number
    for (int i = 0; i < serialNumbers.length; i++) {
      final serial = serialNumbers[i];
      if (!serialPositions.containsKey(serial)) {
        serialPositions[serial] = [];
      }
      serialPositions[serial]!.add(i + 1); // +1 to make it 1-based index
    }

    // Return only duplicates (serial numbers that appear more than once)
    return serialPositions..removeWhere((key, value) => value.length <= 1);
  }

  void resetValidation() {
    isValidForPosting = true;
    validationMessage = '';
    notifyListeners();
  }

  // Method to clear all item serials for a specific purchase order
  void clearAllItemSerials(String poNumber) {
    final order = getPurchaseOrderById(poNumber);
    if (order == null) return;

    for (var item in order.items) {
      item.clearSerials();
      item.qtyReceived = 0;
    }
    notifyListeners();
  }

  // Method to update item quantity directly via text field
  void updateItemQuantity(String poNumber, String itemCode, double newQuantity) {
    final order = getPurchaseOrderById(poNumber);
    if (order == null) return;

    final item = order.items.firstWhere(
      (i) => i.itemCode == itemCode,
      orElse: () => throw Exception('Item not found'),
    );
    
    // Validate the new quantity
    if (newQuantity < 0) {
      AppAlerts.appToast(message: 'Quantity cannot be negative');
      return;
    }
    
    if (newQuantity > item.qtyOrdered) {
      AppAlerts.appToast(message: 'Cannot exceed ordered quantity (${item.qtyOrdered})');
      return;
    }
    
    item.qtyReceived = newQuantity;
    notifyListeners();
  }
}
