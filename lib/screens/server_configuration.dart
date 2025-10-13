import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:delivery_note_app/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';


class ServerConfigScreen extends StatefulWidget {
  final bool fromLogin;

  const ServerConfigScreen({super.key, this.fromLogin = false});

  @override
  State<ServerConfigScreen> createState() => _ServerConfigScreenState();
}

class _ServerConfigScreenState extends State<ServerConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverUrlController = TextEditingController();
  final _serverUserIdController = TextEditingController();
  final _serverPasswordController = TextEditingController();
  final _databaseNameController = TextEditingController();
  bool _isConnecting = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedConfig();
  }

  Future<void> _loadSavedConfig() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _serverUrlController.text = prefs.getString('serverUrl') ?? '';
      _serverUserIdController.text = prefs.getString('serverUserId') ?? '';
      _serverPasswordController.text = prefs.getString('serverPassword') ?? '';
      _databaseNameController.text = prefs.getString('databaseName') ?? '';
      _isLoading = false;
    });

    // Auto-connect only if NOT coming from login screen
    if (!widget.fromLogin &&
        _serverUrlController.text.isNotEmpty &&
        _serverUserIdController.text.isNotEmpty &&
        _serverPasswordController.text.isNotEmpty &&
        _databaseNameController.text.isNotEmpty) {
      _autoConnectToServer();
    }
  }

  Future<void> _autoConnectToServer() async {
    setState(() {
      _isConnecting = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.connectToServer(
        url: _serverUrlController.text,
        port: "1433",
        userId: _serverUserIdController.text,
        password: _serverPasswordController.text,
        database: _databaseNameController.text,
      );

      if (success && mounted) {
        Navigator.of(context).pushReplacementNamed('/auth');
      } else {
        setState(() {
          _isConnecting = false;
        });
      }
    } catch (e) {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _serverUserIdController.dispose();
    _serverPasswordController.dispose();
    _databaseNameController.dispose();
    super.dispose();
  }

  Future<void> _connectToServer() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isConnecting = true;
      });

      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final success = await authProvider.connectToServer(
          url: _serverUrlController.text,
          port: "1433",
          userId: _serverUserIdController.text,
          password: _serverPasswordController.text,
          database: _databaseNameController.text,
        );

        if (success) {
          _showToastMessage("Connection Established", Colors.green);

          if (widget.fromLogin && mounted) {
            Navigator.of(context).pop();
          } else if (mounted) {
            Navigator.of(context).pushReplacementNamed('/auth');
          }
        } else {
          final errorMessage = authProvider.lastConnectionError ?? "Connection Failed";
          _showToastMessage(errorMessage, Colors.redAccent);
        }
      } catch (e) {
        _showToastMessage(e.toString(), Colors.redAccent);
      } finally {
        if (mounted) {
          setState(() {
            _isConnecting = false;
          });
        }
      }
    }
  }

  void _showToastMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Configuration'),
        leading: widget.fromLogin
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        )
            : null,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
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
                    const Text(
                      'Server Configuration',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _serverUrlController,
                            decoration: const InputDecoration(
                              labelText: 'Server URL',
                              prefixIcon: Icon(Icons.link),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter server URL';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _serverUserIdController,
                      decoration: const InputDecoration(
                        labelText: 'Server User ID',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter server user ID';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _serverPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Server Password',
                        prefixIcon: Icon(Icons.lock),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter server password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _databaseNameController,
                      decoration: const InputDecoration(
                        labelText: 'Database Name',
                        prefixIcon: Icon(Icons.storage),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter database name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isConnecting ? null : _connectToServer,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: _isConnecting
                          ? const CircularProgressIndicator()
                          : const Text('Connect'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
