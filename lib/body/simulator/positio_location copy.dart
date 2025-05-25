import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:async';
import '../../constants.dart';

class GPSDevice extends StatefulWidget {
  const GPSDevice({super.key});

  @override
  _GPSDeviceState createState() => _GPSDeviceState();
}

class _GPSDeviceState extends State<GPSDevice> {
  String _serialNumber = '';
  String _baseUrl = Constants.uri;
  Position? _location;
  String? _errorMessage;
  bool _loading = false;
  bool _updating = false;
  DateTime? _lastUpdateTime;
  Timer? _periodicTimer;
  LocationPermission? _permissionStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermission();
    });
  }

  @override
  void dispose() {
    stopPeriodicUpdates();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (BuildContext context) => AlertDialog(
                title: const Text('Location Services Disabled'),
                content: const Text(
                  'Please enable Location Services in your device settings to continue.',
                ),
                actions: [
                  TextButton(
                    child: const Text('Open Settings'),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await Geolocator.openLocationSettings();
                    },
                  ),
                ],
              ),
        );

        // Recheck if services were enabled
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          throw Exception('Location services are still disabled');
        }
      }

      // Check current permission status
      _permissionStatus = await Geolocator.checkPermission();

      if (_permissionStatus == LocationPermission.denied) {
        // Show explanation before requesting permission
        bool shouldRequest =
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder:
                  (BuildContext context) => AlertDialog(
                    title: const Text('Location Permission Required'),
                    content: const Text(
                      'This app needs access to location to update GPS coordinates. '
                      'Would you like to grant permission?',
                    ),
                    actions: [
                      TextButton(
                        child: const Text('Deny'),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                      TextButton(
                        child: const Text('Continue'),
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ],
                  ),
            ) ??
            false;

        if (shouldRequest) {
          _permissionStatus = await Geolocator.requestPermission();
          if (_permissionStatus == LocationPermission.denied) {
            throw Exception('Location permission denied');
          }
        } else {
          throw Exception('Permission request declined');
        }
      }

      if (_permissionStatus == LocationPermission.deniedForever) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (BuildContext context) => AlertDialog(
                title: const Text('Permission Required'),
                content: const Text(
                  'Location permission is permanently denied. '
                  'Please enable it in your device settings.',
                ),
                actions: [
                  TextButton(
                    child: const Text('Open Settings'),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await Geolocator.openAppSettings();
                    },
                  ),
                ],
              ),
        );
        throw Exception('Location permissions are permanently denied');
      }

      // Initialize location after permissions are granted
      await _initializeLocation();
      _showSuccessToast('Location permission granted');
    } catch (e) {
      setState(() => _errorMessage = e.toString());
      _showErrorToast(_errorMessage!);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _initializeLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _location = position;
        _lastUpdateTime = DateTime.now();
      });
    } catch (e) {
      throw Exception('Error getting initial location: $e');
    }
  }

  Future<void> _updateLocation() async {
    if (_updating || _loading) return;

    setState(() {
      _updating = true;
      _errorMessage = null;
    });

    try {
      // Verify permissions before updating
      if (_permissionStatus != LocationPermission.whileInUse &&
          _permissionStatus != LocationPermission.always) {
        await _requestPermission();
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _location = position;
        _lastUpdateTime = DateTime.now();
      });

      if (_serialNumber.isEmpty || _baseUrl.isEmpty) {
        throw Exception('Serial number and base URL are required');
      }

      final finalBaseUrl = _baseUrl.isNotEmpty ? _baseUrl : Constants.uri;
      await _sendLocationToBackend(
        finalBaseUrl,
        _serialNumber,
        position.latitude,
        position.longitude,
      );

      _showSuccessToast('Location updated successfully');
    } catch (e) {
      setState(() => _errorMessage = e.toString());
      _showErrorToast(_errorMessage!);
    } finally {
      setState(() => _updating = false);
    }
  }

  Future<void> _sendLocationToBackend(
    String baseUrl,
    String serialNumber,
    double latitude,
    double longitude,
  ) async {
    try {
      final response = await http
          .patch(
            Uri.parse('$baseUrl/api/update-location'),
            body: jsonEncode({
              'serialNumber': serialNumber,
              'latitude': latitude,
              'longitude': longitude,
              'timestamp': DateTime.now().toIso8601String(),
            }),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Connection timeout'),
          );

      if (response.statusCode != 200) {
        throw Exception(
          'Server error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (error) {
      throw Exception('Failed to update location: $error');
    }
  }

  void startPeriodicUpdates() {
    if (_permissionStatus != LocationPermission.whileInUse &&
        _permissionStatus != LocationPermission.always) {
      _showErrorToast('Location permission required');
      return;
    }

    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _updateLocation();
    });
    _showSuccessToast('Started periodic updates (every 1 minute)');
  }

  void stopPeriodicUpdates() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    setState(() => _updating = false);
    _showSuccessToast('Stopped periodic updates');
  }

  void _showErrorToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.TOP,
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
  }

  void _showSuccessToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.TOP,
      backgroundColor: Colors.green,
      textColor: Colors.white,
    );
  }

  String get _formattedLastUpdateTime {
    if (_lastUpdateTime == null) return 'Never';
    return 'Last updated: ${_lastUpdateTime!.hour}:${_lastUpdateTime!.minute.toString().padLeft(2, '0')}:${_lastUpdateTime!.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS Device Simulator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _requestPermission,
            tooltip: 'Reset Permissions',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_permissionStatus == LocationPermission.denied ||
                  _permissionStatus == LocationPermission.deniedForever)
                Card(
                  color: Colors.red[100],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text(
                          'Location Permission Required',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _requestPermission,
                          child: const Text('Grant Permission'),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'server URL',
                  hintText: 'Enter base URL',
                  border: const OutlineInputBorder(),
                  errorText:
                      _baseUrl.isEmpty && _errorMessage != null
                          ? 'Base URL is required'
                          : null,
                ),
                onChanged: (value) => setState(() => _baseUrl = value.trim()),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Serial Number',
                  hintText: 'Enter serial number',
                  border: const OutlineInputBorder(),
                  errorText:
                      _serialNumber.isEmpty && _errorMessage != null
                          ? 'Serial number is required'
                          : null,
                ),
                onChanged:
                    (value) => setState(() => _serialNumber = value.trim()),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Location Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_loading)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_location != null) ...[
                        Text(
                          'Latitude: ${_location!.latitude.toStringAsFixed(6)}',
                        ),
                        Text(
                          'Longitude: ${_location!.longitude.toStringAsFixed(6)}',
                        ),
                        Text(
                          'Altitude: ${_location!.altitude.toStringAsFixed(2)} meters',
                        ),
                        Text(
                          'Speed: ${_location!.speed.toStringAsFixed(2)} m/s',
                        ),
                        Text(
                          'Accuracy: ${_location!.accuracy.toStringAsFixed(2)} meters',
                        ),
                        const SizedBox(height: 8),
                        Text(_formattedLastUpdateTime),
                      ] else
                        const Text('No location data available'),
                    ],
                  ),
                ),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Card(
                    color: Colors.red[100],
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loading || _updating ? null : _updateLocation,
                      child:
                          _updating
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Update Location'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _periodicTimer == null ? startPeriodicUpdates : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text('Start Auto Update'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _periodicTimer != null ? stopPeriodicUpdates : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Stop Updates'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
