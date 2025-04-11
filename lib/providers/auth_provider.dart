import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mssql_connection/mssql_connection.dart';

class AuthProvider with ChangeNotifier {
  String? _username;
  String? _password;
  String? _location;
  String? _serverUrl;
  String? _serverPort;
  String? _serverUserId;
  String? _serverPassword;
  String? _databaseName;
  bool _isServerConnected = false;
  final _sqlConnection = MssqlConnection.getInstance();

  String? get username => _username;
  String? get password => _password;
  String? get location => _location;
  String? get serverUrl => _serverUrl;
  String? get serverPort => _serverPort;
  String? get serverUserId => _serverUserId;
  String? get serverPassword => _serverPassword;
  String? get databaseName => _databaseName;
  bool get isAuthenticated => _username != null;
  bool get isServerConnected => _isServerConnected;

  Future<void> loadServerConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _serverUrl = prefs.getString('serverUrl');
    _serverPort = prefs.getString('serverPort');
    _serverUserId = prefs.getString('serverUserId');
    _serverPassword = prefs.getString('serverPassword');
    _databaseName = prefs.getString('databaseName');

    // Try to connect if we have saved config
    if (_serverUrl != null &&
        _serverPort != null &&
        _serverUserId != null &&
        _serverPassword != null &&
        _databaseName != null) {
      await _connectToServer();
    }

    notifyListeners();
  }

  Future<bool> _connectToServer() async {
    try {
      final connected = await _sqlConnection.connect(
        ip: _serverUrl!,
        port: _serverPort!,
        databaseName: _databaseName!,
        username: _serverUserId!,
        password: _serverPassword!,
      );

      _isServerConnected = connected;
      notifyListeners();
      return connected;
    } catch (e) {
      _isServerConnected = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> connectToServer({
    required String url,
    required String port,
    required String userId,
    required String password,
    required String database,
  }) async {
    // Save to shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('serverUrl', url);
    await prefs.setString('serverPort', port);
    await prefs.setString('serverUserId', userId);
    await prefs.setString('serverPassword', password);
    await prefs.setString('databaseName', database);

    _serverUrl = url;
    _serverPort = port;
    _serverUserId = userId;
    _serverPassword = password;
    _databaseName = database;

    // Attempt connection
    final connected = await _connectToServer();

    if (connected) {
      // Test connection with a simple query
      try {
        await _sqlConnection.getData("SELECT 1");
        return true;
      } catch (e) {
        _isServerConnected = false;
        notifyListeners();
        return false;
      }
    }
    return false;
  }

  void login(String username, String password, String location) {
    _username = username;
    _password = password;
    _location = location;
    notifyListeners();
  }

  void logout() {
    _username = null;
    _password = null;
    _location = null;
    notifyListeners();
  }
}