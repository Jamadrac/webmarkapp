import 'dart:async'
    show StreamSubscription; // Added import for StreamSubscription
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:logging/logging.dart';

class LocationTracker extends StatefulWidget {
  const LocationTracker({super.key}); // Updated constructor syntax

  @override
  State<LocationTracker> createState() => _LocationTrackerState();
}

class _LocationTrackerState extends State<LocationTracker> {
  Position? _location;
  String? _errorMsg;
  bool _isTracking = false;
  socket_io.Socket? _socket;
  StreamSubscription<Position>? _locationSubscription;

  // Configuration constants
  static const String _baseUrl = 'http://your-server-url.com';
  static const String _deviceId =
      'unique-device-id'; // Replace with actual device ID

  // Updated to use int for duration and filter
  static const int _trackingIntervalSeconds = 5;
  static const int _distanceFilter = 10; // meters

  // Logger setup
  final Logger _logger = Logger('LocationTracker');

  @override
  void initState() {
    super.initState();
    // Configure logging
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      debugPrint('${record.level.name}: ${record.time}: ${record.message}');
    });

    _initSocket();
    _checkLocationPermission();
  }

  void _initSocket() {
    try {
      _socket = socket_io.io(_baseUrl, <String, dynamic>{
        'transports': ['websocket'],
      });

      _socket?.onConnect((_) {
        _logger.info('Socket connected');
      });

      _socket?.onConnectError((error) {
        _logger.warning('Socket connection error: $error');
      });
    } catch (e) {
      _logger.severe('Socket initialization error: $e');
    }
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _errorMsg = 'Location services are disabled';
      });
      return;
    }

    // Check location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _errorMsg = 'Location permissions are denied';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _errorMsg = 'Location permissions are permanently denied';
      });
      return;
    }
  }

  void _startTracking() {
    setState(() {
      _isTracking = true;
      _errorMsg = null;
    });

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _distanceFilter,
        timeLimit: Duration(seconds: _trackingIntervalSeconds),
      ),
    ).listen((Position position) {
      setState(() {
        _location = position;
      });

      // Emit location update via socket
      _socket?.emit('location_update', {
        'deviceId': _deviceId,
        'latitude': position.latitude,
        'longitude': position.longitude,
      });
    }, onError: (error) {
      setState(() {
        _errorMsg = 'Location tracking error: $error';
        _isTracking = false;
      });
      _logger.warning('Location tracking error: $error');
    });
  }

  void _stopTracking() {
    _locationSubscription?.cancel();
    setState(() {
      _isTracking = false;
      _location = null;
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _socket?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Tracker'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Device ID: $_deviceId'),

            // Error message display
            if (_errorMsg != null)
              Text(
                _errorMsg!,
                style: const TextStyle(color: Colors.red),
              ),

            // Location display
            if (_location != null)
              Text(
                'Latitude: ${_location!.latitude}, Longitude: ${_location!.longitude}',
                style: const TextStyle(fontSize: 16),
              )
            else
              const Text('Waiting for location...'),

            const SizedBox(height: 20),

            // Tracking control button
            ElevatedButton(
              onPressed: _isTracking ? _stopTracking : _startTracking,
              child: Text(_isTracking ? 'Stop Tracking' : 'Start Tracking'),
            ),
          ],
        ),
      ),
    );
  }
}
