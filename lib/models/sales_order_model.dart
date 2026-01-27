class SalesOrder {
  final String companyCode;
  final String soNumber;
  final DateTime soDate;
  final String customerCode;
  final String customerName;
  final String salesmanCode;
  final String salesmanName;
  final String refNo;
  final String locationCode;
  final bool isPending;
  final List<SalesOrderItem> items; // List of items

  SalesOrder({
    required this.companyCode,
    required this.soNumber,
    required this.soDate,
    required this.customerCode,
    required this.customerName,
    required this.salesmanCode,
    required this.salesmanName,
    required this.refNo,
    required this.locationCode,
    required this.isPending,
    required this.items,
  });

  factory SalesOrder.fromJson(Map<String, dynamic> json) {
    return SalesOrder(
      companyCode: json['CmpyCode'].toString(),
      soNumber: json['SoNumber'].toString(),
      soDate: DateTime.parse(json['SODate'].toString()),
      customerCode: json['CustomerCode'].toString(),
      customerName: json['CustomerName'].toString(),
      salesmanCode: json['SalesmanCode'].toString(),
      salesmanName: json['SalesmanName'].toString(),
      refNo: json['RefNo'].toString() == "null" ? "":json['RefNo'].toString(),
      locationCode: json['loccode'].toString(),
      isPending: true, // Add your actual status logic here
      items: [
        SalesOrderItem(
          itemCode: json['ItemCode'].toString(),
          itemName: json['ItemName'].toString(),
          unit: json['Unit'].toString(),
          qtyOrdered: double.parse(json['QtyOrdered'].toString()),
          stockQty: double.parse(json['StockQty'].toString()),
          nonInventory: json['NonInventory'].toString() == '1',
          serialYN: json['SerialYN'].toString() == '1',
          soQty: double.tryParse(json['SOQty']?.toString() ?? '0') ?? 0,
          qtyIssued: 0,
        )
      ],
    );
  }

  // Helper method to add an item to this order
  void addItem(Map<String, dynamic> json) {
    items.add(
        SalesOrderItem(
          itemCode: json['ItemCode'].toString(),
          itemName: json['ItemName'].toString(),
          unit: json['Unit'].toString(),
          qtyOrdered: double.parse(json['QtyRemain'].toString()),
          stockQty: double.parse(json['StockQty'].toString()),
          nonInventory: json['NonInventory'].toString() == '1',
          serialYN: json['SerialYN'].toString() == '1',
          soQty: double.tryParse(json['SOQty']?.toString() ?? '0') ?? 0,
          qtyIssued: 0,
        )
    );
  }

  // Helper method to get serialized items
  List<SalesOrderItem> get serializedItems => items.where((item) => item.serialYN).toList();
}

class SalesOrderItem {
  final String itemCode;
  final String itemName;
  final String unit;
  final double qtyOrdered;
  double qtyIssued;
  final double stockQty;
  final bool nonInventory;
  final bool serialYN;
  final double soQty;
  final List<ItemSerial> serials; // Track serial numbers for this item
  final Set<String> _scannedBarcodes; // Use Set to prevent duplicate barcodes

  SalesOrderItem({
    required this.itemCode,
    required this.itemName,
    required this.unit,
    required this.qtyOrdered,
    required this.qtyIssued,
    required this.stockQty,
    required this.nonInventory,
    required this.serialYN,
    this.soQty = 0,
    List<ItemSerial>? serials,
  }) : serials = serials ?? [],
       _scannedBarcodes = (serials?.map((s) => s.serialNo).toSet() ?? <String>{});

  // Add a serial number to this item
  void addSerial(String serialNo) {
    // Check if barcode already exists in the set
    if (_scannedBarcodes.contains(serialNo)) {
      return; // Don't add duplicate barcode
    }
    
    // Add to set and list
    _scannedBarcodes.add(serialNo);
    serials.add(ItemSerial(
      serialNo: serialNo,
      sNo: serials.length + 1, // Auto-increment position
    ));
  }

  // Remove a serial number from this item
  void removeSerial(String serialNo) {
    // Remove from set
    _scannedBarcodes.remove(serialNo);
    
    // Find and remove from list
    final serialIndex = serials.indexWhere((s) => s.serialNo == serialNo);
    if (serialIndex != -1) {
      serials.removeAt(serialIndex);
      
      // Recalculate positions (serial numbers)
      for (int i = 0; i < serials.length; i++) {
        serials[i] = ItemSerial(
          serialNo: serials[i].serialNo,
          sNo: i + 1,
        );
      }
    }
  }

  // Clear all serials
  void clearSerials() {
    _scannedBarcodes.clear();
    serials.clear();
  }

  // Check if serial number already exists
  bool hasSerial(String serialNo) {
    return _scannedBarcodes.contains(serialNo);
  }
}

class ItemSerial {
  final String serialNo;
  final int sNo;

  ItemSerial({
    required this.serialNo,
    required this.sNo,
  });
}