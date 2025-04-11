import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:delivery_note_app/providers/auth_provider.dart';
import 'package:toast_message_bar/toast_message_bar.dart';

class ServerConfigScreen extends StatefulWidget {
  const ServerConfigScreen({super.key});

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

  @override
  void initState() {
    super.initState();

    _loadDefaultConfig();
    _loadSavedConfig();
  }

  Future<void> _loadDefaultConfig()async {
    _serverUrlController.text = "192.168.30.142";
    _serverUserIdController.text = "silveradmin";
    _serverPasswordController.text = "admin\$ilver";
    _databaseNameController.text = "Techsysdb";
  }

  Future<void> _loadSavedConfig() async {
    await Provider.of<AuthProvider>(context, listen: false).loadServerConfig();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.serverUrl != null) {
      _serverUrlController.text = authProvider.serverUrl!;
    }
    if (authProvider.serverUserId != null) {
      _serverUserIdController.text = authProvider.serverUserId!;
    }
    if (authProvider.serverPassword != null) {
      _serverPasswordController.text = authProvider.serverPassword!;
    }
    if (authProvider.databaseName != null) {
      _databaseNameController.text = authProvider.databaseName!;
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
        final success = await Provider.of<AuthProvider>(context, listen: false).connectToServer(
          url: _serverUrlController.text,
          port: "1433",
          userId: _serverUserIdController.text,
          password: _serverPasswordController.text,
          database: _databaseNameController.text,
        );

        if (success) {
          await _showToastMessage("Connection Established", Colors.green);
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/auth');
          }
        } else {
          await _showToastMessage("Connection Failed", Colors.redAccent);
        }
      } catch (e) {
        await _showToastMessage(e.toString(), Colors.redAccent);
      } finally {
        if (mounted) {
          setState(() {
            _isConnecting = false;
          });
        }
      }
    }
  }

  Future<void> _showToastMessage(String message, Color color) async {
    await ToastMessageBar(
      backgroundColor: color,
      title: color == Colors.green ? "SUCCESS" : "ERROR",
      titleColor: Colors.white,
      message: message,
      messageColor: Colors.white,
      duration: const Duration(seconds: 3),
    ).show(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    const FlutterLogo(size: 100),
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