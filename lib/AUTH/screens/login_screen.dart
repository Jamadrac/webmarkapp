import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../Body.dart'; // Import MainScreen
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

// Define the URL you want to open
final String url = 'https://webmarck.vercel.app/login';

// Function to launch the URL
Future<void> _launchURL() async {
  if (await canLaunch(url)) {
    await launch(url);
  } else {
    throw 'Could not launch $url';
  }
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Add listener for auth state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      auth.addListener(() {
        if (auth.isAuthenticated && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final smallScreen = screenSize.width < 600;

    // Calculate responsive padding and sizes
    final contentPadding = EdgeInsets.all(screenSize.width * 0.04);
    final iconSize = screenSize.width * 0.15;
    final titleFontSize = screenSize.width * 0.06;
    final welcomeFontSize = screenSize.width * 0.05;

    // Ensure form doesn't exceed screen width
    final formWidth =
        smallScreen ? screenSize.width * 0.9 : screenSize.width * 0.6;
    return Scaffold(
      body: Consumer<AuthProvider>(
        builder:
            (context, auth, _) => Container(
              height: screenSize.height,
              width: screenSize.width,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF3F4F6), Color(0xFFE5E7EB)],
                ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: contentPadding,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_on,
                            size: iconSize.clamp(40, 80),
                            color: Colors.white,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'GO MAP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: titleFontSize.clamp(24.0, 32.0),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 32),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: formWidth),
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x1A000000),
                                    blurRadius: 15,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  ClipOval(
                                    child: Container(
                                      width: 96,
                                      height: 96,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Theme.of(context).primaryColor,
                                          width: 2,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.location_on,
                                        size: 48,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Welcome Back',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.displayLarge?.copyWith(
                                      fontSize: 28,
                                      color: const Color(0xFF1F2937),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  const SizedBox(height: 8),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Please login with your information',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: smallScreen ? 14 : 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  if (auth.error != null)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 16.0,
                                      ),
                                      child: Text(
                                        auth.error!,
                                        style: const TextStyle(
                                          color: Colors.red,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  TextFormField(
                                    controller: _usernameController,
                                    decoration: InputDecoration(
                                      labelText: 'Email address',
                                      suffixIcon: Icon(
                                        Icons.email_outlined,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your email';
                                      }
                                      if (!value.contains('@')) {
                                        return 'Please enter a valid email';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _passwordController,
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      suffixIcon: Icon(
                                        Icons.lock_outline,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                    obscureText: true,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your password';
                                      }
                                      if (value.length < 6) {
                                        return 'Password must be at least 6 characters';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    children: [
                                      TextButton(
                                        onPressed: () => _launchURL(),
                                        child: Text(
                                          'Forgot Password?',
                                          style: TextStyle(
                                            color:
                                                Theme.of(context).primaryColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  if (auth.isLoading)
                                    const CircularProgressIndicator()
                                  else
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          if (_formKey.currentState!
                                              .validate()) {
                                            await auth.login(
                                              _usernameController.text,
                                              _passwordController.text,
                                            );
                                            if (auth.isAuthenticated &&
                                                mounted) {
                                              Navigator.pushReplacement(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (context) =>
                                                          const MainScreen(),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.all(12.0),
                                          child: Text(
                                            'Login',
                                            style: TextStyle(fontSize: 16),
                                          ),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 16),
                                  const Text('Or Login with'),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 16,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.facebook,
                                          color: Colors.blueAccent,
                                        ),
                                        iconSize: smallScreen ? 24 : 32,
                                        onPressed: () {},
                                      ),
                                      // Using X/Twitter logo
                                      // Container(
                                      //   width: smallScreen ? 24 : 32,
                                      //   height: smallScreen ? 24 : 32,
                                      //   decoration: const BoxDecoration(
                                      //     image: DecorationImage(
                                      //       image: AssetImage(
                                      //         'assets/x-logo.png',
                                      //       ),
                                      //       fit: BoxFit.contain,
                                      //     ),
                                      //   ),
                                      // ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.webhook,
                                          color: Colors.black87,
                                        ),
                                        iconSize: smallScreen ? 24 : 32,
                                        onPressed: _launchURL,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
