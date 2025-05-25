import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webmark/AUTH/providers/auth_provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (auth.isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (auth.error != null) {
      return Scaffold(body: Center(child: Text('Error: ${auth.error}')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard'),
        actions: [
          IconButton(icon: Icon(Icons.logout), onPressed: () => auth.logout()),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome, ${auth.user?.username ?? "Guest"}!'),
            Text('Email: ${auth.user?.email ?? "N/A"}'),
          ],
        ),
      ),
    );
  }
}
