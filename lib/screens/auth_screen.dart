import 'package:delivery_note_app/models/users_model.dart';
import 'package:delivery_note_app/screens/server_configuration.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:delivery_note_app/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedLocation;
  bool _isLoading = false;
  bool _isCheckingAuth = true;
  bool _isLoadingUserData = true;
  bool _obscurePassword = true;
  List<User> _matchingUsers = [];
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
    });
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = 'v${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }


  void _resetForm() {
    if (mounted) {
      setState(() {
        _usernameController.clear();
        _passwordController.clear();
        _selectedLocation = null;
        _matchingUsers = [];
        _obscurePassword = true;
      });
    }
  }

  Future<void> _initializeScreen() async {
    await _checkExistingAuth();
    if (mounted && !_isCheckingAuth) {
      // Only load user data if we're staying on the login screen
      await _loadInitialData();
    }
  }

  Future<void> _checkExistingAuth() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isLoggedIn = await authProvider.checkExistingAuth();
    print(isLoggedIn);

    if (isLoggedIn && mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/dashboard',(route) => false);
    } else {
      setState(() => _isCheckingAuth = false);
    }
  }

  Future<void> _loadInitialData() async {
    try {
      // Clear the form before loading fresh user data
      _resetForm();
      
      setState(() => _isLoadingUserData = true);
      await Provider.of<AuthProvider>(context, listen: false).fetchAllUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load user data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingUserData = false);
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _updateAvailableOptions() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final matchingUsers = authProvider.allUsers.where((user) =>
    user.username == _usernameController.text &&
        user.password == _passwordController.text).toList();

    setState(() {
      _matchingUsers = matchingUsers;

      // Reset location if it's no longer valid
      if (!_matchingUsers.any((user) => user.locationCode == _selectedLocation)) {
        _selectedLocation = null;
      }

      // Auto-select location if only one exists
      if (_selectedLocation == null && _matchingUsers.isNotEmpty) {
        final uniqueLocations = _getUniqueLocationCodes();
        if (uniqueLocations.length == 1) {
          _selectedLocation = uniqueLocations.first;
        }
      }
    });
  }

  List<String> _getUniqueLocationCodes() {
    return _matchingUsers
        .map((user) => user.locationCode)
        .toSet()
        .toList();
  }

  String? _getCompanyCodeForSelectedLocation() {
    if (_selectedLocation == null) return null;
    final user = _matchingUsers.firstWhere(
          (user) => user.locationCode == _selectedLocation,
      orElse: () => User(
        companyCode: '',
        username: '',
        password: '',
        locationCode: '',
      ),
    );
    return user.companyCode.isNotEmpty ? user.companyCode : null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLocation == null) return;

    final companyCode = _getCompanyCodeForSelectedLocation();
    if (companyCode == null) return;

    setState(() => _isLoading = true);

    try {
      await Provider.of<AuthProvider>(context, listen: false).login(
        _usernameController.text,
        _passwordController.text,
        companyCode,
        _selectedLocation!,
      );

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${e.toString()}')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  bool get _canSubmit {
    return _matchingUsers.isNotEmpty &&
        _selectedLocation != null &&
        !_isLoading;
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ServerConfigScreen(fromLogin: true),
                ),
              );
              // Reload data when coming back from server config
              if (mounted) {
                _loadInitialData();
              }
            },
            tooltip: 'Server Configuration',
          ),
        ],
      ),
      body: WillPopScope(
        onWillPop: () async {
          // Reload data when coming back to this screen
          _loadInitialData();
          return true;
        },
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset("assets/logo/techsys_logo.png", height: 100),
                      const SizedBox(height: 16),
                      Consumer<AuthProvider>(
                        builder: (context, authProvider, _) {
                          final serverUrl = authProvider.serverUrl;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.cloud,
                                  size: 16,
                                  color: authProvider.isServerConnected
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  serverUrl != null && serverUrl.isNotEmpty
                                      ? 'Connected to: $serverUrl'
                                      : 'Not connected',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      if (_isLoadingUserData) ...[
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        const Text(
                          'Loading user data from database...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      TextFormField(
                        controller: _usernameController,
                        enabled: !_isLoadingUserData,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter username';
                          }
                          return null;
                        },
                        onChanged: (_) => _updateAvailableOptions(),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        enabled: !_isLoadingUserData,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter password';
                          }
                          return null;
                        },
                        onChanged: (_) => _updateAvailableOptions(),
                      ),
                      if (_matchingUsers.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedLocation,
                          decoration: const InputDecoration(
                            labelText: 'Select Location',
                            prefixIcon: Icon(Icons.location_on),
                          ),
                          items: _getUniqueLocationCodes().map((location) {
                            return DropdownMenuItem<String>(
                              value: location,
                              child: Text(location),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedLocation = value);
                          },
                          validator: (value) {
                            if (_matchingUsers.isNotEmpty && value == null) {
                              return 'Please select a location';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _canSubmit ? _submit : null,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : const Text('Login'),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _appVersion.isNotEmpty ? _appVersion : 'Loading...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
  }
}