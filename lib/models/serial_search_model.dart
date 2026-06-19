import 'package:intl/intl.dart';

class SerialSearchRecord {
  final String cmpyCode;
  final String invNumber;
  final DateTime? dates;
  final String customerCode;
  final String itemCode;
  final String serialNo;
  final String clientCode;
  final String locCode;

  const SerialSearchRecord({
    required this.cmpyCode,
    required this.invNumber,
    this.dates,
    required this.customerCode,
    required this.itemCode,
    required this.serialNo,
    required this.clientCode,
    required this.locCode,
  });

  factory SerialSearchRecord.fromJson(Map<String, dynamic> json) {
    return SerialSearchRecord(
      cmpyCode: _field(json, 'CmpyCode'),
      invNumber: _field(json, 'InvNumber'),
      dates: _parseDate(json['Dates']),
      customerCode: _field(json, 'CustomerCode'),
      itemCode: _field(json, 'ItemCode'),
      serialNo: _field(json, 'SerialNo').toUpperCase(),
      clientCode: _field(json, 'ClientCode'),
      locCode: _field(json, 'LocCode'),
    );
  }

  String get formattedDate {
    if (dates == null) return '';
    return DateFormat('dd/MM/yyyy').format(dates!);
  }

  String get docNoAndDate {
    if (formattedDate.isEmpty) return invNumber;
    return '$invNumber • $formattedDate';
  }

  String get customerAndClient {
    if (customerCode.isEmpty) return clientCode;
    if (clientCode.isEmpty) return customerCode;
    return '$customerCode • $clientCode';
  }

  String get itemAndLoc {
    if (itemCode.isEmpty) return locCode;
    if (locCode.isEmpty) return itemCode;
    return '$itemCode • $locCode';
  }

  static String _field(Map<String, dynamic> json, String key) {
    final value = json[key] ?? json[key.toLowerCase()];
    if (value == null) return '';
    return value.toString().trim();
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    if (value is DateTime) return value;
    final text = value.toString();
    final formats = [
      DateFormat('yyyy-MM-dd HH:mm:ss'),
      DateFormat('yyyy-MM-dd'),
      DateFormat('dd/MM/yyyy HH:mm:ss'),
      DateFormat('dd/MM/yyyy'),
    ];
    for (final format in formats) {
      try {
        return format.parse(text);
      } catch (_) {}
    }
    return DateTime.tryParse(text);
  }
}
