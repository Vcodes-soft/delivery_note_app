import 'dart:convert';
import 'package:delivery_note_app/models/users_model.dart';
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

  Future<void> loadServerConfig(BuildContext context) async {
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
      final connected = await _connectToServer();
      if(connected){
        Navigator.pushNamed(context, '/auth');
      }
    }

    notifyListeners();
  }

  List<User> _allUsers = [];
  List<User> get allUsers => _allUsers;

  Future<List<User>> fetchAllUsers() async {
    try {
      if (!_isServerConnected) {
        throw Exception('Not connected to server');
      }

      final result = await _sqlConnection.getData("""
        SELECT CmpyCode, user_name, password, locCode 
        FROM VW_DM_Users
      """);

      final data = jsonDecode(result) as List;
      _allUsers = data.map((userJson) => User.fromJson(userJson)).toList();
      notifyListeners();
      return _allUsers;
    } catch (e) {
      _allUsers = [];
      notifyListeners();
      throw Exception('Failed to fetch users: $e');
    }
  }

  // Helper method to find users by location
  List<User> getUsersByLocation(String locationCode) {
    return _allUsers.where((user) => user.locationCode == locationCode).toList();
  }

  // Helper method to find a specific user
  User? findUser(String username, String password) {
    try {
      return _allUsers.firstWhere(
            (user) => user.username == username && user.password == password,
      );
    } catch (e) {
      return null;
    }
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

  Future<void> removeSavedConfig() async{
    final prefs = await SharedPreferences.getInstance();
    prefs.clear();
    _serverUrl = '';
    _serverPort = '';
    _serverUserId = '';
    _serverPassword ='';
    _databaseName = '';
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

  String _companyCode = "";


  Future<bool> checkExistingAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get stored values
      final username = prefs.getString('username');
      final password = prefs.getString('password');
      final companyCode = prefs.getString('companyCode');
      final location = prefs.getString('location');

      // Check if all required values exist
      if (username == null || password == null || companyCode == null || location == null) {
        return false;
      }

      // Assign values to provider variables
      _username = username;
      _password = password;
      _companyCode = companyCode;
      _location = location;

      notifyListeners();
      return true;

    } catch (e) {
      return false;
    }
  }


   login(String username, String password,String companyCode, String location) async {
    _username = username;
    _password = password;
    _companyCode = companyCode;
    _location = location;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
    await prefs.setString('password', password);
    await prefs.setString('companyCode', companyCode);
    await prefs.setString('location', location);

    notifyListeners();
  }


  void logout(BuildContext context) async{
    _username = null;
    _password = null;
    _location = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
    await prefs.remove('password');
    await prefs.remove('companyCode',);
    await prefs.remove('location');
    Navigator.pushNamedAndRemoveUntil(context, '/auth',(route) => false);
    notifyListeners();
  }
}