class InventoryDetailSerialNo {
  final String cmpyCode;
  final String invNumber;
  final String sno;
  final String itemCode;
  final String serialNo;
  final String srNo;
  final String? dnNumber;
  final bool returnYN;

  InventoryDetailSerialNo({
    required this.cmpyCode,
    required this.invNumber,
    required this.sno,
    required this.itemCode,
    required this.serialNo,
    required this.srNo,
    this.dnNumber,
    required this.returnYN,
  });

  Map<String, dynamic> toJson() {
    return {
      'CmpyCode': cmpyCode,
      'InvNumber': invNumber,
      'Sno': sno,
      'ItemCode': itemCode,
      'SerialNo': serialNo,
      'SrNo': srNo,
      'DnNumber': dnNumber,
      'ReturnYN': returnYN ? 1 : 0,
    };
  }
}