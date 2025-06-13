import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../AUTH/providers/auth_provider.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: SettingsScreen());
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> controllers = {
    'firstName': TextEditingController(),
    'lastName': TextEditingController(),
    'email': TextEditingController(),
    'mobile': TextEditingController(),
    'address': TextEditingController(),
  };
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final user = auth.user;
      if (user != null) {
        controllers['firstName']!.text = user.firstName;
        controllers['lastName']!.text = user.lastName;
        controllers['email']!.text = user.email;
        controllers['mobile']!.text = user.mobile;
        controllers['address']!.text = user.address;
      }
    });
  }

  @override
  void dispose() {
    for (var controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      await auth.updateProfile(
        firstName: controllers['firstName']!.text,
        lastName: controllers['lastName']!.text,
        mobile: controllers['mobile']!.text,
        address: controllers['address']!.text,
      );
      setState(() => _isEditing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed:
                _isLoading
                    ? null
                    : () {
                      if (_isEditing) {
                        _updateProfile();
                      } else {
                        setState(() => _isEditing = true);
                      }
                    },
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          if (auth.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = auth.user;
          if (user == null) {
            return const Center(child: Text('No user data available'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(
                      context,
                    ).primaryColor.withOpacity(0.1),
                    child: Icon(
                      Icons.person_outline,
                      size: 50,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome, ${user.username}!',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  _buildField(
                    'First Name',
                    controllers['firstName']!,
                    Icons.person,
                    enabled: _isEditing,
                    validator:
                        (value) =>
                            value?.isEmpty == true
                                ? 'First name is required'
                                : null,
                  ),
                  _buildField(
                    'Last Name',
                    controllers['lastName']!,
                    Icons.person,
                    enabled: _isEditing,
                    validator:
                        (value) =>
                            value?.isEmpty == true
                                ? 'Last name is required'
                                : null,
                  ),
                  _buildField(
                    'Email',
                    controllers['email']!,
                    Icons.email,
                    enabled: false,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  _buildField(
                    'Mobile',
                    controllers['mobile']!,
                    Icons.phone,
                    enabled: _isEditing,
                    keyboardType: TextInputType.phone,
                  ),
                  _buildField(
                    'Address',
                    controllers['address']!,
                    Icons.location_on,
                    enabled: _isEditing,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool enabled = true,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        validator: validator,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: enabled ? Colors.transparent : Colors.grey[100],
        ),
      ),
    );
  }
}
