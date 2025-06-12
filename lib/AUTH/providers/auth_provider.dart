import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webmark/AUTH/models/user_model.dart';
import 'package:webmark/constants.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _error;
  User? _user;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;
  User? get user => _user;
  Future<void> login(String username, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      print('Attempting login to: ${Constants.uri}/api/login');
      print('Username: $username');
      print(
        'Request body: ${json.encode({'username': username, 'password': password})}',
      );

      final response = await http
          .post(
            Uri.parse('${Constants.uri}/api/login'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({'username': username, 'password': password}),
          )
          .timeout(const Duration(seconds: 30));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Login response data: $data');

        // Check if we have the required fields
        if (data['id'] != null && data['username'] != null) {
          _isAuthenticated = true;
          _user = User.fromJson(data);
          _error = null;

          // Save authentication state and user details
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isAuthenticated', true);
          await prefs.setString('user', json.encode(data));
          await prefs.setString('token', data['token'] ?? '');

          print('Login successful for user: ${_user?.username}');
        } else {
          _error = 'Invalid response format from server';
          _isAuthenticated = false;
          print('Login failed: Invalid response format - $data');
        }
      } else {
        final errorData = json.decode(response.body);
        _error =
            errorData['error'] ??
            'Login failed with status ${response.statusCode}';
        _isAuthenticated = false;
        print('Login failed: $_error');
        print('Error response body: ${response.body}');
      }
    } catch (e) {
      _error = 'Network error occurred: $e';
      _isAuthenticated = false;
      print('Login error: $e');
      print('Error type: ${e.runtimeType}');

      // Check if it's a timeout error
      if (e.toString().contains('TimeoutException')) {
        _error = 'Request timeout. Please check your internet connection.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isAuthenticated = false;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }

  Future<void> checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _isAuthenticated = prefs.getBool('isAuthenticated') ?? false;

    if (_isAuthenticated) {
      final userData = prefs.getString('user');
      if (userData != null) {
        _user = User.fromJson(json.decode(userData));
      }
    }
    notifyListeners();
  }

  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    required String mobile,
    required String address,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await http.put(
        Uri.parse('${Constants.uri}/api/updateuser'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'firstName': firstName,
          'lastName': lastName,
          'mobile': mobile,
          'address': address,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _user = User.fromJson(data['user']);
        _error = null;

        // Update stored user details
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', json.encode(data['user']));
      } else {
        final errorData = json.decode(response.body);
        _error = errorData['error'] ?? 'Failed to update profile';
        throw Exception(_error);
      }
    } catch (e) {
      _error = 'Error updating profile: $e';
      throw Exception(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Test function to debug login
  Future<void> testLogin() async {
    try {
      print('Testing server connection...');

      // Test basic server connectivity
      final healthResponse = await http.get(Uri.parse(Constants.uri));
      print(
        'Health check: ${healthResponse.statusCode} - ${healthResponse.body}',
      );

      // Test login endpoint with dummy data
      final testResponse = await http.post(
        Uri.parse('${Constants.uri}/api/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'username': 'test', 'password': 'test'}),
      );

      print('Test login status: ${testResponse.statusCode}');
      print('Test login response: ${testResponse.body}');
    } catch (e) {
      print('Test error: $e');
    }
  }
}
