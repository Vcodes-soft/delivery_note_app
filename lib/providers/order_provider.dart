import 'package:delivery_note_app/models/item_model.dart';
import 'package:delivery_note_app/models/purchase_order_model.dart';
import 'package:delivery_note_app/models/sales_order_model.dart';
import 'package:flutter/material.dart';

class OrderProvider with ChangeNotifier {
  // Sample data - in a real app, this would come from an API
  final List<SalesOrder> _salesOrders = [
    SalesOrder(
      id: 'S0123563',
      customerName: 'Tech Solutions Inc.',
      refNumber: '53324545',
      issueDate: DateTime(2025, 4, 2),
      salesmanName: 'John Doe',
    ),
    SalesOrder(
      id: 'S0123565',
      customerName: 'Digital World Ltd.',
      refNumber: '53324546',
      issueDate: DateTime(2025, 4, 3),
      salesmanName: 'Jane Smith',
    ),
  ];

  final List<PurchaseOrder> _purchaseOrders = [
    PurchaseOrder(
        id: 'PO123563',
        supplierName: 'Electro Components Co.',
        refNumber: '53324547',
        issueDate: DateTime(2025, 4, 2)),
    PurchaseOrder(
        id: 'PO123565',
        supplierName: 'Cable Masters Inc.',
        refNumber: '53324548',
        issueDate: DateTime(2025, 4, 3)),
  ];

  List<SalesOrder> get salesOrders => _salesOrders;
  List<PurchaseOrder> get purchaseOrders => _purchaseOrders;

  int get totalSalesOrders => _salesOrders.length;
  int get totalPendingSalesOrders => _salesOrders.where((o) => o.isPending).length;
  int get totalPurchaseOrders => _purchaseOrders.length;
  int get totalPendingPurchaseOrders => _purchaseOrders.where((o) => o.isPending).length;

  SalesOrder? getSalesOrderById(String id) {
    try {
      return _salesOrders.firstWhere((order) => order.id == id);
    } catch (e) {
      return null;
    }
  }

  PurchaseOrder? getPurchaseOrderById(String id) {
    try {
      return _purchaseOrders.firstWhere((order) => order.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Item> getItemsForOrder(String orderId) {
    // In a real app, this would fetch from API based on orderId
    return [
      Item(
        id: '1',
        name: 'Cable USB C Type',
        code: 'TS-BHDJ-DGA',
        stock: 30,
        orderedQuantity: 20,
      ),
    ];
  }
}