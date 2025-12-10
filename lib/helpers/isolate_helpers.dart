// isolate_helpers.dart
// Isolate helper functions for CPU-intensive operations
import 'dart:isolate';
import 'dart:convert';

/// Parse JSON string in isolate (CPU-intensive operation)
/// This prevents blocking the main UI thread when parsing large JSON responses
Future<List<dynamic>> parseJsonInIsolate(String jsonString) async {
  return await Isolate.run(() {
    return jsonDecode(jsonString) as List;
  });
}

/// Check for duplicate serial numbers in a list
/// Returns a map with serial numbers as keys and their positions as values
Future<Map<String, List<int>>> findDuplicateSerials(List<String> serialNumbers) async {
  return await Isolate.run(() {
    final serialPositions = <String, List<int>>{};
    
    // Track positions of each serial number
    for (int i = 0; i < serialNumbers.length; i++) {
      final serial = serialNumbers[i];
      if (!serialPositions.containsKey(serial)) {
        serialPositions[serial] = [];
      }
      serialPositions[serial]!.add(i + 1); // +1 to make it 1-based index
    }
    
    // Return only duplicates (serial numbers that appear more than once)
    return serialPositions..removeWhere((key, value) => value.length <= 1);
  });
}

/// Filter sales orders by search query
Future<List<Map<String, dynamic>>> filterSalesOrders(
  List<Map<String, dynamic>> orders,
  String query,
) async {
  return await Isolate.run(() {
    final lowerQuery = query.toLowerCase();
    return orders.where((order) {
      final soNumber = order['soNumber']?.toString().toLowerCase() ?? '';
      final customerName = order['customerName']?.toString().toLowerCase() ?? '';
      return soNumber.contains(lowerQuery) || customerName.contains(lowerQuery);
    }).toList();
  });
}

/// Filter purchase orders by search query
Future<List<Map<String, dynamic>>> filterPurchaseOrders(
  List<Map<String, dynamic>> orders,
  String query,
) async {
  return await Isolate.run(() {
    final lowerQuery = query.toLowerCase();
    return orders.where((order) {
      final poNumber = order['poNumber']?.toString().toLowerCase() ?? '';
      final supplierName = order['supplierName']?.toString().toLowerCase() ?? '';
      return poNumber.contains(lowerQuery) || supplierName.contains(lowerQuery);
    }).toList();
  });
}

/// Parse JSON and find the maximum DN number
/// Returns the next DN number
Future<String> getNextDnNumberFromJson(String jsonString) async {
  return await Isolate.run(() {
    final resultJson = jsonDecode(jsonString);
    
    if (resultJson.isEmpty) {
      return 'ADN000001';
    } else {
      // Extract all DN numbers and parse their numeric parts
      final dnNumbers = resultJson
          .map<String>((item) => item['DnNumber'] as String)
          .toList();
      
      // Find the maximum number
      int maxNumber = 0;
      for (final dn in dnNumbers) {
        final number = int.tryParse(dn.replaceAll('ADN', '')) ?? 0;
        if (number > maxNumber) {
          maxNumber = number;
        }
      }
      
      final nextNumber = maxNumber + 1;
      return 'ADN${nextNumber.toString().padLeft(6, '0')}';
    }
  });
}

/// Parse JSON and find the maximum GRN number
/// Returns the next GRN number
Future<String> getNextGrnNumberFromJson(String jsonString) async {
  return await Isolate.run(() {
    final resultJson = jsonDecode(jsonString);
    
    if (resultJson.isEmpty) {
      return 'AGRN00001';
    } else {
      // Extract all GRN numbers and parse their numeric parts
      final grnNumbers = resultJson
          .map<String>((item) => item['GrnNumber'] as String)
          .toList();
      
      // Find the maximum number
      int maxNumber = 0;
      for (final grn in grnNumbers) {
        final number = int.tryParse(grn.replaceAll('AGRN', '')) ?? 0;
        if (number > maxNumber) {
          maxNumber = number;
        }
      }
      
      final nextNumber = maxNumber + 1;
      return 'AGRN${nextNumber.toString().padLeft(5, '0')}';
    }
  });
}


