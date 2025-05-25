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
  });
  factory GpsAsset.fromJson(Map<String, dynamic> json) {
    return GpsAsset(
      id: json['_id'] ?? '',
      serialNumber: json['serialNumber'] ?? '',
      name: json['name'] ?? '',
      model: json['model'] ?? '',
      deviceName: json['deviceName'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      userId: json['user'] ?? json['userId'] ?? '', // Handle both 'user' and 'userId' fields
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
      lastKnownLocation: json['lastKnownLocation'] != null 
          ? LastKnownLocation.fromJson(json['lastKnownLocation'])
          : null,
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
    };
  }
}

class LastKnownLocation {
  final String type;
  final List<double> coordinates;

  LastKnownLocation({
    required this.type,
    required this.coordinates,
  });
  factory LastKnownLocation.fromJson(Map<String, dynamic> json) {
    return LastKnownLocation(
      type: json['type'] ?? 'Point',
      coordinates: (json['coordinates'] as List?)
          ?.map((e) => (e as num).toDouble())
          .toList() ?? [0.0, 0.0],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'coordinates': coordinates,
    };
  }
}
