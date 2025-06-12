import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:webmark/constants.dart';
import 'package:webmark/AUTH/providers/auth_provider.dart';

class AddAssetScreen extends StatefulWidget {
  const AddAssetScreen({super.key});

  @override
  State<AddAssetScreen> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends State<AddAssetScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Form fields
  String _name = '';
  String _serialNumber = '';
  String _model = '';
  String _deviceName = '';
  String _description = '';

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userId = auth.user?.id;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await http.post(
        Uri.parse('${Constants.uri}/api/gpsModule'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'name': _name,
          'serialNumber': _serialNumber,
          'model': _model,
          'deviceName': _deviceName,
          'description': _description,
          'userId': userId,
        }),
      );

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Asset added successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Return true to indicate success
        }
      } else {
        throw Exception('Failed to add asset: ${response.statusCode}');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding asset: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Asset'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Name field
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Asset Name',
                  hintText: 'Enter asset name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an asset name';
                  }
                  return null;
                },
                onSaved: (value) => _name = value!,
              ),
              const SizedBox(height: 16),

              // Serial Number field
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Serial Number',
                  hintText: 'Enter serial number',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a serial number';
                  }
                  return null;
                },
                onSaved: (value) => _serialNumber = value!,
              ),
              const SizedBox(height: 16),

              // Model field
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Model',
                  hintText: 'Enter model name',
                  border: OutlineInputBorder(),
                ),
                onSaved: (value) => _model = value ?? '',
              ),
              const SizedBox(height: 16),

              // Device Name field
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Device Name',
                  hintText: 'Enter device name',
                  border: OutlineInputBorder(),
                ),
                onSaved: (value) => _deviceName = value ?? '',
              ),
              const SizedBox(height: 16),

              // Description field
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter asset description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onSaved: (value) => _description = value ?? '',
              ),
              const SizedBox(height: 24),

              // Submit button
              ElevatedButton(
                onPressed:
                    _isLoading
                        ? null
                        : () {
                          _formKey.currentState!.save();
                          _submitForm();
                        },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : const Text('Add Asset'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
