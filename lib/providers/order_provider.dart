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
    } catch (e) {
      _error = 'Failed to fetch orders: ${e.toString()}';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void searchSalesOrders(String query) {
    searchQuery = query;
    filteredSalesOrders = salesOrders.where((order) {
      return order.soNumber.toLowerCase().contains(query.toLowerCase()) ||
          order.customerName.toLowerCase().contains(query.toLowerCase());
    }).toList();
    notifyListeners();
  }

  Future<void> fetchSalesOrderDetails(String soNumber) async {
    try {
      _isLoading = true;
      notifyListeners();

      final result = await _sqlConnection.getData("""
      SELECT * FROM VW_DM_SODetails_Items 
      WHERE SoNumber = '$soNumber'
      ORDER BY Sno
      """);

      final data = jsonDecode(result) as List;

      // Find existing order or create new one
      SalesOrder? order = getSalesOrderById(soNumber);
      if (order == null) {
        // If order not found in list, fetch header details
        final headerResult = await _sqlConnection.getData("""
        SELECT TOP 1 * FROM VW_DM_SODetails 
        WHERE SoNumber = '$soNumber'
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

  Future<List<SalesOrder>> getSalesOrdersByLocation(String locationCode) async {
    try {
      final result = await _sqlConnection.getData("""
        SELECT * FROM VW_DM_SODetails 
        WHERE LocCode = '$locationCode'
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

    if (order == null) {
      print('Order not found for SO: $soNumber');
      setLoading(false);
      AppAlerts.appToast(message: "Order not found for SO: $soNumber");
      return;
    }

    // Validate each item's stock and quantities
    for (var item in order.items) {
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
          SELECT COUNT(*) as count FROM InvDetailSerials_DN 
          WHERE CmpyCode = '$companyCode' AND ItemCode = '${item.itemCode}' AND SerialNo = '${serial.serialNo}'
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
      AppAlerts.appToast(
          message: "Delivery note validation failed: \n $validationMessage");
      return;
    }

    try {
      String nextDnNumber = await _getNextDnNumber();

      final deliveryNoteHeader = DeliveryNoteHeader(
        cmpyCode: order.companyCode,
        dnNumber: nextDnNumber,
        locCode: order.locationCode,
        dates: DateTime.now(),
        customerCode: order.customerCode,
        salesmanCode: order.salesmanCode,
        soNumber: order.soNumber,
        refNo: order.refNo,
        status: 'O',
        invStat: 'N',
        discount: 0,
        curCode: 'AED',
        exRate: 1,
        dnType: 'D',
        qty: order.items
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

      final headerQuery = '''
    INSERT INTO DNoteHeader (
      Cmpycode, DnNumber, LocCode, Dates, CustomerCode, SalesmanCode, 
      SoNumber, RefNo, Status, InvStat, Discount, CurCode, ExRate, 
      DnType, Qty, DTime, LoginUser, CreditLimitAmount, OutstandingBalance, 
      GrossAmount, Narration, CommissionYN, Supplier, DYType
    ) VALUES (
      '${deliveryNoteHeader.cmpyCode}', 
      '${deliveryNoteHeader.dnNumber}', 
      '${deliveryNoteHeader.locCode}', 
      CONVERT(DATETIME, '${DateFormat('yyyy-MM-dd').format(deliveryNoteHeader.dates)}', 120), 
      '${deliveryNoteHeader.customerCode}', 
      '${deliveryNoteHeader.salesmanCode}',
      '${deliveryNoteHeader.soNumber}', 
      '${deliveryNoteHeader.refNo}', 
      '${deliveryNoteHeader.status}', 
      '${deliveryNoteHeader.invStat}', 
      ${deliveryNoteHeader.discount}, 
      '${deliveryNoteHeader.curCode}', 
      ${deliveryNoteHeader.exRate},
      '${deliveryNoteHeader.dnType}', 
      ${deliveryNoteHeader.qty}, 
      CONVERT(TIME, '${deliveryNoteHeader.dTime.hour.toString().padLeft(2, '0')}:${deliveryNoteHeader.dTime.minute.toString().padLeft(2, '0')}:00'), 
      '${deliveryNoteHeader.loginUser}', 
      ${deliveryNoteHeader.creditLimitAmount}, 
      ${deliveryNoteHeader.outstandingBalance},
      ${deliveryNoteHeader.grossAmount}, 
      '${deliveryNoteHeader.narration}', 
      '${deliveryNoteHeader.commissionYN}', 
      '${deliveryNoteHeader.supplier}', 
      '${deliveryNoteHeader.dyType}'
    )
    ''';

      print('Posting delivery note header with DN: $nextDnNumber...');
      await _sqlConnection.writeData(headerQuery);
      print('Header posted successfully with DN: $nextDnNumber');

      // Post items
      for (var item in order.items) {
        final bsno = order.items.indexOf(item) + 1;
        final detail = DeliveryNoteDetail(
          cmpyCode: order.companyCode,
          dnNumber: deliveryNoteHeader.dnNumber,
          locCode: order.locationCode,
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
      '${detail.cmpyCode}', 
      '${detail.dnNumber}', 
      '${detail.locCode}', 
      ${detail.sno}, 
      '${detail.itemCode}', 
      ${detail.barcode != null ? "'${detail.barcode}'" : 'NULL'}, 
      '${detail.description}',
      '${detail.unit}', 
      ${detail.qtyOrdered}, 
      ${detail.qtyIssued}, 
      ${detail.unitPrice}, 
      ${detail.grossTotal}, 
      ${detail.discountP},
      ${detail.discount}, 
      ${detail.closingStock}, 
      ${detail.avgCost}, 
      ${detail.srNo != null ? "'${detail.srNo}'" : 'NULL'}, 
      '${detail.soNumber}', 
      ${detail.cogsamt},
      ${detail.nonInventory ? 1 : 0}, 
      ${detail.isFreeofCost ? 1 : 0}, 
      ${detail.parentItem != null ? "'${detail.parentItem}'" : 'NULL'}, 
      ${detail.qtyReserved}, 
      ${detail.poQty},
      ${detail.totReservedQty}, 
      ${detail.bSno != null ? "'${detail.bSno}'" : 'NULL'}, 
      ${detail.soQty}, 
      ${detail.taxCode != null ? "'${detail.taxCode}'" : 'NULL'}, 
      ${detail.taxPercentage},
      ${detail.binCode != null ? "'${detail.binCode}'" : 'NULL'}, 
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
            SrNo = '${bsno.toString()}'
        WHERE CmpyCode = '${order.companyCode}' 
          AND SoNumber = '${order.soNumber}' 
          AND ItemCode = '${item.itemCode}' 
      ''';

        print('Updating SoDetail for item ${item.itemCode}...');
        await _sqlConnection.writeData(updateSoDetailQuery);
        print('SoDetail updated for item ${item.itemCode}');

        // Post serial numbers
        if (item.serialYN && item.serials.isNotEmpty) {

          for (var serial in item.serials) {
            final serialDetail = InventoryDetailSerialNo(
              cmpyCode: order.companyCode,
              invNumber: '',
              sno: serial.sNo.toString(),
              itemCode: item.itemCode,
              serialNo: serial.serialNo,
              srNo: bsno.toString(),
              dnNumber: deliveryNoteHeader.dnNumber,
              returnYN: false,
            );

            final serialQuery = '''
        INSERT INTO InvDetailSerials_DN (
          CmpyCode, InvNumber, Sno, ItemCode, SerialNo, SrNo, DnNumber, ReturnYN
        ) VALUES (
          '${serialDetail.cmpyCode}', 
          '${serialDetail.invNumber}', 
          '${serialDetail.sno}', 
          '${serialDetail.itemCode}', 
          '${serialDetail.serialNo}', 
          '${serialDetail.srNo}', 
          '${serialDetail.dnNumber}', 
          ${serialDetail.returnYN ? 1 : 0}
        )
        ''';

            print('Posting serial ${serial.serialNo}...');
            await _sqlConnection.writeData(serialQuery);
            print('Serial ${serial.serialNo} posted');
          }
        }
      }

      // Update SO status based on whether it's fully delivered
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
          DelStat = '${isFullyDelivered ? 'Y' : 'N'}'
      WHERE SoNumber = '${order.soNumber}' AND CmpyCode = '${order.companyCode}'
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
      print('ERROR in postDeliveryNote:');
      print('Message: $e');
      print('Stack trace: $stackTrace');
      AppAlerts.appToast(
          message: "Failed to post delivery note: ${e.toString()}");
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
    } catch (e) {
      setLoading(false);
      debugPrint("Failed to initialize scanner: $e");
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

      notifyListeners();
      debugPrint('Scanner started');
    } catch (e) {
      debugPrint('Error starting scanner: $e');
      await stopScanner();
      rethrow;
    }
  }

  Future<void> stopScanner() async {
    try {
      await dataWedge?.activateScanner(false);
      _scanSubscription?.cancel();
      _isScannerActive = false;
      debugPrint('Scanner stopped');
    } catch (e) {
      debugPrint("Failed to stop scanner: $e");
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

      final escapedSerial = serialNo.replaceAll("'", "''");
      final escapedItemCode = itemCode.replaceAll("'", "''");

      final result = await _sqlConnection.getData(
          "SELECT TOP 1 1 FROM InvDetailSerials "
          "WHERE SerialNo = '$escapedSerial' AND ItemCode = '$escapedItemCode'");

      return result.isEmpty || result == "[]";
    } catch (e) {
      print('Error checking serial uniqueness: $e');
      return false;
    }
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

      final initialLength = item.serials.length;
      item.serials.removeWhere((s) => s.serialNo == serialNo);

      if (item.serials.length < initialLength) {
        item.qtyIssued -= 1;
      }

      for (int i = 0; i < item.serials.length; i++) {
        item.serials[i] = ItemSerial(
          serialNo: item.serials[i].serialNo,
          sNo: i + 1,
        );
      }
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
}
