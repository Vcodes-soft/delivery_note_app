class DeliveryNoteDetail {
  final String cmpyCode;
  final String dnNumber;
  final String locCode;
  final int sno;
  final String itemCode;
  final String? barcode;
  final String description;
  final String unit;
  final double qtyOrdered;
  final double qtyIssued;
  final double unitPrice;
  final double grossTotal;
  final double discountP;
  final double discount;
  final double closingStock;
  final double avgCost;
  final String? srNo;
  final String? soNumber;
  final double cogsamt;
  final bool nonInventory;
  final bool isFreeofCost;
  final String? parentItem;
  final double qtyReserved;
  final double poQty;
  final double totReservedQty;
  final String? bSno;
  final double soQty;
  final String? taxCode;
  final double taxPercentage;
  final String? binCode;
  final double? commAmount;
  final double? commission;

  DeliveryNoteDetail({
    required this.cmpyCode,
    required this.dnNumber,
    required this.locCode,
    required this.sno,
    required this.itemCode,
    this.barcode,
    required this.description,
    required this.unit,
    required this.qtyOrdered,
    required this.qtyIssued,
    required this.unitPrice,
    required this.grossTotal,
    required this.discountP,
    required this.discount,
    required this.closingStock,
    required this.avgCost,
    this.srNo,
    this.soNumber,
    required this.cogsamt,
    required this.nonInventory,
    required this.isFreeofCost,
    this.parentItem,
    required this.qtyReserved,
    required this.poQty,
    required this.totReservedQty,
    this.bSno,
    required this.soQty,
    this.taxCode,
    required this.taxPercentage,
    this.binCode,
    this.commAmount,
    this.commission,
  });

  Map<String, dynamic> toJson() {
    return {
      'CmpyCode': cmpyCode,
      'DnNumber': dnNumber,
      'LocCode': locCode,
      'Sno': sno,
      'ItemCode': itemCode,
      'Barcode': barcode,
      'Description': description,
      'Unit': unit,
      'QtyOrdered': qtyOrdered,
      'QtyIssued': qtyIssued,
      'UnitPrice': unitPrice,
      'GrossTotal': grossTotal,
      'DiscountP': discountP,
      'Discount': discount,
      'ClosingStock': closingStock,
      'AvgCost': avgCost,
      'SrNo': srNo,
      'SoNumber': soNumber,
      'Cogsamt': cogsamt,
      'NonInventory': nonInventory ? 1 : 0,
      'IsFreeofCost': isFreeofCost ? 1 : 0,
      'ParentItem': parentItem,
      'QtyReserved': qtyReserved,
      'PoQty': poQty,
      'TotReservedQty': totReservedQty,
      'BSno': bSno,
      'SoQty': soQty,
      'TaxCode': taxCode,
      'TaxPercentage': taxPercentage,
      'BinCode': binCode,
      'CommAmount': commAmount,
      'Commission': commission,
    };
  }
}