import 'dart:async';
import 'dart:convert';

import 'package:delivery_note_app/models/delivery_note_details.dart';
import 'package:delivery_note_app/models/delivery_note_header.dart';
import 'package:delivery_note_app/models/inventory_detail_serialno.dart';
import 'package:delivery_note_app/utils/app_alerts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_datawedge/flutter_datawedge.dart';
import 'package:intl/intl.dart';
import 'package:mssql_connection/mssql_connection.dart';
import 'package:delivery_note_app/models/sales_order_model.dart';
import 'package:delivery_note_app/services/telegram_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderProvider with ChangeNotifier {
  final MssqlConnection _sqlConnection = MssqlConnection.getInstance();
  String? _error;
  List<SalesOrder> _salesOrders = [];
  List<SalesOrder> get salesOrders => _salesOrders;
  List<SalesOrder> filteredSalesOrders = [];
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String searchQuery = '';
  String? _selectedLocationCode;
  String? _selectedCustomerName;
  String? get selectedLocationCode => _selectedLocationCode;
  String? get selectedCustomerName => _selectedCustomerName;
  
  // Get unique locations and customers from orders
  List<String> get uniqueLocations {
    final locations = _salesOrders
        .map((o) => o.locationCode)
        .where((loc) => loc != null && loc.isNotEmpty)
        .toSet()
        .toList();
    locations.sort();
    return locations;
  }
  
  List<String> get uniqueCustomers {
    final customers = _salesOrders.map((o) => o.customerName).toSet().toList();
    customers.sort();
    return customers;
  }
  
  bool isValidForPosting = true;
  String validationMessage = '';
  FlutterDataWedge? dataWedge;
  StreamSubscription? _scanSubscription;
  bool _isScannerActive = false;
  bool _scanCooldown = false;
  int _scanCount = 0;
  bool get isScannerActive => _isScannerActive;
  int get scanCount => _scanCount;
  String? _scannedBarcode;
  String? get scannedBarcode => _scannedBarcode;

  Future<void> fetchSalesOrders() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _sqlConnection.getData("""
      SELECT 
        *,
        QtyOrdered AS QtyRemain
      FROM VW_DM_SODetails
      ORDER BY SODate DESC
      """);

      final data = jsonDecode(result) as List;

      final ordersMap = <String, SalesOrder>{};

      for (var json in data) {
        final soNumber = json['SoNumber'].toString();

        if (!ordersMap.containsKey(soNumber)) {
          ordersMap[soNumber] = SalesOrder.fromJson(json);
        } else {
          ordersMap[soNumber]!.addItem(json);
        }
      }

      _salesOrders = ordersMap.values.toList();
      applyFilters();
    } catch (e) {
      _error = 'Failed to fetch orders: ${e.toString()}';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setLocationFilter(String? locationCode) {
    _selectedLocationCode = locationCode;
    applyFilters();
  }

  void setCustomerFilter(String? customerName) {
    _selectedCustomerName = customerName;
    applyFilters();
  }

  void clearFilters({bool notify = true}) {
    _selectedLocationCode = null;
    _selectedCustomerName = null;
    searchQuery = '';
    if (notify) {
      applyFilters();
    } else {
      // Just update filtered list without notifying listeners
      filteredSalesOrders = _salesOrders;
    }
  }

  void searchSalesOrders(String query) {
    searchQuery = query;
    applyFilters();
  }

  void applyFilters() {
    filteredSalesOrders = _salesOrders.where((order) {
      // Filter by SO# if search query is provided
      if (searchQuery.isNotEmpty) {
        if (!order.soNumber.toLowerCase().contains(searchQuery.toLowerCase())) {
          return false;
        }
      }
      
      // Filter by location if selected
      if (_selectedLocationCode != null && _selectedLocationCode!.isNotEmpty) {
        if (order.locationCode != _selectedLocationCode) {
          return false;
        }
      }
      
      // Filter by customer if selected
      if (_selectedCustomerName != null && _selectedCustomerName!.isNotEmpty) {
        if (order.customerName != _selectedCustomerName) {
          return false;
        }
      }
      
      return true;
    }).toList();
    notifyListeners();
  }

  Future<void> fetchSalesOrderDetails(String soNumber) async {
    try {
      _isLoading = true;
      notifyListeners();

      final result = await _sqlConnection.getData("""
      SELECT * FROM VW_DM_SODetails_Items 
      WHERE SoNumber = '${_escapeSqlString(soNumber)}'
      ORDER BY Sno
      """);

      final data = jsonDecode(result) as List;

      // Find existing order or create new one
      SalesOrder? order = getSalesOrderById(soNumber);
      if (order == null) {
        // If order not found in list, fetch header details
        final headerResult = await _sqlConnection.getData("""
        SELECT TOP 1 * FROM VW_DM_SODetails 
        WHERE SoNumber = '${_escapeSqlString(soNumber)}'
        """);

        final headerData = jsonDecode(headerResult) as List;
        if (headerData.isEmpty) throw Exception('Order not found');

        order = SalesOrder.fromJson(headerData.first);
        _salesOrders.add(order);
      }

      // Clear existing items and add new ones
      order.items.clear();
      for (var json in data) {
        order.addItem(json);
      }

      notifyListeners();
    } catch (e) {
      _error = 'Failed to fetch order details: ${e.toString()}';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Helper function to escape SQL strings (replace single quotes with double single quotes)
  String _escapeSqlString(String? value) {
    if (value == null) return '';
    return value.replaceAll("'", "''");
  }

  Future<List<SalesOrder>> getSalesOrdersByLocation(String locationCode) async {
    try {
      final result = await _sqlConnection.getData("""
        SELECT * FROM VW_DM_SODetails 
        WHERE LocCode = '${_escapeSqlString(locationCode)}'
        ORDER BY SODate DESC
      """);

      final data = jsonDecode(result) as List;
      return data.map((json) => SalesOrder.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch orders: ${e.toString()}');
    }
  }

  Future<void> postDeliveryNote(BuildContext context, String soNumber) async {
    validationMessage = "";
    isValidForPosting = true;
    setLoading(true);
    final order = getSalesOrderById(soNumber);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final String companyCode = prefs.getString('companyCode') ?? "";
    final String username = prefs.getString("username") ?? "";
    final String locationCode = prefs.getString('location') ?? "";

    if (order == null) {
      setLoading(false);
      final errorMsg = "Order not found for SO: $soNumber";
      print('ERROR: $errorMsg');
      await TelegramLogger.sendLog(
        "❌ [OrderProvider] postDeliveryNote - Order Not Found\n"
        "SO Number: $soNumber\n"
        "Company Code: $companyCode\n"
        "Location Code: $locationCode\n"
        "Username: $username\n"
        "Timestamp: ${DateTime.now().toIso8601String()}"
      );
      AppAlerts.appToast(message: "Order not found for SO: $soNumber");
      return;
    }

    // Filter items to only those with qtyIssued > 0 for validation
    final itemsToProcess =
    order.items.where((item) => item.qtyIssued > 0).toList();

    // Validate each item's stock and quantities (only for items with qtyIssued > 0)
    for (var item in itemsToProcess) {
      if (!item.nonInventory) {
        if (item.stockQty < item.qtyIssued) {
          isValidForPosting = false;
          validationMessage +=
          'Insufficient stock for ${item.itemCode} - ${item.itemName}. Available: ${item.stockQty}, Issued: ${item.qtyIssued}\n';
        }
      }

      if (item.qtyIssued > item.qtyOrdered) {
        isValidForPosting = false;
        validationMessage +=
        'Quantity issued cannot exceed quantity ordered for ${item.itemCode} - ${item.itemName}. Issued: ${item.qtyIssued}, Ordered: ${item.qtyOrdered}\n';
      }

      if (item.serialYN && (item.qtyIssued > 0)) {
        if (item.serials.length != item.qtyIssued) {
          isValidForPosting = false;
          validationMessage +=
          'Serial numbers required for ${item.itemCode} - ${item.itemName}. Expected: ${item.qtyOrdered}, Provided: ${item.serials.length}\n';
        }

        // Check for duplicate serial numbers in the database (ItemCode + SerialNo combination)
        for (var serial in item.serials) {
          final checkSerialQuery = '''
        SELECT COUNT(*) as count FROM InvDetailSerials 
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

    if (!isValidForPosting) {
      setLoading(false);
      final errorMsg = "Delivery note validation failed: \n $validationMessage";
      print('ERROR: $errorMsg');
      await TelegramLogger.sendLog(
        "❌ [OrderProvider] postDeliveryNote - Validation Failed\n"
        "SO Number: $soNumber\n"
        "Company Code: $companyCode\n"
        "Location Code: $locationCode\n"
        "Username: $username\n"
        "Validation Errors:\n$validationMessage\n"
        "Timestamp: ${DateTime.now().toIso8601String()}"
      );
      AppAlerts.appToast(message: errorMsg);
      return;
    }

    // Check if there are any items with qtyIssued > 0 to process
    if (itemsToProcess.isEmpty) {
      setLoading(false);
      final errorMsg = "No items with quantity issued to process";
      print('ERROR: $errorMsg');
      await TelegramLogger.sendLog(
        "❌ [OrderProvider] postDeliveryNote - No Items to Process\n"
        "SO Number: $soNumber\n"
        "Company Code: $companyCode\n"
        "Location Code: $locationCode\n"
        "Username: $username\n"
        "Total Items in Order: ${order.items.length}\n"
        "Items with qtyIssued > 0: ${itemsToProcess.length}\n"
        "Timestamp: ${DateTime.now().toIso8601String()}"
      );
      AppAlerts.appToast(message: errorMsg);
      return;
    }

    try {
      String nextDnNumber = await _getNextDnNumber();

      final deliveryNoteHeader = DeliveryNoteHeader(
        cmpyCode: order.companyCode,
        dnNumber: nextDnNumber,
        locCode: locationCode,
        dates: DateTime.now(),
        customerCode: order.customerCode,
        salesmanCode: order.salesmanCode,
        soNumber: order.soNumber,
        refNo: order.refNo.toString() == "null" ? "" : order.refNo.toString(),
        status: 'O',
        invStat: 'N',
        discount: 0,
        curCode: 'AED',
        exRate: 1,
        dnType: 'S',
        qty: itemsToProcess
            .fold(0.0, (double sum, item) => sum + item.qtyIssued)
            .round(),
        dTime: TimeOfDay.now(),
        loginUser: username,
        creditLimitAmount: 0,
        outstandingBalance: 0,
        grossAmount: 0,
        narration: '',
        commissionYN: 'N',
        supplier: '',
        dyType: 'D',
      );

      // Construct time string for SQL
      final timeString = '${deliveryNoteHeader.dTime.hour.toString().padLeft(2, '0')}:${deliveryNoteHeader.dTime.minute.toString().padLeft(2, '0')}:00';

      final headerQuery = '''
    INSERT INTO DNoteHeader (
      Cmpycode, DnNumber, LocCode, Dates, CustomerCode, SalesmanCode, 
      SoNumber, RefNo, Status, InvStat, Discount, CurCode, ExRate, 
      DnType, Qty, DTime, LoginUser, CreditLimitAmount, OutstandingBalance, 
      GrossAmount, Narration, CommissionYN, Supplier, DYType
    ) VALUES (
      '${_escapeSqlString(deliveryNoteHeader.cmpyCode)}', 
      '${_escapeSqlString(deliveryNoteHeader.dnNumber)}', 
      '${_escapeSqlString(deliveryNoteHeader.locCode)}', 
      CONVERT(DATETIME, '${_escapeSqlString(DateFormat('yyyy-MM-dd').format(deliveryNoteHeader.dates))}', 120), 
      '${_escapeSqlString(deliveryNoteHeader.customerCode)}', 
      '${_escapeSqlString(deliveryNoteHeader.salesmanCode)}',
      '${_escapeSqlString(deliveryNoteHeader.soNumber)}', 
      '${_escapeSqlString(deliveryNoteHeader.refNo.toString() == "null" ? "" : deliveryNoteHeader.refNo.toString())}', 
      '${_escapeSqlString(deliveryNoteHeader.status)}', 
      '${_escapeSqlString(deliveryNoteHeader.invStat)}', 
      ${deliveryNoteHeader.discount}, 
      '${_escapeSqlString(deliveryNoteHeader.curCode)}', 
      ${deliveryNoteHeader.exRate},
      '${_escapeSqlString(deliveryNoteHeader.dnType)}', 
      ${deliveryNoteHeader.qty}, 
      CONVERT(TIME, '${_escapeSqlString(timeString)}'), 
      '${_escapeSqlString(deliveryNoteHeader.loginUser)}', 
      ${deliveryNoteHeader.creditLimitAmount}, 
      ${deliveryNoteHeader.outstandingBalance},
      ${deliveryNoteHeader.grossAmount}, 
      '${_escapeSqlString(deliveryNoteHeader.narration)}', 
      '${_escapeSqlString(deliveryNoteHeader.commissionYN)}', 
      '${_escapeSqlString(deliveryNoteHeader.supplier)}', 
      '${_escapeSqlString(deliveryNoteHeader.dyType)}'
    )
    ''';

      print('Posting delivery note header with DN: $nextDnNumber...');
      await _sqlConnection.writeData(headerQuery);
      print('Header posted successfully with DN: $nextDnNumber');

      // Post items with qtyIssued > 0
      int bsno = 1;
      int globalSerialSno = 1; // Global counter for serial numbers across all items

      for (var item in itemsToProcess) {
        final detail = DeliveryNoteDetail(
          cmpyCode: order.companyCode,
          dnNumber: deliveryNoteHeader.dnNumber,
          locCode: locationCode,
          sno: bsno,
          itemCode: item.itemCode,
          barcode: null,
          description: item.itemName,
          unit: item.unit,
          qtyOrdered: item.qtyOrdered,
          qtyIssued: item.qtyIssued,
          unitPrice: 0,
          grossTotal: 0,
          discountP: 0,
          discount: 0,
          closingStock: item.stockQty - item.qtyIssued,
          avgCost: 0,
          srNo: bsno.toString(),
          soNumber: order.soNumber,
          cogsamt: 0,
          nonInventory: item.nonInventory,
          isFreeofCost: false,
          parentItem: null,
          qtyReserved: 0,
          poQty: 0,
          totReservedQty: 0,
          bSno: bsno.toString(),
          soQty: item.qtyOrdered,
          taxCode: null,
          taxPercentage: 0,
          binCode: null,
          commAmount: null,
          commission: null,
        );

        final detailQuery = '''
    INSERT INTO DnoteDetail (
      CmpyCode, DnNumber, LocCode, Sno, ItemCode, Barcode, Description, 
      Unit, QtyOrdered, QtyIssued, UnitPrice, GrossTotal, DiscountP, 
      Discount, ClosingStock, AvgCost, SrNo, SoNumber, cogsamt, 
      NonInventory, IsFreeofCost, ParentItem, QtyReserved, PoQty, 
      TotReservedQty, BSno, SoQty, TaxCode, TaxPercentage, BinCode, 
      CommAmount, Commission
    ) VALUES (
      '${_escapeSqlString(detail.cmpyCode)}', 
      '${_escapeSqlString(detail.dnNumber)}', 
      '${_escapeSqlString(detail.locCode)}', 
      ${detail.sno}, 
      '${_escapeSqlString(detail.itemCode)}', 
      ${detail.barcode != null ? "'${_escapeSqlString(detail.barcode)}'" : 'NULL'}, 
      '${_escapeSqlString(detail.description)}',
      '${_escapeSqlString(detail.unit)}', 
      ${detail.qtyOrdered}, 
      ${detail.qtyIssued}, 
      ${detail.unitPrice}, 
      ${detail.grossTotal}, 
      ${detail.discountP},
      ${detail.discount}, 
      ${detail.closingStock}, 
      ${detail.avgCost}, 
      ${detail.srNo != null ? "'${_escapeSqlString(detail.srNo)}'" : 'NULL'}, 
      '${_escapeSqlString(detail.soNumber)}', 
      ${detail.cogsamt},
      ${detail.nonInventory ? 1 : 0}, 
      ${detail.isFreeofCost ? 1 : 0}, 
      ${detail.parentItem != null ? "'${_escapeSqlString(detail.parentItem)}'" : 'NULL'}, 
      ${detail.qtyReserved}, 
      ${detail.poQty},
      ${detail.totReservedQty}, 
      ${detail.bSno != null ? "'${_escapeSqlString(detail.bSno)}'" : 'NULL'}, 
      ${detail.soQty}, 
      ${detail.taxCode != null ? "'${_escapeSqlString(detail.taxCode)}'" : 'NULL'}, 
      ${detail.taxPercentage},
      ${detail.binCode != null ? "'${_escapeSqlString(detail.binCode)}'" : 'NULL'}, 
      ${detail.commAmount ?? 'NULL'}, 
      ${detail.commission ?? 'NULL'}
    )
    ''';

        print('Posting detail for item ${item.itemCode}...');
        await _sqlConnection.writeData(detailQuery);
        print('Detail posted for item ${item.itemCode}');

        // Update SoDetail table with issued quantity
        final updateSoDetailQuery = '''
      UPDATE SoDetail 
      SET QtyIssued = QtyIssued + ${item.qtyIssued}, 
          SrNo = '${_escapeSqlString(bsno.toString())}'
      WHERE CmpyCode = '${_escapeSqlString(order.companyCode)}' 
        AND SoNumber = '${_escapeSqlString(order.soNumber)}' 
        AND ItemCode = '${_escapeSqlString(item.itemCode)}' 
      ''';

        print('Updating SoDetail for item ${item.itemCode}...');
        await _sqlConnection.writeData(updateSoDetailQuery);
        print('SoDetail updated for item ${item.itemCode}');

        // Post serial numbers with continuous Sno across all items
        if (item.serialYN && item.serials.isNotEmpty) {
          final values = <String>[];

          for (var serial in item.serials) {
            final value = '''
      ('${_escapeSqlString(order.companyCode)}', 
       '${_escapeSqlString(deliveryNoteHeader.dnNumber)}', 
       '${_escapeSqlString(globalSerialSno.toString())}', 
       '${_escapeSqlString(item.itemCode)}', 
       '${_escapeSqlString(serial.serialNo)}', 
       '${_escapeSqlString(bsno.toString())}', 
       '${_escapeSqlString(deliveryNoteHeader.dnNumber)}', 
       ${false ? 1 : 0})
    ''';
            values.add(value);
            globalSerialSno++; // Increment global serial counter
          }

          final batchQuery = '''
    INSERT INTO InvDetailSerials (
      CmpyCode, InvNumber, Sno, ItemCode, SerialNo, SrNo, DnNumber, ReturnYN
    ) VALUES 
    ${values.join(', ')}
  ''';

          print('Posting ${item.serials.length} serials...');
          await _sqlConnection.writeData(batchQuery);
          print('All serials posted');
        }

        bsno++; // Increment bsno for next item
      }

      // Update SO status based on whether it's fully delivered (considering all items in the order)
      bool isFullyDelivered = true;
      for (var item in order.items) {
        if (item.qtyIssued < item.qtyOrdered) {
          isFullyDelivered = false;
          break;
        }
      }

      final updateSoQuery = '''
    UPDATE SoHeader 
    SET Status = '${isFullyDelivered ? 'C' : 'O'}', 
        DelStat = 'Y'
    WHERE SoNumber = '${_escapeSqlString(order.soNumber)}' AND CmpyCode = '${_escapeSqlString(order.companyCode)}'
    ''';

      print('Updating SO status...');
      await _sqlConnection.writeData(updateSoQuery);
      print('SO status updated');

      AppAlerts.appToast(
          message: "Delivery note $nextDnNumber posted successfully",
          bgColor: Colors.green,
          textColor: Colors.white);

      // Refresh the order details
      await fetchSalesOrders();
      Navigator.pop(context);
    } catch (e, stackTrace) {
      setLoading(false);
      final errorMsg = "Failed to post delivery note: ${e.toString()}";
      print('ERROR in postDeliveryNote:');
      print('Message: $e');
      print('Stack trace: $stackTrace');
      
      // Build detailed error log
      String errorDetails = "❌ [OrderProvider] postDeliveryNote - Exception\n"
          "SO Number: $soNumber\n"
          "Company Code: $companyCode\n"
          "Location Code: $locationCode\n"
          "Username: $username\n"
          "Error Type: ${e.runtimeType}\n"
          "Error Message: $e\n"
          "Stack Trace:\n$stackTrace\n";
      
      // Add order details if available
      if (order != null) {
        errorDetails += "Order Details:\n"
            "  Customer: ${order.customerName}\n"
            "  Items Count: ${order.items.length}\n"
            "  Items to Process: ${itemsToProcess.length}\n";
        
        // Add item details
        if (itemsToProcess.isNotEmpty) {
          errorDetails += "  Items:\n";
          for (var item in itemsToProcess) {
            errorDetails += "    - ${item.itemCode} (${item.itemName}): "
                "Ordered: ${item.qtyOrdered}, Issued: ${item.qtyIssued}, "
                "Stock: ${item.stockQty}, Serialized: ${item.serialYN}\n";
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

  Future<String> _getNextDnNumber() async {
    final query = '''
    SELECT DnNumber 
    FROM DNoteHeader 
    WHERE DnNumber LIKE 'ADN%'
  ''';

    final result = await _sqlConnection.getData(query);
    final resultJson = jsonDecode(result);

    if (resultJson.isEmpty) {
      return 'ADN000001';
    } else {
      // Extract all DN numbers and parse their numeric parts
      final dnNumbers =
          resultJson.map<String>((item) => item['DnNumber'] as String).toList();

      // Find the maximum number
      int maxNumber = 0;
      for (final dn in dnNumbers) {
        final number = int.tryParse(dn.replaceAll('ADN', '')) ?? 0;
        if (number > maxNumber) {
          maxNumber = number;
        }
      }

      final nextNumber = maxNumber + 1;
      return 'ADN${nextNumber.toString().padLeft(6, '0')}';
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
      await TelegramLogger.sendLog("❌ [OrderProvider] Failed to initialize scanner\nError: $e\nStack: $stackTrace");
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
        _scannedBarcode = barcode;
        notifyListeners();
        debugPrint('Scanned barcode: $barcode');

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
      await TelegramLogger.sendLog("❌ [OrderProvider] Error starting scanner\nError: $e\nStack: $stackTrace");
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
      await TelegramLogger.sendLog("❌ [OrderProvider] Failed to stop scanner\nError: $e\nStack: $stackTrace");
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  SalesOrder? getSalesOrderById(String soNumber) {
    try {
      return _salesOrders.firstWhere((order) => order.soNumber == soNumber);
    } catch (e) {
      return null;
    }
  }

  Future<bool> isSerialUnique({
    required String serialNo,
    required String itemCode,
  }) async {
    try {
      for (var order in salesOrders) {
        for (var item in order.items) {
          if (item.itemCode == itemCode && item.hasSerial(serialNo)) {
            return false;
          }
        }
      }

      final result = await _sqlConnection.getData(
          "SELECT TOP 1 1 FROM InvDetailSerials "
          "WHERE SerialNo = '${_escapeSqlString(serialNo)}' AND ItemCode = '${_escapeSqlString(itemCode)}'");

      return result.isEmpty || result == "[]";
    } catch (e) {
      print('Error checking serial uniqueness: $e');
      return false;
    }
  }

  // Add this method to your OrderProvider class
  bool hasDuplicateSerialsInItem({
    required String soNumber,
    required String itemCode,
  }) {
    final order = getSalesOrderById(soNumber);
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
    required String soNumber,
    required String itemCode,
  }) {
    final order = getSalesOrderById(soNumber);
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

// Also add this method to get duplicate serials for display
  List<String> getDuplicateSerialsInItem({
    required String soNumber,
    required String itemCode,
  }) {
    final order = getSalesOrderById(soNumber);
    if (order == null) return [];

    final item = order.items.firstWhere(
          (i) => i.itemCode == itemCode,
      orElse: () => throw Exception('Item not found'),
    );

    final serialNumbers = item.serials.map((s) => s.serialNo).toList();
    final duplicates = <String>[];
    final seen = <String>{};

    for (final serial in serialNumbers) {
      if (seen.contains(serial)) {
        duplicates.add(serial);
      } else {
        seen.add(serial);
      }
    }

    return duplicates;
  }

  Future<void> addSerialToItem({
    required String soNumber,
    required String itemCode,
    required String serialNo,
  }) async {
    try {
      final order = getSalesOrderById(soNumber);
      if (order == null) throw Exception('Order not found');

      final item = order.items.firstWhere(
        (i) => i.itemCode == itemCode,
        orElse: () => throw Exception('Item not found'),
      );

      final isUnique =
          await isSerialUnique(itemCode: itemCode, serialNo: serialNo);
      if (!isUnique) {
        return AppAlerts.appToast(
            message: 'Serial number $serialNo already exists in another item');
      }

      if (!item.nonInventory) {
        if (item.stockQty <= 0) {
          return AppAlerts.appToast(
              message: 'Insufficient stock for item ${item.itemCode}');
        }

        if (item.serials.length >= item.stockQty) {
          return AppAlerts.appToast(
              message:
                  'Cannot add serial - would exceed available stock (${item.stockQty})');
        }
      }

      if (item.qtyIssued >= item.qtyOrdered) {
        return AppAlerts.appToast(
            message:
                'Cannot add serial - would exceed Qty ordered (${item.qtyOrdered})');
      }

      item.qtyIssued++;
      item.addSerial(serialNo);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }


  void removeSerialFromItem({
    required String soNumber,
    required String itemCode,
    required String serialNo,
  }) {
    try {
      final order = getSalesOrderById(soNumber);
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

      // Decrement the quantity issued
      item.qtyIssued -= 1;

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to remove serial: ${e.toString()}');
    }
  }

  void resetValidation() {
    isValidForPosting = true;
    validationMessage = '';
    notifyListeners();
  }

  // Method to update item quantity directly via text field
  void updateItemQuantity(String soNumber, String itemCode, double newQuantity) {
    final order = getSalesOrderById(soNumber);
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
    
    if (!item.nonInventory && newQuantity > item.stockQty) {
      AppAlerts.appToast(message: 'Insufficient stock (${item.stockQty} available)');
      return;
    }
    
    item.qtyIssued = newQuantity;
    notifyListeners();
  }
}
