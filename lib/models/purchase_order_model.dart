class PurchaseOrder {
  final String id;
  final String supplierName;
  final String refNumber;
  final DateTime issueDate;
  final bool isPending;

  PurchaseOrder({
    required this.id,
    required this.supplierName,
    required this.refNumber,
    required this.issueDate,
    this.isPending = true,
  });
}
