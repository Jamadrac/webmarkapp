import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:logging/logging.dart';
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
  Position? _currentPosition; // Added missing field
  String? _errorMessage;
  bool _loading = false;
  bool _updating = false;
  DateTime? _lastUpdateTime;
  Timer? _periodicTimer;
  LocationPermission? _permissionStatus;

  // WebSocket related variables
  IO.Socket? _socket;
  bool _isSocketConnected = false;
  final Logger _logger = Logger('GPSDevice');
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _requestPermission();
      // Initialize current position after permission
      _currentPosition = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _disconnectWebSocket();
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

      // Also send location via WebSocket if connected
      _sendLocationViaWebSocket(serialNumber, latitude, longitude);
    } catch (error) {
      throw Exception('Failed to update location: $error');
    }
  }

  // WebSocket connection methods
  void _connectWebSocket() {
    if (_isSocketConnected || _baseUrl.isEmpty) return;

    try {
      final finalBaseUrl = _baseUrl.isNotEmpty ? _baseUrl : Constants.uri;

      _socket = IO.io(finalBaseUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
      });

      _socket!.connect();

      _socket!.on('connect', (_) {
        setState(() => _isSocketConnected = true);
        _logger.info('WebSocket connected');
        _showSuccessToast('Real-time connection established');

        // Register device with server
        if (_serialNumber.isNotEmpty) {
          _registerDevice();
        }

        // Start heartbeat
        _startHeartbeat();
      });

      _socket!.on('disconnect', (_) {
        setState(() => _isSocketConnected = false);
        _logger.info('WebSocket disconnected');
        _showErrorToast('Real-time connection lost');
        _stopHeartbeat();
      });

      _socket!.on('connect_error', (error) {
        setState(() => _isSocketConnected = false);
        _logger.severe('WebSocket connection error: $error');
        _showErrorToast('Failed to establish real-time connection');
      });

      _socket!.on('pong', (_) {
        _logger.fine('Heartbeat pong received');
      });
    } catch (e) {
      _logger.severe('Error initializing WebSocket: $e');
      _showErrorToast('WebSocket setup failed: $e');
    }
  }

  void _disconnectWebSocket() {
    _stopHeartbeat();
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      setState(() => _isSocketConnected = false);
    }
  }

  void _registerDevice() {
    if (_socket != null && _isSocketConnected && _serialNumber.isNotEmpty) {
      _socket!.emit('register-device', {
        'serialNumber': _serialNumber,
        'deviceInfo': {
          'platform': 'Flutter',
          'timestamp': DateTime.now().toIso8601String(),
        },
      });
      _logger.info('Device registered with serial: $_serialNumber');
    }
  }

  void _sendLocationViaWebSocket(
    String serialNumber,
    double latitude,
    double longitude,
  ) {
    if (_socket != null && _isSocketConnected) {
      final locationData = {
        'serialNumber': serialNumber,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': DateTime.now().toIso8601String(),
        'accuracy': _location?.accuracy,
        'speed': _location?.speed,
        'altitude': _location?.altitude,
      };

      _socket!.emit('location-update', locationData);
      _logger.info('Location sent via WebSocket: $latitude, $longitude');
    }
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_socket != null && _isSocketConnected) {
        _socket!.emit('ping');
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // Simulation methods for testing
  void _simulateRandomMovement() async {
    if (!_isSocketConnected || _serialNumber.isEmpty) {
      _showErrorToast('WebSocket not connected or serial number missing');
      return;
    }

    try {
      // Get current position or use a default
      double baseLat = _currentPosition?.latitude ?? -1.2921; // Nairobi default
      double baseLng = _currentPosition?.longitude ?? 36.8219;

      // Generate random movement within ~1km radius
      final random = Random();
      double newLat = baseLat + (random.nextDouble() - 0.5) * 0.01;
      double newLng = baseLng + (random.nextDouble() - 0.5) * 0.01;

      await _sendLocationUpdate(_serialNumber, newLat, newLng);
      _showSuccessToast('Random location simulated');
    } catch (e) {
      _showErrorToast('Simulation failed: $e');
    }
  }

  void _simulateCircularMovement() async {
    if (!_isSocketConnected || _serialNumber.isEmpty) {
      _showErrorToast('WebSocket not connected or serial number missing');
      return;
    }

    try {
      double baseLat = _currentPosition?.latitude ?? -1.2921;
      double baseLng = _currentPosition?.longitude ?? 36.8219;

      // Circular movement pattern
      double angle = DateTime.now().millisecondsSinceEpoch / 10000.0;
      double radius = 0.005; // ~500m radius

      double newLat = baseLat + radius * cos(angle);
      double newLng = baseLng + radius * sin(angle);

      await _sendLocationUpdate(_serialNumber, newLat, newLng);
      _showSuccessToast('Circular movement simulated');
    } catch (e) {
      _showErrorToast('Simulation failed: $e');
    }
  }

  void _simulateLinearMovement() async {
    if (!_isSocketConnected || _serialNumber.isEmpty) {
      _showErrorToast('WebSocket not connected or serial number missing');
      return;
    }

    try {
      double baseLat = _currentPosition?.latitude ?? -1.2921;
      double baseLng = _currentPosition?.longitude ?? 36.8219;

      // Linear movement (north-south)
      double offset = (DateTime.now().millisecondsSinceEpoch % 60000) / 60000.0;
      double newLat = baseLat + (offset - 0.5) * 0.01;
      double newLng = baseLng;

      await _sendLocationUpdate(_serialNumber, newLat, newLng);
      _showSuccessToast('Linear movement simulated');
    } catch (e) {
      _showErrorToast('Simulation failed: $e');
    }
  }

  void startPeriodicUpdates() {
    if (_permissionStatus != LocationPermission.whileInUse &&
        _permissionStatus != LocationPermission.always) {
      _showErrorToast('Location permission required');
      return;
    }

    // Connect to WebSocket for real-time updates
    _connectWebSocket();

    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _updateLocation();
    });
    _showSuccessToast('Started periodic updates (every 1 minute)');
  }

  void stopPeriodicUpdates() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _disconnectWebSocket();
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

  // Add _sendLocationUpdate method
  Future<void> _sendLocationUpdate(
    String serialNumber,
    double lat,
    double lng,
  ) async {
    if (!mounted) return;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/gpsModules/update-location'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'serialNumber': serialNumber,
          'latitude': lat,
          'longitude': lng,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _lastUpdateTime = DateTime.now();
        });
      } else {
        throw Exception('Failed to update location');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to update location: $e';
        });
      }
      _logger.warning('Failed to update location: $e');
    }
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
                            'Connection Status',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  _isSocketConnected
                                      ? Colors.green
                                      : Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _isSocketConnected ? '🟢 Live' : '🔴 Offline',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isSocketConnected
                            ? 'Real-time connection established'
                            : 'No real-time connection',
                        style: TextStyle(
                          color:
                              _isSocketConnected ? Colors.green : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
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

              // Simulation Controls Section
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                '🎯 Movement Simulation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Test real-time tracking with simulated movement patterns',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              // Simulation Buttons Row 1
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          _isSocketConnected ? _simulateRandomMovement : null,
                      icon: const Icon(Icons.shuffle),
                      label: const Text('Random'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          _isSocketConnected ? _simulateCircularMovement : null,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Circular'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Simulation Buttons Row 2
              ElevatedButton.icon(
                onPressed: _isSocketConnected ? _simulateLinearMovement : null,
                icon: const Icon(Icons.trending_up),
                label: const Text('Linear Movement'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),

              const SizedBox(height: 8),
              Text(
                _isSocketConnected
                    ? '✅ Ready for simulation'
                    : '⚠️ Connect to server first',
                style: TextStyle(
                  fontSize: 12,
                  color: _isSocketConnected ? Colors.green : Colors.orange,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
