import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
// import 'package:http/http.dart' as http; // Keep if still used for non-P2P things
import 'dart:convert';
import 'dart:math';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:logging/logging.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart'; // Added for WebRTC
import '../../constants.dart';

// Add debug utils
class WebRTCProvider {
  static void debug(String message) {
    print('[WebRTC] $message');
  }
}

class GPSDevice extends StatefulWidget {
  const GPSDevice({super.key});

  @override
  _GPSDeviceState createState() => _GPSDeviceState();
}

class _GPSDeviceState extends State<GPSDevice> {
  String _serialNumber = '';
  String _baseUrl = Constants.uri;
  Position? _location;
  Position? _currentPosition;
  String? _errorMessage;
  bool _loading = false;
  bool _updating = false; // For periodic backend updates
  DateTime? _lastUpdateTime;
  Timer? _periodicTimer;
  // Timer? _streamingTimer; // This might be replaced or repurposed by P2P data channel sending
  Timer? _heartbeatTimer;
  LocationPermission? _permissionStatus;

  // WebSocket related variables
  IO.Socket? _socket;
  bool _isSocketConnected = false;

  // WebRTC P2P related variables
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  bool _isPeerConnected = false; // True if P2P data channel is open and active
  // _isStreaming is used by _startPeerStream and _stopLocationStream to manage the P2P streaming state
  bool _isP2PStreaming =
      false; // Renamed for clarity to distinguish from general streaming

  // Logger
  final Logger _logger = Logger('GPSDevice');

  // Configuration for ICE servers
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'url': 'stun:stun.l.google.com:19302'},
      // Add more STUN/TURN servers if needed
    ],
  };

  final Map<String, dynamic> _rtcPeerConnectionConstraints = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  String get _formattedLastUpdateTime =>
      _lastUpdateTime != null
          ? '${_lastUpdateTime!.hour.toString().padLeft(2, '0')}:${_lastUpdateTime!.minute.toString().padLeft(2, '0')}:${_lastUpdateTime!.second.toString().padLeft(2, '0')}'
          : '--:--:--';

  void _showSuccessToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.green,
      textColor: Colors.white,
    );
  }

  void _showErrorToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
  }

  void stopPeriodicUpdates() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    setState(() => _updating = false);
    _showSuccessToast('Stopped periodic backend updates.');
  }

  void startPeriodicUpdates() {
    if (_permissionStatus != LocationPermission.whileInUse &&
        _permissionStatus != LocationPermission.always) {
      _showErrorToast('Location permission not granted for periodic updates.');
      return;
    }

    if (_updating) {
      _showErrorToast('Periodic updates are already running.');
      return;
    }

    if (!_isSocketConnected) {
      _showErrorToast(
        'Signaling server not connected. Cannot start periodic updates.',
      );
      // Optionally, try to connect: _connectWebSocket();
      return;
    }

    setState(() {
      _updating = true;
    });

    _periodicTimer?.cancel(); // Cancel any existing timer first
    _periodicTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateLocation(
        viaP2P: false,
      ); // Periodic updates go to backend via WebSocket/HTTP
    });
    _showSuccessToast('Started periodic backend updates.');
  }

  void _simulateRandomMovement({bool forceWebSocket = false}) async {
    if (!_isSocketConnected || _serialNumber.isEmpty) {
      _showErrorToast('Not connected or S/N missing for simulation.');
      return;
    }
    // Generate data
    final newLat =
        (_currentPosition?.latitude ?? -15.0) +
        (Random().nextDouble() * 0.02 - 0.01);
    final newLng =
        (_currentPosition?.longitude ?? 28.0) +
        (Random().nextDouble() * 0.02 - 0.01);
    final timestamp = DateTime.now().millisecondsSinceEpoch.toDouble();
    final altitude =
        _currentPosition?.altitude ?? 100.0 + Random().nextDouble() * 20;
    final speed = _currentPosition?.speed ?? Random().nextDouble() * 10;
    final accuracy =
        _currentPosition?.accuracy ?? Random().nextDouble() * 5 + 5;

    if (forceWebSocket) {
      _logger.info('Simulating random movement via WebSocket (forced).');
      final locationPayload = {
        'serialNumber': _serialNumber,
        'latitude': newLat,
        'longitude': newLng,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'altitude': altitude,
        'speed': speed,
        'accuracy': accuracy,
        'simulated': true,
      };
      if (_isSocketConnected) {
        // _socket is non-null if _isSocketConnected
        _socket!.emit('location-update', locationPayload);
        _showSuccessToast('Random location simulated via WebSocket.');
        if (mounted) {
          setState(() {
            _lastUpdateTime = DateTime.now();
          });
        }
      } else {
        _showErrorToast('WebSocket not connected for forced simulation.');
      }
      return;
    }

    // Default behavior (P2P first, then WebSocket fallback via _sendLocationData)
    if (_isPeerConnected &&
        _isP2PStreaming &&
        _dataChannel != null &&
        _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      _sendLocationData(
        newLat,
        newLng,
        timestamp,
        altitude: altitude,
        speed: speed,
        accuracy: accuracy,
        extraData: {'simulated': true},
      );
      _showSuccessToast('Random location simulated via P2P.');
    } else if (_isSocketConnected) {
      _logger.info(
        'Simulating random movement via WebSocket (P2P not active/streaming).',
      );
      _sendLocationData(
        newLat,
        newLng,
        timestamp,
        altitude: altitude,
        speed: speed,
        accuracy: accuracy,
        extraData: {'simulated': true},
      );
      _showSuccessToast('Random location simulated via WebSocket.');
    } else {
      _showErrorToast(
        'Cannot simulate: No P2P or WebSocket connection available.',
      );
    }
  }

  void _simulateCircularMovement({bool forceWebSocket = false}) async {
    if (!_isSocketConnected || _serialNumber.isEmpty) {
      _showErrorToast('Not connected or S/N missing for simulation.');
      return;
    }
    _logger.info(
      'Simulating circular movement (forceWebSocket: $forceWebSocket)...',
    );
    // Dummy data for circular movement
    final newLat =
        (_currentPosition?.latitude ?? -15.0) +
        (sin(DateTime.now().second / 60 * 2 * pi) * 0.01);
    final newLng =
        (_currentPosition?.longitude ?? 28.0) +
        (cos(DateTime.now().second / 60 * 2 * pi) * 0.01);
    final timestamp = DateTime.now().millisecondsSinceEpoch.toDouble();
    final altitude = _currentPosition?.altitude ?? 100.0;
    final speed = _currentPosition?.speed ?? 5.0;
    final accuracy = _currentPosition?.accuracy ?? 10.0;

    if (forceWebSocket) {
      _logger.info('Simulating circular movement via WebSocket (forced).');
      final locationPayload = {
        'serialNumber': _serialNumber,
        'latitude': newLat,
        'longitude': newLng,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'altitude': altitude,
        'speed': speed,
        'accuracy': accuracy,
        'simulated': true,
        'pattern': 'circular',
      };
      if (_isSocketConnected) {
        _socket!.emit('location-update', locationPayload);
        _showSuccessToast('Circular location simulated via WebSocket.');
        if (mounted) {
          setState(() {
            _lastUpdateTime = DateTime.now();
          });
        }
      } else {
        _showErrorToast('WebSocket not connected for forced simulation.');
      }
      return;
    }

    if (_isPeerConnected &&
        _isP2PStreaming &&
        _dataChannel != null &&
        _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      _sendLocationData(
        newLat,
        newLng,
        timestamp,
        altitude: altitude,
        speed: speed,
        accuracy: accuracy,
        extraData: {'simulated': true, 'pattern': 'circular'},
      );
      _showSuccessToast('Circular location simulated via P2P.');
    } else if (_isSocketConnected) {
      _logger.info(
        'Simulating circular movement via WebSocket (P2P not active/streaming).',
      );
      _sendLocationData(
        newLat,
        newLng,
        timestamp,
        altitude: altitude,
        speed: speed,
        accuracy: accuracy,
        extraData: {'simulated': true, 'pattern': 'circular'},
      );
      _showSuccessToast('Circular location simulated via WebSocket.');
    } else {
      _showErrorToast(
        'Cannot simulate: No P2P or WebSocket connection available.',
      );
    }
  }

  void _simulateLinearMovement({bool forceWebSocket = false}) async {
    if (!_isSocketConnected || _serialNumber.isEmpty) {
      _showErrorToast('Not connected or S/N missing for simulation.');
      return;
    }
    _logger.info(
      'Simulating linear movement (forceWebSocket: $forceWebSocket)...',
    );
    // Dummy data for linear movement
    final newLat =
        (_currentPosition?.latitude ?? -15.0) +
        (DateTime.now().second * 0.0001); // Simple linear change
    final newLng =
        (_currentPosition?.longitude ?? 28.0) +
        (DateTime.now().second * 0.0001);
    final timestamp = DateTime.now().millisecondsSinceEpoch.toDouble();
    final altitude = _currentPosition?.altitude ?? 100.0;
    final speed = _currentPosition?.speed ?? 5.0;
    final accuracy = _currentPosition?.accuracy ?? 10.0;

    if (forceWebSocket) {
      _logger.info('Simulating linear movement via WebSocket (forced).');
      final locationPayload = {
        'serialNumber': _serialNumber,
        'latitude': newLat,
        'longitude': newLng,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'altitude': altitude,
        'speed': speed,
        'accuracy': accuracy,
        'simulated': true,
        'pattern': 'linear',
      };
      if (_isSocketConnected) {
        _socket!.emit('location-update', locationPayload);
        _showSuccessToast('Linear location simulated via WebSocket.');
        if (mounted) {
          setState(() {
            _lastUpdateTime = DateTime.now();
          });
        }
      } else {
        _showErrorToast('WebSocket not connected for forced simulation.');
      }
      return;
    }

    if (_isPeerConnected &&
        _isP2PStreaming &&
        _dataChannel != null &&
        _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      _sendLocationData(
        newLat,
        newLng,
        timestamp,
        altitude: altitude,
        speed: speed,
        accuracy: accuracy,
        extraData: {'simulated': true, 'pattern': 'linear'},
      );
      _showSuccessToast('Linear location simulated via P2P.');
    } else if (_isSocketConnected) {
      _logger.info(
        'Simulating linear movement via WebSocket (P2P not active/streaming).',
      );
      _sendLocationData(
        newLat,
        newLng,
        timestamp,
        altitude: altitude,
        speed: speed,
        accuracy: accuracy,
        extraData: {'simulated': true, 'pattern': 'linear'},
      );
      _showSuccessToast('Linear location simulated via WebSocket.');
    } else {
      _showErrorToast(
        'Cannot simulate: No P2P or WebSocket connection available.',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _requestPermission();
      // _initializeLocation(); // Location init might depend on permissions
      // Do not auto-connect WebSocket here, let user/logic decide.
      // _connectWebSocket(); // Moved to be called explicitly or on demand
    });
  }

  @override
  void dispose() {
    _stopP2PLocationStream(); // Stop P2P streaming
    _disconnectWebSocket(); // Disconnect signaling
    stopPeriodicUpdates(); // Stop backend updates
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    if (!mounted) return;
    setState(() {
      _errorMessage = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        // Simple dialog for enabling services
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
        serviceEnabled = await Geolocator.isLocationServiceEnabled(); // Recheck
        if (!serviceEnabled) {
          throw Exception('Location services are still disabled');
        }
      }

      _permissionStatus = await Geolocator.checkPermission();

      if (_permissionStatus == LocationPermission.denied) {
        if (!mounted) return;
        // Corrected showDialog call for permission request
        bool? shouldRequestResult = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder:
              (BuildContext context) => AlertDialog(
                title: const Text('Location Permission Required'),
                content: const Text(
                  'This app needs access to your location to function properly. Would you like to grant permission?',
                ),
                actions: [
                  TextButton(
                    child: const Text('Deny'),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  TextButton(
                    child: const Text('Grant'),
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
        );

        bool shouldRequest = shouldRequestResult ?? false; // Handle null case

        if (shouldRequest) {
          _permissionStatus = await Geolocator.requestPermission();
          if (_permissionStatus == LocationPermission.denied) {
            throw Exception('Location permission denied by user');
          }
        } else {
          throw Exception('Permission request declined by user');
        }
      }

      if (_permissionStatus == LocationPermission.deniedForever) {
        if (!mounted) return;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (BuildContext context) => AlertDialog(
                title: const Text('Permission Permanently Denied'),
                content: const Text(
                  'Location permission is permanently denied. Please enable it in your device settings.',
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
        throw Exception(
          'Location permissions are permanently denied. Please enable in settings.',
        );
      }

      if (_permissionStatus == LocationPermission.whileInUse ||
          _permissionStatus == LocationPermission.always) {
        await _initializeLocation(); // Get initial location if permission granted
        _showSuccessToast('Location permission granted.');
      } else {
        // This case should ideally be handled by the checks above, but as a fallback:
        throw Exception('Location permission not granted sufficiently.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
        _showErrorToast('Permission Error: ${e.toString()}');
      }
    }
  }

  Future<void> _initializeLocation() async {
    if (_permissionStatus != LocationPermission.whileInUse &&
        _permissionStatus != LocationPermission.always) {
      _showErrorToast('Location permission not granted.');
      return;
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _location = position;
          _currentPosition = position;
          _lastUpdateTime = DateTime.now();
        });
      }
    } catch (e) {
      throw Exception('Error getting initial location: $e');
    }
  }

  Future<void> _updateLocation({bool viaP2P = true}) async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _location = position; // Update general location too
        _lastUpdateTime = DateTime.now();
        _loading = false;
      });

      if (viaP2P &&
          _isPeerConnected &&
          _isP2PStreaming &&
          _dataChannel != null) {
        _sendLocationData(
          position.latitude,
          position.longitude,
          position.timestamp.millisecondsSinceEpoch
              .toDouble(), // Removed unnecessary null-aware operator
          altitude: position.altitude,
          speed: position.speed,
          accuracy: position.accuracy,
        );
      } else if (!viaP2P) {
        // Send to backend if not P2P or explicitly told so
        _sendLocationToBackend(
          _serialNumber,
          position.latitude,
          position.longitude,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
      _showErrorToast('Error updating location: $e');
      _logger.severe('Error updating location: $e');
    }
  }

  Future<void> _sendLocationToBackend(
    String serialNumber,
    double latitude,
    double longitude,
    // Removed baseUrl as it's a class member _baseUrl
  ) async {
    if (serialNumber.isEmpty) {
      _showErrorToast('Serial number is empty. Cannot send to backend.');
      return;
    }
    // This method now primarily sends via WebSocket for backend updates,
    // P2P data is handled by _sendLocationData via data channel.
    final locationPayload = {
      'serialNumber': serialNumber,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      // Add other relevant fields like accuracy, speed, altitude if available
      // from _currentPosition
      'accuracy': _currentPosition?.accuracy,
      'speed': _currentPosition?.speed,
      'altitude': _currentPosition?.altitude,
    };

    if (_isSocketConnected && _socket != null) {
      _logger.info(
        'Sending location to backend via WebSocket: $locationPayload',
      );
      _socket!.emit('location-update', locationPayload); // Added null check
      _showSuccessToast('Location sent to backend.');
    } else {
      _showErrorToast(
        'WebSocket not connected. Cannot send location to backend.',
      );
      _logger.warning(
        'WebSocket not connected. Failed to send location to backend.',
      );
      // Optionally, implement HTTP fallback here if desired
    }
  }

  // Method to send location data (could be real or simulated)
  // This will be the primary method for sending data over P2P or WebSocket
  void _sendLocationData(
    double lat,
    double lng,
    double timestamp, {
    double? altitude,
    double? speed,
    double? accuracy,
    Map<String, dynamic>? extraData,
  }) {
    final Map<String, dynamic> payload = {
      'serialNumber': _serialNumber,
      'latitude': lat,
      'longitude': lng,
      'timestamp': timestamp, // Device's original timestamp
      'altitude': altitude,
      'speed': speed,
      'accuracy': accuracy,
      ...(extraData ?? {}),
    };

    if (_isP2PStreaming &&
        _isPeerConnected &&
        _dataChannel != null &&
        _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      try {
        _dataChannel!.send(RTCDataChannelMessage(jsonEncode(payload)));
        _logger.info(
          'Location sent via P2P Data Channel: SN $_serialNumber, $lat, $lng',
        );
        // Toast for P2P might be too noisy, consider conditional feedback
        // _showSuccessToast('Location streamed via P2P.');
        if (mounted) {
          setState(() {
            _lastUpdateTime = DateTime.now(); // Reflect P2P send time locally
          });
        }
      } catch (e) {
        _logger.severe('Error sending data via P2P Data Channel: $e');
        _showErrorToast('P2P send error: $e');
        // Fallback to WebSocket if P2P send fails?
        // _sendLocationToBackend(_serialNumber, lat, lng);
      }
    } else if (_isSocketConnected && _socket != null) {
      // Fallback to WebSocket if P2P not active/ready
      _logger.info(
        'P2P not active/ready. Sending location via WebSocket: $payload',
      );
      _socket!.emit('location-update', payload);
      // _showSuccessToast('Location sent via WebSocket (P2P fallback).');
    } else {
      _logger.warning(
        'Cannot send location data: No P2P or WebSocket connection available.',
      );
      _showErrorToast('Not connected. Cannot send location.');
    }
  }

  // WebSocket connection methods
  void _connectWebSocket() {
    if (_serialNumber.isEmpty) {
      _showErrorToast('Serial number is required to connect.');
      _logger.warning('Serial number is empty, WebSocket connection aborted.');
      return;
    }
    if (_isSocketConnected && _socket != null && _socket!.connected) {
      // Added null check for _socket.connected
      _logger.info('WebSocket already connected.');
      // _showSuccessToast('Already connected to signaling server.');
      _registerDevice(); // Re-register if needed, or ensure it's idempotent
      _initializePeerHandling(); // Ensure P2P handlers are set up
      return;
    }
    if (_baseUrl.isEmpty) {
      _showErrorToast('Server URL is not set.');
      _logger.severe('Base URL for WebSocket is empty.');
      return;
    }

    _logger.info('Connecting to WebSocket: $_baseUrl for S/N: $_serialNumber');
    try {
      _socket = IO.io(_baseUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false, // We call connect manually
        'query': {
          'serialNumber': _serialNumber,
          'deviceType': 'flutter-gps-device',
        },
      });

      _socket!.onConnect((_) {
        // Added null check
        _logger.info('WebSocket Connected: ${_socket!.id}'); // Added null check
        if (!mounted) return;
        setState(() {
          _isSocketConnected = true;
        });
        _registerDevice();
        _initializePeerHandling(); // Setup P2P listeners AFTER socket is connected
        _startHeartbeat();
        _showSuccessToast('Connected to signaling server.');
      });

      _socket!.onDisconnect((reason) {
        // Added null check
        _logger.info('WebSocket Disconnected: $reason');
        if (!mounted) return;
        setState(() {
          _isSocketConnected = false;
          _isPeerConnected = false; // P2P depends on signaling
          _isP2PStreaming = false;
        });
        _stopHeartbeat();
        _showErrorToast('Disconnected from signaling server.');
        // Consider cleanup for _peerConnection and _dataChannel here
        _peerConnection
            ?.close(); // Keep null-aware for safety, might be called when _peerConnection is already null
        _peerConnection = null;
        _dataChannel?.close(); // Keep null-aware
        _dataChannel = null;
      });

      _socket!.onConnectError((err) {
        // Added null check
        _logger.severe('WebSocket Connect Error: $err');
        if (!mounted) return;
        setState(() {
          _isSocketConnected = false;
        });
        _showErrorToast('Signaling connection error.');
      });

      _socket!.onError((err) {
        // Added null check
        _logger.severe('WebSocket Error: $err');
        // _showErrorToast('Signaling error.'); // Can be noisy
      });

      _socket!.connect(); // Added null check
    } catch (e) {
      _logger.severe('WebSocket connection attempt failed: $e');
      _showErrorToast('Failed to initiate connection.');
      if (!mounted) return;
      setState(() {
        _isSocketConnected = false;
      });
    }
  }

  void _registerDevice() {
    if (_isSocketConnected && _serialNumber.isNotEmpty && _socket != null) {
      final deviceInfo = {
        'model': 'Flutter GPS Device',
        'platform': Theme.of(context).platform.toString(),
        // Add other device specific info if needed
      };
      _logger.info(
        'Registering device with S/N: $_serialNumber, Info: $deviceInfo',
      );
      _socket!.emit('register-device', {
        // Added null check
        'serialNumber': _serialNumber,
        'deviceInfo': deviceInfo,
      });
    } else {
      _logger.warning(
        'Cannot register device: WebSocket not connected or S/N missing.',
      );
    }
  }

  // P2P Initialization and Signaling
  Future<void> _initializeWebRTC() async {
    _logger.info('Initializing WebRTC Peer Connection...');
    if (_peerConnection != null) {
      _logger.info(
        'Closing existing peer connection before creating a new one.',
      );
      await _peerConnection!.close();
      _peerConnection = null;
      _dataChannel?.close();
      _dataChannel = null;
      if (mounted)
        setState(() {
          _isPeerConnected = false;
        });
    }

    _peerConnection = await createPeerConnection(
      _iceServers,
      _rtcPeerConnectionConstraints,
    );

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate != null && _isSocketConnected && _socket != null) {
        _logger.info('Sending ICE candidate: ${candidate.toMap()}');
        _socket!.emit('device-signal', {
          // Added null check
          'deviceId': _serialNumber,
          'signal': {'type': 'candidate', 'candidate': candidate.toMap()},
        });
      }
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      _logger.info('ICE Connection State: $state');
      if (!mounted) return;
      // Potentially update UI based on state (e.g., connecting, connected, failed)
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        // This indicates ICE negotiation is complete. Data channel 'open' is the true P2P connected state.
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateClosed) {
        setState(() {
          _isPeerConnected = false;
          // _isP2PStreaming = false; // Stream might still be "on" conceptually, but not working
        });
        _showErrorToast("P2P Connection Failed/Lost");
      }
    };

    _peerConnection!.onDataChannel = (RTCDataChannel channel) {
      _logger.info('Data Channel received: ${channel.label}');
      _dataChannel = channel;
      _setupDataChannelListeners();
    };
  }

  Future<void> _createDataChannel() async {
    if (_peerConnection == null) {
      _logger.warning(
        'PeerConnection not initialized. Cannot create data channel.',
      );
      return;
    }
    _logger.info('Creating Data Channel...');
    RTCDataChannelInit dataChannelInit = RTCDataChannelInit();
    // dataChannelInit.ordered = true; // Ensure ordered delivery if needed
    _dataChannel = await _peerConnection!.createDataChannel(
      'locationDataChannel',
      dataChannelInit,
    );
    _setupDataChannelListeners();
  }

  void _setupDataChannelListeners() {
    if (_dataChannel == null) return;

    _dataChannel!.onDataChannelState = (RTCDataChannelState state) {
      _logger.info('Data Channel State: $state');
      if (!mounted) return;
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        setState(() {
          _isPeerConnected = true;
        });
        _showSuccessToast('P2P Data Channel Open!');
        // If _isP2PStreaming is true, we can now send data.
        // Example: _dataChannel!.send(RTCDataChannelMessage('Hello from Flutter P2P!'));
        // Notify web client that this device's P2P is ready
        if (_socket != null && _isSocketConnected) {
          _socket!.emit('p2p-device-channel-ready', {
            'deviceId': _serialNumber,
          });
        }
      } else {
        setState(() {
          _isPeerConnected = false;
        });
        if (state == RTCDataChannelState.RTCDataChannelClosed) {
          _showErrorToast('P2P Data Channel Closed.');
        }
      }
    };

    _dataChannel!.onMessage = (RTCDataChannelMessage message) {
      _logger.info('P2P Data received: ${message.text}');
      // Handle incoming P2P messages if web client sends any (e.g., acknowledgments, commands)
      // For now, Flutter device is primarily a sender.
    };
  }

  Future<void> _initiateP2PConnection() async {
    if (!_isSocketConnected || _socket == null) {
      // _socket == null check is still relevant here before it's used.
      _showErrorToast('Signaling server not connected. Cannot initiate P2P.');
      _logger.warning('Cannot initiate P2P: Signaling server not connected.');
      return;
    }
    if (_peerConnection != null && _isPeerConnected) {
      _logger.info("P2P connection already active or in progress.");
      // _showSuccessToast("P2P already active.");
      return;
    }

    _logger.info('Initiating P2P connection with S/N: $_serialNumber');
    await _initializeWebRTC(); // Initialize PeerConnection
    await _createDataChannel(); // Create DataChannel as initiator

    try {
      RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      _logger.info('Offer created and set as local description. Sending to web client...');
      _socket!.emit('device-signal', {
        'deviceId': _serialNumber,
        'signal': {'type': 'offer', 'sdp': offer.sdp}
      });
      _showSuccessToast('P2P connection offer sent.');
    } catch (e) {
      _logger.severe('Error creating or sending P2P offer: $e');
      _showErrorToast('P2P Offer Error: $e');
      await _cleanupP2PResources(); // Await cleanup
    }
  }

  void _initializePeerHandling() {
    if (!_isSocketConnected || _socket == null) {
      _logger.warning(
        'Cannot initialize P2P event handlers: WebSocket not connected or socket is null.',
      );
      return;
    }
    _logger.info('Initializing P2P event handlers on WebSocket...');

    // Clear existing P2P listeners to prevent multiple registrations
    _socket!.off('incoming-p2p-signal-from-web'); // Added null check
    _socket!.off('p2p-web-client-ready'); // Added null check
    _socket!.off('p2p-web-client-disconnected'); // Added null check
    _socket!.off('p2p-target-not-found'); // Added null check

    // Handle signals from web client (answer, ICE candidates)
    _socket!.on('incoming-p2p-signal-from-web', (data) async {
      // Added null check
      _logger.info('Received signal from web client: $data');
      if (_peerConnection == null) {
        _logger.warning('PeerConnection not initialized. Ignoring signal.');
        // This might happen if web client sends signal before Flutter initiates.
        // Consider if Flutter should also be able to receive an offer. For now, Flutter initiates.
        return;
      }

      final signal = data['signal'];
      final String type = signal['type'];

      try {
        if (type == 'answer') {
          final sdp = signal['sdp'];
          RTCSessionDescription answer = RTCSessionDescription(sdp, type);
          _logger.info('Setting remote description (answer) from web client.');
          await _peerConnection!.setRemoteDescription(answer);
        } else if (type == 'candidate') {
          final candidateMap = signal['candidate'];
          RTCIceCandidate candidate = RTCIceCandidate(
            candidateMap['candidate'],
            candidateMap['sdpMid'],
            candidateMap['sdpMLineIndex'],
          );
          _logger.info('Adding ICE candidate from web client.');
          await _peerConnection!.addCandidate(candidate);
        } else {
          _logger.warning('Unknown signal type from web client: $type');
        }
      } catch (e) {
        _logger.severe('Error processing signal from web client: $e');
        _showErrorToast('P2P Signal Error: $e');
      }
    });

    // Web client indicates its P2P data channel is ready
    _socket!.on('p2p-web-client-ready', (data) {
      // Added null check
      final fromClientId = data['fromClientId'];
      _logger.info('Web client ($fromClientId) P2P data channel is ready.');
      // This device's data channel state (_isPeerConnected) is managed by its own onDataChannelState.
      // This event is more for information or if specific action needed upon web client readiness.
    });

    // Web client explicitly disconnected P2P
    _socket!.on('p2p-web-client-disconnected', (data) async { // Handler is already async
      final fromClientId = data['fromClientId'];
      final reason = data['reason'];
      _logger.info('Web client ($fromClientId) disconnected P2P. Reason: $reason');
      _showErrorToast('Peer disconnected: $reason');
      await _cleanupP2PResources(); // Await cleanup
       if(mounted) setState(() {
          _isPeerConnected = false;
          _isP2PStreaming = false; // Stop streaming if peer disconnects
       });
    });
    
    _socket!.on('p2p-target-not-found', (data) { 
      // Added null check
      final targetDeviceId = data['targetDeviceId'];
      if (targetDeviceId == _serialNumber) {
        // Should not happen if this device is the target
        _logger.warning(
          'Received p2p-target-not-found for this device. This is unexpected.',
        );
      } else {
        // This device was trying to signal a web client that is no longer found by the server
        _logger.warning(
          'Server reported target web client for P2P not found for device $targetDeviceId.',
        );
        // If this device was trying to connect to a specific web client (not current model), handle here.
      }
    });
  }

  void _disconnectWebSocket() {
    _logger.info('Disconnecting WebSocket...');
    _stopHeartbeat();
    _socket
        ?.disconnect(); // Keep null-aware, _socket might be null if never connected
    // _socket?.dispose(); // Dispose if you are completely done with the socket instance
    // _socket = null; // Let onDisconnect handle state, but nullify if disposed
    if (!mounted) return;
    // State updates are handled in onDisconnect
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (_isSocketConnected && _socket != null) {
        _socket!.emit('ping', {
          'deviceId': _serialNumber,
          'time': DateTime.now().toIso8601String(),
        }); // Added null check
        _logger.finer('Sent ping to server.');
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // Renamed from _startLocationStream to be P2P specific
  void _startP2PLocationStream() async {
    if (_serialNumber.isEmpty) {
      _showErrorToast('Serial number is required to start P2P stream.');
      return;
    }
    if (!_isSocketConnected) {
      _showErrorToast('Signaling server not connected. Please connect first.');
      // Attempt to connect to WebSocket if not already connected
      _connectWebSocket();
      // Wait a bit for connection, or handle async connection better
      // For now, user might need to press again after connection establishes.
      return;
    }

    if (_isP2PStreaming && _isPeerConnected) {
      _showSuccessToast('P2P Location stream already active.');
      return;
    }

    setState(() {
      _isP2PStreaming = true; // Indicate intent to stream
    });

    await _initiateP2PConnection(); // This will set up peer connection and data channel

    // Location sending will happen via _updateLocation or simulated movements
    // if _isP2PStreaming and _isPeerConnected are true.
    _showSuccessToast('P2P Location stream initiated.');
  }

  // Renamed from _stopLocationStream
  void _stopP2PLocationStream() async { // Made async
    _logger.info('Stopping P2P Location Stream...');
    if (!_isP2PStreaming && !_isPeerConnected) {
        // _showSuccessToast("P2P stream already stopped.");
        // return;
    }

    if (mounted) {
      setState(() {
        _isP2PStreaming = false;
      });
    }

    // Notify web client about P2P disconnect initiated by this device
    if (_socket != null && _isSocketConnected && _serialNumber.isNotEmpty) {
        _socket!.emit('p2p-device-disconnect', {
            'deviceId': _serialNumber,
            'reason': 'Device stopped streaming'
        });
    }
    
    await _cleanupP2PResources(); // Await cleanup
    _showSuccessToast('P2P Location stream stopped.');
  }

  Future<void> _cleanupP2PResources() async { // Made async
    _logger.info("Cleaning up P2P resources...");
    _dataChannel?.close(); // RTCDataChannel.close() is synchronous
    _dataChannel = null;
    await _peerConnection?.close(); // RTCPeerConnection.close() is asynchronous
    _peerConnection = null;
    if (mounted) {
      setState(() {
        _isPeerConnected = false;
        // _isP2PStreaming should be set by the calling function (_stopP2PLocationStream or error handlers)
      });
    }
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Flexible(
            // Use Flexible for long values
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Example of how to use the new P2P streaming functions in UI:
    // ElevatedButton(onPressed: _startP2PLocationStream, child: Text('Start P2P Stream')),
    // ElevatedButton(onPressed: _stopP2PLocationStream, child: Text('Stop P2P Stream')),
    // Text(_isPeerConnected ? "P2P Connected" : "P2P Disconnected"),
    // Text(_isP2PStreaming ? "P2P Streaming ON" : "P2P Streaming OFF"),

    // Make sure to also add a way to input Serial Number and connect to WebSocket:
    // TextField(onChanged: (val) => _serialNumber = val, decoration: InputDecoration(labelText: 'Serial Number')),
    // ElevatedButton(onPressed: _connectWebSocket, child: Text('Connect Signaling')),

    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS Device Simulator'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Connection Status Card
              Card(
                elevation: 2,
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
                              _isSocketConnected
                                  ? '🟢 WS Live'
                                  : '🔴 WS Offline',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isPeerConnected
                            ? 'P2P Connected'
                            : (_isSocketConnected
                                ? 'P2P Ready'
                                : 'P2P Offline'),
                        style: TextStyle(
                          color:
                              _isPeerConnected
                                  ? Colors.blueAccent
                                  : (_isSocketConnected
                                      ? Colors.orangeAccent
                                      : Colors.grey),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isSocketConnected
                            ? (_socket!.id != null
                                ? 'Socket ID: ${_socket!.id}'
                                : 'Real-time connection is active')
                            : 'No connection to server',
                        style: TextStyle(
                          color:
                              _isSocketConnected ? Colors.green : Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Configuration Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Configuration',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'Serial Number',
                          hintText: 'Enter device serial (e.g., GPS-123)',
                          border: const OutlineInputBorder(),
                          errorText:
                              _serialNumber.isEmpty &&
                                      _errorMessage != null &&
                                      _errorMessage!.contains("Serial")
                                  ? _errorMessage
                                  : null,
                        ),
                        onChanged:
                            (value) =>
                                setState(() => _serialNumber = value.trim()),
                        onSubmitted: (_) {
                          if (_serialNumber.isNotEmpty && _baseUrl.isNotEmpty)
                            _connectWebSocket();
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'Server URL',
                          hintText: 'e.g., http://localhost:3001',
                          border: const OutlineInputBorder(),
                        ),
                        controller: TextEditingController(text: _baseUrl)
                          ..selection = TextSelection.fromPosition(
                            TextPosition(offset: _baseUrl.length),
                          ),
                        onChanged:
                            (value) => setState(() => _baseUrl = value.trim()),
                        onSubmitted: (_) {
                          if (_serialNumber.isNotEmpty && _baseUrl.isNotEmpty)
                            _connectWebSocket();
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: Icon(
                                _isSocketConnected
                                    ? Icons.cloud_off
                                    : Icons.cloud_queue,
                              ),
                              label: Text(
                                _isSocketConnected
                                    ? 'Disconnect'
                                    : 'Connect WS',
                              ),
                              onPressed:
                                  _serialNumber.isNotEmpty &&
                                          _baseUrl.isNotEmpty
                                      ? (_isSocketConnected
                                          ? _disconnectWebSocket
                                          : _connectWebSocket)
                                      : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _isSocketConnected
                                        ? Colors.orange
                                        : Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // P2P Controls Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'P2P Streaming',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: Icon(
                          _isP2PStreaming // Condition based on intent to stream
                              ? Icons.stop_circle_outlined
                              : Icons.play_circle_outline,
                        ),
                        label: Text(
                          _isP2PStreaming // Label based on intent to stream
                              ? 'Stop P2P Stream'
                              : 'Start P2P Stream',
                        ),
                        onPressed:
                            _isSocketConnected && _serialNumber.isNotEmpty
                                ? (_isP2PStreaming
                                    ? _stopP2PLocationStream // If streaming, stop it
                                    : _startP2PLocationStream) // Else (not streaming), start it
                                : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isP2PStreaming // Style based on intent to stream
                                  ? Colors.redAccent
                                  : Colors.teal,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 40),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Location Info Card
              if (_location != null)
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Location',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDataRow(
                          'Latitude',
                          _location!.latitude.toStringAsFixed(6),
                        ),
                        _buildDataRow(
                          'Longitude',
                          _location!.longitude.toStringAsFixed(6),
                        ),
                        _buildDataRow(
                          'Altitude',
                          '${_location!.altitude.toStringAsFixed(1)} m',
                        ),
                        _buildDataRow(
                          'Speed',
                          '${(_location!.speed * 3.6).toStringAsFixed(1)} km/h',
                        ),
                        _buildDataRow(
                          'Accuracy',
                          '${_location!.accuracy.toStringAsFixed(1)} m',
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Last Update: $_formattedLastUpdateTime',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Periodic Backend Updates Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Periodic Backend Updates',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: Icon(
                          _updating
                              ? Icons.stop_circle_outlined
                              : Icons.play_circle_outline,
                        ),
                        label: Text(
                          _updating
                              ? 'Stop Periodic Updates'
                              : 'Start Periodic Updates',
                        ),
                        onPressed:
                            _isSocketConnected && _serialNumber.isNotEmpty
                                ? (_updating
                                    ? stopPeriodicUpdates
                                    : startPeriodicUpdates)
                                : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _updating ? Colors.red : Colors.indigo,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 40),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // WebSocket Simulation Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'WebSocket Location Simulation',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Manual Simulation (sends single update via WebSocket):',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  _isSocketConnected && _serialNumber.isNotEmpty
                                      ? () => _simulateRandomMovement(
                                        forceWebSocket: true,
                                      )
                                      : null,
                              child: const Text('Random'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  _isSocketConnected && _serialNumber.isNotEmpty
                                      ? () => _simulateCircularMovement(
                                        forceWebSocket: true,
                                      )
                                      : null,
                              child: const Text('Circular'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed:
                            _isSocketConnected && _serialNumber.isNotEmpty
                                ? () => _simulateLinearMovement(
                                  forceWebSocket: true,
                                )
                                : null,
                        child: const Text('Linear Movement'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 36),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Error Message Display
              if (_errorMessage != null && _errorMessage!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Made async
          await _requestPermission(); // Refresh permissions
          if (mounted &&
              (_permissionStatus == LocationPermission.always ||
                  _permissionStatus == LocationPermission.whileInUse)) {
            await _initializeLocation(); // Then get initial location
          }
        },
        tooltip: 'Refresh Location/Permissions',
        child: const Icon(Icons.my_location),
      ),
    );
  }
}

// Ensure you have these helper functions or integrate them.
// For example, if Constants.uri is not defined, define it.
// class Constants {
//   static String uri = "http://your_server_address:your_port";
// }
