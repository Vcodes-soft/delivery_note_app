// purchase_order_provider.dart
import 'dart:convert';
import 'package:delivery_note_app/models/sales_order_model.dart';
import 'package:delivery_note_app/utils/app_alerts.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mssql_connection/mssql_connection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delivery_note_app/models/purchase_order_model.dart';

class PurchaseOrderProvider with ChangeNotifier {
  final MssqlConnection _sqlConnection = MssqlConnection.getInstance();
  List<PurchaseOrder> _purchaseOrders = [];
  bool _isLoading = false;
  String? _error;

  List<PurchaseOrder> get purchaseOrders => _purchaseOrders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchPurchaseOrders() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _sqlConnection.getData("""
      SELECT * FROM VW_DM_PODetails
      ORDER BY PONumber, ItemCode
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
    } catch (e) {
      _error = 'Failed to fetch orders: ${e.toString()}';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<PurchaseOrder>> getPurchaseOrdersByLocation(String locationCode) async {
    try {
      final result = await _sqlConnection.getData("""
        SELECT * FROM VW_DM_PODetails 
        WHERE loccode = '$locationCode'
        ORDER BY SODate DESC
      """);

      final data = jsonDecode(result) as List;
      return data.map((json) => PurchaseOrder.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch orders: ${e.toString()}');
    }
  }

  // Validate quantities before proceeding
  bool isValidForPosting = true;
  String validationMessage = '';

  Future<void> postGoodsReceipt(BuildContext context, String poNumber) async {
    validationMessage = "";
    isValidForPosting = true;
    final order = getPurchaseOrderById(poNumber);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final String companyCode = prefs.getString('companyCode') ?? "";
    final String username = prefs.getString("username") ?? "";

    if (order == null) {
      print('Order not found for PO: $poNumber');
      AppAlerts.appToast(message: "Order not found for PO: $poNumber");
      return;
    }

    // Validate each item's quantities
    for (var item in order.items) {
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
      }
    }

    // If validation fails, show error message and return
    if (!isValidForPosting) {
      notifyListeners();
      AppAlerts.appToast(
          message: "GRN validation failed, please check the log above");
      return;
    }

    try {
      // Get the next available GRN number
      final maxGrnQuery = "SELECT MAX(GrnNumber) as maxGrn FROM GrnHeader WHERE CmpyCode = '$companyCode'";
      final maxGrnResult = await _sqlConnection.getData(maxGrnQuery);
      String nextGrnNumber = "GRN00001"; // Default starting number

      if (maxGrnResult.isNotEmpty) {
        // Parse the string result to get the max GRN number
        final maxGrn = maxGrnResult;
        if (maxGrn.isNotEmpty && maxGrn != "null") {
          // Extract the numeric part and increment
          final numericPart = int.tryParse(maxGrn.substring(3)) ?? 0;
          nextGrnNumber = "GRN${(numericPart + 1).toString().padLeft(5, '0')}";
        }
      }

      // 1. Create GRNHeader
      final grnHeader = {
        'CmpyCode': companyCode,
        'GrnNumber': nextGrnNumber,
        'LocCode': order.locationCode,
        'Dates': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'SupplierCode': order.supplierCode,
        'RefNo': order.refNo,
        'InvStat': 'N', // Not invoiced
        'Status': 'O', // Open status
        'CurCode': 'AED',
        'ExRate': 1,
        'Discount': 0,
        'GrnType': 'G', // Goods receipt type
        'Qty': order.items.length,
        'DTime': '${TimeOfDay.now().hour.toString().padLeft(2, '0')}:${TimeOfDay.now().minute.toString().padLeft(2, '0')}:00',
        'LoginUser': username,
        'MType': 'P', // Purchase type
        'GrnType1': 'P' // Purchase type
      };

      // Post header
      final headerQuery = '''
      INSERT INTO GrnHeader (
        CmpyCode, GrnNumber, LocCode, Dates, SupplierCode, RefNo, InvStat, 
        Status, CurCode, ExRate, Discount, GrnType, Qty, DTime, LoginUser, 
        MType, GrnType1
      ) VALUES (
        '${grnHeader['CmpyCode']}', 
        '${grnHeader['GrnNumber']}', 
        '${grnHeader['LocCode']}', 
        CONVERT(DATETIME, '${grnHeader['Dates']}', 120), 
        '${grnHeader['SupplierCode']}', 
        '${grnHeader['RefNo']}', 
        '${grnHeader['InvStat']}', 
        '${grnHeader['Status']}', 
        '${grnHeader['CurCode']}', 
        ${grnHeader['ExRate']}, 
        ${grnHeader['Discount']}, 
        '${grnHeader['GrnType']}', 
        ${grnHeader['Qty']}, 
        '${grnHeader['DTime']}', 
        '${grnHeader['LoginUser']}', 
        '${grnHeader['MType']}', 
        '${grnHeader['GrnType1']}'
      )
      ''';

      print('Posting GRN header with number: $nextGrnNumber...');
      await _sqlConnection.writeData(headerQuery);
      print('Header posted successfully with GRN: $nextGrnNumber');

      // 2. Create and post GRNDetails for each item
      for (var item in order.items) {
        final detail = {
          'CmpyCode': companyCode,
          'GrnNumber': nextGrnNumber,
          'LocCode': order.locationCode,
          'Sno': order.items.indexOf(item) + 1,
          'ItemCode': item.itemCode,
          'Barcode': null,
          'Description': item.itemName,
          'Unit': item.unit,
          'QtyOrdered': item.qtyOrdered,
          'QtyReceived': item.qtyReceived,
          'QtyFree': 0,
          'UnitPrice': 0,
          'GrossTotal': 0,
          'AvgCost': 0,
          'ProjectCode': null,
          'AnalysisCode': null,
          'SrNo': item.serials.isNotEmpty ? item.serials.first.serialNo : null,
          'PoNumber': order.poNumber,
          'DiscountP': 0,
          'Discount': 0,
          'NetAmount': 0,
          'NetPurchase': 0,
          'Bsno': null,
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
          '${detail['CmpyCode']}', 
          '${detail['GrnNumber']}', 
          '${detail['LocCode']}', 
          ${detail['Sno']}, 
          '${detail['ItemCode']}', 
          ${detail['Barcode'] != null ? "'${detail['Barcode']}'" : 'NULL'}, 
          '${detail['Description']}',
          '${detail['Unit']}', 
          ${detail['QtyOrdered']}, 
          ${detail['QtyReceived']}, 
          ${detail['QtyFree']}, 
          ${detail['UnitPrice']}, 
          ${detail['GrossTotal']}, 
          ${detail['AvgCost']}, 
          ${detail['ProjectCode'] != null ? "'${detail['ProjectCode']}'" : 'NULL'}, 
          ${detail['AnalysisCode'] != null ? "'${detail['AnalysisCode']}'" : 'NULL'}, 
          ${detail['SrNo'] != null ? "'${detail['SrNo']}'" : 'NULL'}, 
          '${detail['PoNumber']}', 
          ${detail['DiscountP']},
          ${detail['Discount']}, 
          ${detail['NetAmount']}, 
          ${detail['NetPurchase']}, 
          ${detail['Bsno'] != null ? "'${detail['Bsno']}'" : 'NULL'}, 
          ${detail['TaxCode'] != null ? "'${detail['TaxCode']}'" : 'NULL'}, 
          ${detail['TaxPercentage']},
          ${detail['BinCode'] != null ? "'${detail['BinCode']}'" : 'NULL'}
        )
        ''';

        print('Posting detail for item ${item.itemCode}...');
        await _sqlConnection.writeData(detailQuery);
        print('Detail posted for item ${item.itemCode}');

        // 3. Post serial numbers if item is serialized
        if (item.serialYN && item.serials.isNotEmpty) {
          for (var serial in item.serials) {
            final serialDetail = {
              'CmpyCode': companyCode,
              'GrnNumber': nextGrnNumber,
              'VbNumber': '', // Will be invoice number if available
              'Sno': serial.sNo.toString(),
              'ItemCode': item.itemCode,
              'SerialNo': serial.serialNo,
              'SrNo': "1",
              'DocType': 'P', // Purchase type
              'ReturnYN': false,
            };

            final serialQuery = '''
            INSERT INTO GrnDetailSerials (
              CmpyCode, GrnNumber, VbNumber, Sno, ItemCode, SerialNo, SrNo, DocType, ReturnYN
            ) VALUES (
              '${serialDetail['CmpyCode']}', 
              '${serialDetail['GrnNumber']}', 
              '${serialDetail['VbNumber']}', 
              '${serialDetail['Sno']}', 
              '${serialDetail['ItemCode']}', 
              '${serialDetail['SerialNo']}', 
              '${serialDetail['SrNo']}', 
              '${serialDetail['DocType']}', 
              ${serialDetail['ReturnYN'] == true ? 1 : 0}
            )
            ''';

            print('Posting serial ${serial.serialNo}...');
            await _sqlConnection.writeData(serialQuery);
            print('Serial ${serial.serialNo} posted');
          }
        }
      }
      AppAlerts.appToast(message: "GRN $nextGrnNumber posted successfully");
    } catch (e, stackTrace) {
      print('ERROR in postGoodsReceipt:');
      print('Message: $e');
      print('Stack trace: $stackTrace');
      AppAlerts.appToast(
          message: "Failed to post GRN: ${e.toString()}");
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

      // 2. SAFE DATABASE CHECK - Using proper parameterization
      final escapedSerial = serialNo.replaceAll("'", "''");
      final escapedItemCode = itemCode.replaceAll("'", "''");

      final result = await _sqlConnection.getData(
          "SELECT TOP 1 1 FROM GrnDetailSerials "
              "WHERE SerialNo = '$escapedSerial' AND ItemCode = '$escapedItemCode'");

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

      // Check if serial exists in other items or database
      final isUnique = await isSerialUnique(itemCode: itemCode, serialNo: serialNo);
      if (!isUnique) {
        throw Exception('Serial number $serialNo already exists in another item');
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

      final initialLength = item.serials.length;
      item.serials.removeWhere((s) => s.serialNo == serialNo);

      // Only decrement if a serial was actually removed
      if (item.serials.length < initialLength) {
        item.qtyReceived -= 1;
      }

      // Recalculate positions
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