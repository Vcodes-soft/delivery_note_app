class SalesOrder {
  final String id;
  final String customerName;
  final String refNumber;
  final DateTime issueDate;
  final String salesmanName;
  final bool isPending;

  SalesOrder({
    required this.id,
    required this.customerName,
    required this.refNumber,
    required this.issueDate,
    required this.salesmanName,
    this.isPending = true,
  });
}