import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mssql_connection/mssql_connection.dart';
import 'package:delivery_note_app/models/sales_order_model.dart';

class OrderProvider with ChangeNotifier {
  final MssqlConnection _sqlConnection = MssqlConnection.getInstance();
  List<SalesOrder> _salesOrders = [];
  bool _isLoading = false;
  String? _error;


  List<SalesOrder> get salesOrders => _salesOrders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchSalesOrders() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _sqlConnection.getData("""
      SELECT 
        A.CmpyCode, 
        A.SoNumber,
        A.Dates as SODate, 
        A.CustomerCode, 
        C.Name As CustomerName,
        A.SalesmanCode, 
        D.Name As SalesmanName, 
        A.RefNo, 
        B.ItemCode, 
        Left(B.Description,50) as ItemName, 
        B.Unit, 
        B.QtyOrdered, 
        E.Tqty as StockQty,
        F.NonInventory, 
        F.SerialYN,
        A.LocCode
      FROM 
        SoHeader A, 
        SoDetail B, 
        Customers C, 
        Salesman D, 
        Vw_ClosingStockA E, 
        Products F
      WHERE 
        A.CmpyCode = B.CmpyCode and A.SoNumber = B.SoNumber 
        and A.CmpyCode = C.Cmpycode and A.CustomerCode = C.Customercode
        and C.CmpyCode = D.Cmpycode and A.SalesmanCode = D.SalesmanCode
        And B.CmpyCode = E.Cmpycode and B.ItemCode = E.Itemcode and A.LocCode = E.LocCode 
        And B.CmpyCode = F.Cmpycode and B.ItemCode = F.Itemcode  
        and A.Status <> 'C' and A.DelStat <> 'Y'
      ORDER BY A.SoNumber, B.ItemCode
    """);

      final data = jsonDecode(result) as List;

      // Create a map to group orders by SO number
      final ordersMap = <String, SalesOrder>{};

      for (var json in data) {
        final soNumber = json['SoNumber'].toString();

        if (!ordersMap.containsKey(soNumber)) {
          // Create new order with first item
          ordersMap[soNumber] = SalesOrder.fromJson(json);
        } else {
          // Add item to existing order
          ordersMap[soNumber]!.addItem(json);
        }
      }

      // Convert map values to list
      _salesOrders = ordersMap.values.toList();

    } catch (e) {
      _error = 'Failed to fetch orders: ${e.toString()}';
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

  SalesOrder? getSalesOrderById(String soNumber) {
    try {
      return _salesOrders.firstWhere((order) => order.soNumber == soNumber);
    } catch (e) {
      return null;
    }
  }

}