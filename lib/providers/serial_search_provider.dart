import 'dart:convert';

import 'package:delivery_note_app/models/serial_search_group.dart';
import 'package:delivery_note_app/models/serial_search_model.dart';
import 'package:flutter/material.dart';
import 'package:mssql_connection/mssql_connection.dart';

class SerialSearchProvider with ChangeNotifier {
  SerialSearchProvider();

  static const int pageSize = 20;

  final MssqlConnection _sqlConnection = MssqlConnection.getInstance();

  List<SerialSearchRecord> _records = [];
  int _offset = 0;
  bool _hasMore = true;
  bool _hasSearched = false;
  String searchQuery = '';
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  List<SerialSearchRecord> get records => _records;
  List<SerialSearchGroup> get groupedRecords => groupSerialSearchRecords(_records);
  bool get hasSearched => _hasSearched;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;

  String _escapeSqlString(String value) {
    return value.replaceAll("'", "''");
  }

  String _whereClause() {
    if (searchQuery.isEmpty) return '';
    final q = _escapeSqlString(searchQuery);
    return "WHERE UPPER(LTRIM(RTRIM(SerialNo))) = '$q'";
  }

  Future<List<SerialSearchRecord>> _fetchPage(int offset) async {
    final result = await _sqlConnection.getData("""
      SELECT * FROM VW_SearchSerialNo
      ${_whereClause()}
      ORDER BY Dates ASC
      OFFSET $offset ROWS FETCH NEXT $pageSize ROWS ONLY
    """);

    if (result.isEmpty || result == '[]') return [];

    final data = jsonDecode(result) as List;
    return data
        .map((json) =>
            SerialSearchRecord.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> searchSerials(String query) async {
    final trimmed = query.trim().toUpperCase();
    if (trimmed.isEmpty) {
      resetResults();
      return;
    }

    if (trimmed == searchQuery && _hasSearched && _records.isNotEmpty) {
      return;
    }

    searchQuery = trimmed;
    _hasSearched = true;
    await fetchSerialRecords(refresh: true);
  }

  Future<void> fetchSerialRecords({bool refresh = false}) async {
    if (_isLoading || searchQuery.isEmpty) return;

    try {
      _isLoading = true;
      _error = null;
      if (refresh) {
        _offset = 0;
        _hasMore = true;
      }
      notifyListeners();

      final batch = await _fetchPage(0);
      _records = batch;
      _offset = batch.length;
      _hasMore = batch.length >= pageSize;
    } catch (e) {
      _error = 'Failed to fetch serial numbers: ${e.toString()}';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore || searchQuery.isEmpty) {
      return;
    }

    try {
      _isLoadingMore = true;
      notifyListeners();

      final batch = await _fetchPage(_offset);
      _records = [..._records, ...batch];
      _offset += batch.length;
      _hasMore = batch.length >= pageSize;
    } catch (e) {
      _error = 'Failed to load more: ${e.toString()}';
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void resetResults() {
    searchQuery = '';
    _hasSearched = false;
    _records = [];
    _offset = 0;
    _hasMore = true;
    _error = null;
    notifyListeners();
  }
}
