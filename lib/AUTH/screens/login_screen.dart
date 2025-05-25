import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
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
                image: DecorationImage(
                  image: AssetImage('assets/background.jpg'),
                  fit: BoxFit.cover,
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
                              padding: EdgeInsets.all(screenSize.width * 0.05),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(32),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Welcome',
                                    style: TextStyle(
                                      color: Colors.purple,
                                      fontSize: welcomeFontSize.clamp(
                                        20.0,
                                        28.0,
                                      ),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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
                                    decoration: const InputDecoration(
                                      labelText: 'Email address',
                                      suffixIcon: Icon(
                                        Icons.check,
                                        color: Colors.purple,
                                      ),
                                    ),
                                    validator:
                                        (value) =>
                                            value?.isEmpty ?? true
                                                ? 'Email is required'
                                                : null,
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _passwordController,
                                    decoration: const InputDecoration(
                                      labelText: 'Password',
                                      suffixIcon: Icon(
                                        Icons.visibility,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    obscureText: true,
                                    validator:
                                        (value) =>
                                            value?.isEmpty ?? true
                                                ? 'Password is required'
                                                : null,
                                  ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    children: [
                                      Row(mainAxisSize: MainAxisSize.min),
                                      TextButton(
                                        onPressed: () {},
                                        child: const Text(
                                          'I forgot my password',
                                          style: TextStyle(color: Colors.grey),
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
                                      height: 50,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.purple,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              32,
                                            ),
                                          ),
                                        ),
                                        onPressed: () {
                                          if (_formKey.currentState
                                                  ?.validate() ??
                                              false) {
                                            auth.login(
                                              _usernameController.text,
                                              _passwordController.text,
                                            );
                                          }
                                        },
                                        child: const Text('LOGIN'),
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
