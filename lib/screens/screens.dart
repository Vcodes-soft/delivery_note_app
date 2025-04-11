// lib/screens/auth_screen.dart
import 'package:flutter/material.dart';


class AddLotScreen extends StatefulWidget {
  const AddLotScreen({super.key});

  @override
  State<AddLotScreen> createState() => _AddLotScreenState();
}

class _AddLotScreenState extends State<AddLotScreen> {

  final _formKey = GlobalKey<FormState>();
  final _serialNoController = TextEditingController();
  final _quantityController = TextEditingController();


  @override
  void dispose() {
    _serialNoController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      // In a real app, this would save to the database/API
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lot added successfully')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Lot')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _serialNoController,
                decoration: const InputDecoration(
                  labelText: 'Serial No',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter serial number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter quantity';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}