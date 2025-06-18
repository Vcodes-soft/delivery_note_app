import 'package:delivery_note_app/models/users_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:delivery_note_app/providers/auth_provider.dart';

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
  List<User> _matchingUsers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkExistingAuth();
      _loadInitialData();
    });
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
    await Provider.of<AuthProvider>(context, listen: false).fetchAllUsers();
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
            onPressed: () {
              // Handle server configuration
              Provider.of<AuthProvider>(context,listen: false).removeSavedConfig();
              Navigator.of(context).pushNamed('/');
            },
            tooltip: 'Server Configuration',
          ),
        ],
      ),
      body: Center(
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
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _usernameController,
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
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}