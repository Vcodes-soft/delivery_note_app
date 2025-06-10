// purchase_order_model.dart
import 'package:delivery_note_app/models/sales_order_model.dart';

class PurchaseOrder {
  final String companyCode;
  final String poNumber;
  final String locationCode;
  final DateTime poDate;
  final String supplierCode;
  final String supplierName;
  final String refNo;
  final List<PurchaseOrderItem> items;
  final bool isPending;

  PurchaseOrder({
    required this.companyCode,
    required this.poNumber,
    required this.locationCode,
    required this.poDate,
    required this.supplierCode,
    required this.supplierName,
    required this.refNo,
    required this.items,
    this.isPending = true,
  });

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    return PurchaseOrder(
      companyCode: json['CmpyCode'].toString(),
      poNumber: json['PONumber'].toString(),
      locationCode: json['loccode'].toString(),
      poDate: DateTime.parse(json['SODate'].toString()),
      supplierCode: json['SupplierCode'].toString(),
      supplierName: json['SupplierName'].toString(),
      refNo: json['RefNo'].toString(),
      items: [PurchaseOrderItem.fromJson(json)],
      isPending: true,
    );
  }

  void addItem(Map<String, dynamic> json) {
    items.add(PurchaseOrderItem.fromJson(json));
  }
}

class PurchaseOrderItem {
  final String itemCode;
  final String itemName;
  final String unit;
  final double qtyOrdered;
  late final double qtyReceived;
  final bool nonInventory;
  final bool serialYN;
  final List<ItemSerial> serials;

  PurchaseOrderItem({
    required this.itemCode,
    required this.itemName,
    required this.unit,
    required this.qtyOrdered,
    this.qtyReceived = 0,
    required this.nonInventory,
    required this.serialYN,
    this.serials = const [],
  });

  factory PurchaseOrderItem.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderItem(
      itemCode: json['ItemCode'].toString(),
      itemName: json['ItemName'].toString(),
      unit: json['Unit'].toString(),
      qtyOrdered: double.parse(json['QtyOrdered'].toString()),
      nonInventory: json['NonInventory'] == 1,
      serialYN: json['SerialYN'] == 1,
    );
  }

  bool hasSerial(String serialNo) {
    return serials.any((s) => s.serialNo == serialNo);
  }

  void addSerial(String serialNo) {
    serials.add(ItemSerial(
      serialNo: serialNo,
      sNo: serials.length + 1,
    ));
  }
}