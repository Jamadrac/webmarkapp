import 'package:flutter/material.dart';
import 'package:webmark/AUTH/providers/auth_provider.dart';
import 'package:webmark/AUTH/screens/login_screen.dart';
import 'package:webmark/Body.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
      child: const MyApp(), // Added const
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key}); // Added key parameter

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auth Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
        ),
      ),
      home: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          // Fixed builder signature
          if (auth.isAuthenticated) {
            return const MainScreen();
          } else {
            return LoginScreen();
          }
        },
      ),
    );
  }
}
