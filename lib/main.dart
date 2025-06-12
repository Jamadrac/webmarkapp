import 'package:flutter/material.dart';
import 'package:webmark/AUTH/providers/auth_provider.dart';
import 'package:webmark/AUTH/screens/login_screen.dart';
import 'package:webmark/Body.dart';
import 'package:provider/provider.dart';
import 'package:webmark/theme/colors.dart';

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
      title: 'GO MAP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Primary colors from Siemens brand
        primaryColor: const Color(0xFF009999), // Siemens Petrol
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF009999),
          primary: const Color(0xFF009999), // Siemens Petrol
          primaryContainer: const Color(0xFF00B2B2), // Siemens Petrol Light
          secondary: const Color(0xFF000000), // Siemens Black
          secondaryContainer: const Color(0xFF333333), // Siemens Black Light
          background: const Color(0xFFF5F5F5), // Light Gray
          surface: const Color(0xFFFFFFFF), // White
          error: const Color(0xFFCC0000), // Siemens Red
        ),
        // Custom accent colors
        extensions: <ThemeExtension<dynamic>>[
          CustomColors(
            blue: const Color(0xFF003087),
            green: const Color(0xFF50AF47),
            yellow: const Color(0xFFFFD500),
            orange: const Color(0xFFFF8F0F),
            purple: const Color(0xFF962B97),
            coolGray: const Color(0xFF879299),
          ),
        ],
        // Typography
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontFamily: 'SiemensSans',
            color: Color(0xFF000000),
            fontWeight: FontWeight.bold,
          ),
          displayMedium: TextStyle(
            fontFamily: 'SiemensSans',
            color: Color(0xFF000000),
            fontWeight: FontWeight.bold,
          ),
          displaySmall: TextStyle(
            fontFamily: 'SiemensSans',
            color: Color(0xFF000000),
            fontWeight: FontWeight.bold,
          ),
          headlineLarge: TextStyle(
            fontFamily: 'SiemensSans',
            color: Color(0xFF000000),
            fontWeight: FontWeight.bold,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'SiemensSans',
            color: Color(0xFF000000),
            fontWeight: FontWeight.bold,
          ),
          headlineSmall: TextStyle(
            fontFamily: 'SiemensSans',
            color: Color(0xFF000000),
            fontWeight: FontWeight.bold,
          ),
          titleLarge: TextStyle(
            fontFamily: 'SiemensSans',
            color: Color(0xFF505050),
            fontWeight: FontWeight.normal,
          ),
          titleMedium: TextStyle(
            fontFamily: 'SiemensSans',
            color: Color(0xFF505050),
            fontWeight: FontWeight.normal,
          ),
          titleSmall: TextStyle(
            fontFamily: 'SiemensSans',
            color: Color(0xFF505050),
            fontWeight: FontWeight.normal,
          ),
          bodyLarge: TextStyle(
            fontFamily: 'SiemensSans',
            color: Color(0xFF505050),
            fontWeight: FontWeight.normal,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'SiemensSans',
            color: Color(0xFF505050),
            fontWeight: FontWeight.normal,
          ),
          bodySmall: TextStyle(
            fontFamily: 'SiemensSans',
            color: Color(0xFF879299),
            fontWeight: FontWeight.normal,
          ),
        ),
        // Default button style
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF009999),
            foregroundColor: Colors.white,
            minimumSize: const Size(44, 44), // Improved touch target
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
        // Card theme
        cardTheme: CardTheme(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        // App bar theme
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF009999),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      // ... rest of the app configuration
      home: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          if (auth?.isLoading ?? false) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return auth?.isAuthenticated ?? false
              ? const MainScreen()
              : const LoginScreen();
        },
      ),
    );
  }
}
