class GpsAsset {
  final String id;
  final String serialNumber;
  final String name;
  final String model;
  final String deviceName;
  final String imageUrl;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final LastKnownLocation? lastKnownLocation;
  bool isActive; // Power state
  bool engineOn; // Engine state
  bool alarmActive; // Alarm state
  bool lostModeActive; // Lost mode state
  bool isOnline; // Device online status
  String? batteryLevel; // Battery level
  double? speed; // Current speed
  double? altitude; // Altitude
  double? temperature; // Temperature
  double? humidity; // Humidity
  DateTime? lastUpdated; // Last status update time
  String? signalStrength; // Signal strength (e.g., "good", "poor")
  String? errorState; // Any error condition

  GpsAsset({
    required this.id,
    required this.serialNumber,
    required this.name,
    this.model = '',
    this.deviceName = '',
    this.imageUrl = '',
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    this.lastKnownLocation,
    this.isActive = false,
    this.engineOn = false,
    this.alarmActive = false,
    this.lostModeActive = false,
    this.isOnline = false,
    this.batteryLevel,
    this.speed,
    this.altitude,
    this.temperature,
    this.humidity,
    this.lastUpdated,
    this.signalStrength,
    this.errorState,
  });

  factory GpsAsset.fromJson(Map<String, dynamic> json) {
    print('Processing GPS Asset JSON: $json'); // Debug log

    // Create location if available
    LastKnownLocation? location;
    if (json['lastKnownLocation'] != null) {
      try {
        location = LastKnownLocation.fromJson(json['lastKnownLocation']);
        print('Parsed location: ${location.coordinates}'); // Debug log
      } catch (e) {
        print('Error parsing location: $e'); // Debug log
      }
    }

    final DateTime updatedAt = DateTime.parse(
      json['updatedAt'] ?? DateTime.now().toIso8601String(),
    );
    final bool isActive = DateTime.now().difference(updatedAt).inMinutes < 5;

    return GpsAsset(
      id: json['_id'] ?? '',
      serialNumber: json['serialNumber'] ?? '',
      name: json['name'] ?? '',
      model: json['model'] ?? '',
      deviceName: json['deviceName'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      userId: json['userId'] ?? '',
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: updatedAt,
      lastKnownLocation: location,
      isActive: isActive,
      engineOn: json['engineOn'] ?? false,
      speed: json['speed']?.toDouble(),
      altitude: json['altitude']?.toDouble(),
      temperature: json['temperature']?.toDouble(),
      humidity: json['humidity']?.toDouble(),
      lastUpdated:
          json['lastUpdated'] != null
              ? DateTime.parse(json['lastUpdated'])
              : updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'serialNumber': serialNumber,
      'name': name,
      'model': model,
      'deviceName': deviceName,
      'imageUrl': imageUrl,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastKnownLocation': lastKnownLocation?.toJson(),
      'isActive': isActive,
      'engineOn': engineOn,
      'speed': speed,
      'altitude': altitude,
      'temperature': temperature,
      'humidity': humidity,
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }
}

class LastKnownLocation {
  final String type;
  final List<double> coordinates;

  LastKnownLocation({required this.type, required this.coordinates});

  factory LastKnownLocation.fromJson(Map<String, dynamic> json) {
    print('Parsing location JSON: $json'); // Debug log

    List<double> coords;
    if (json['coordinates'] is List) {
      coords =
          (json['coordinates'] as List)
              .map((e) => double.parse(e.toString()))
              .toList();
    } else {
      throw FormatException(
        'Invalid coordinates format: ${json['coordinates']}',
      );
    }

    print('Parsed coordinates: $coords'); // Debug log

    return LastKnownLocation(
      type: json['type'] ?? 'Point',
      coordinates: coords,
    );
  }

  Map<String, dynamic> toJson() {
    return {'type': type, 'coordinates': coordinates};
  }
}
