// lib/helpers/mssql_helper.dart
import 'dart:convert';

import 'package:mssql_connection/mssql_connection.dart';

class MSSQLHelper {
  // Singleton instance
  static final MSSQLHelper _instance = MSSQLHelper._internal();
  final MssqlConnection _connection = MssqlConnection.getInstance();

  // Private constructor
  MSSQLHelper._internal();

  // Factory constructor to return the same instance
  factory MSSQLHelper() => _instance;

  // Get the connection instance
  MssqlConnection get connection => _connection;

  // Connection status
  bool get isConnected => _connection.isConnected;

  // Connect to server
  Future<bool> connect({
    required String server,
    required String port,
    required String username,
    required String password,
    required String database,
  }) async {
    try {
      return await _connection.connect(
        ip: server,
        port: port,
        databaseName: database,
        username: username,
        password: password,
      );
    } catch (e) {
      throw Exception('Failed to connect to database: $e');
    }
  }

  // Disconnect from server
  Future<void> disconnect() async {
    try {
      await _connection.disconnect();
    } catch (e) {
      throw Exception('Failed to disconnect from database: $e');
    }
  }

  // Execute query and return results
  Future<List<Map<String, dynamic>>> executeQuery(String query) async {
    try {
      if (!isConnected) {
        throw Exception('Not connected to database');
      }

      final result = await _connection.getData(query);
      final decoded = jsonDecode(result) as List;
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception('Query execution failed: $e');
    }
  }

  // Execute non-query command
  // Future<int> executeNonQuery(String command) async {
  //   try {
  //     if (!isConnected) {
  //       throw Exception('Not connected to database');
  //     }
  //
  //     final result = await _connection.execute(command);
  //     return result;
  //   } catch (e) {
  //     throw Exception('Command execution failed: $e');
  //   }
  // }
}