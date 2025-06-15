import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

class GpsAssetService {
  final String baseUrl = '${Constants.uri}/api';
  final String userId; // Add userId field

  GpsAssetService({required this.userId}); // Require userId in constructor

  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  // Control engine state
  Future<bool> controlEngine(String assetId, bool state) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/module/$assetId/engine'),
        headers: _headers,
        body: jsonEncode({
          'state': state,
          'userId': userId, // Include userId in request
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to control engine: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to control engine: $e');
    }
  }

  // Control power state
  Future<bool> controlPower(String assetId, bool state) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/module/$assetId/power'),
        headers: _headers,
        body: jsonEncode({
          'state': state,
          'userId': userId, // Include userId in request
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to control power: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to control power: $e');
    }
  }

  // Trigger beep alarm
  Future<bool> triggerAlarm(String assetId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/module/$assetId/alarm'),
        headers: _headers,
        body: jsonEncode({'userId': userId}), // Include userId in request
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to trigger alarm: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to trigger alarm: $e');
    }
  }

  // Activate lost mode
  Future<bool> activateLostMode(String assetId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/module/$assetId/lost-mode'),
        headers: _headers,
        body: jsonEncode({'userId': userId}), // Include userId in request
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to activate lost mode: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to activate lost mode: $e');
    }
  }

  // Restore defaults
  Future<bool> restoreDefaults(String assetId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/module/$assetId/restore'),
        headers: _headers,
        body: jsonEncode({'userId': userId}), // Include userId in request
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to restore defaults: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to restore defaults: $e');
    }
  }

  // Get latest asset status
  Future<Map<String, dynamic>> getAssetStatus(String assetId) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/module/$assetId/status?userId=$userId',
        ), // Include userId as query param
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get asset status: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to get asset status: $e');
    }
  }

  // Get module status
  Future<Map<String, dynamic>> getModuleStatus(String assetId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/module/$assetId/status'),
        headers: _headers,
        body: jsonEncode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] && data['status'] != null) {
          return data['status'];
        }
        throw Exception('Invalid status response');
      } else {
        throw Exception('Failed to get status: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to get status: $e');
    }
  }
}
