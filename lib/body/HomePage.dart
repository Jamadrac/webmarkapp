import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:webmark/AUTH/providers/auth_provider.dart';
import 'package:webmark/constants.dart';
import 'package:webmark/AUTH/models/gps_asset_model.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<GpsAsset> userModules = [];
  bool isLoading = false;
  String? error;
  Position? currentPosition;
  final MapController mapController = MapController();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _getCurrentLocation();
    await _fetchUserModules();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        currentPosition = position;
      });

      if (mounted && currentPosition != null) {
        mapController.move(
          LatLng(currentPosition!.latitude, currentPosition!.longitude),
          13.0,
        );
      }
    } catch (e) {
      setState(() {
        error = 'Error getting location: $e';
      });
    }
  }

  Future<void> _fetchUserModules() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userId = auth.user?.id;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await http.get(
        Uri.parse('${Constants.uri}/api/myDevices/user/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.containsKey('gpsModules')) {
          final List<dynamic> modulesList = data['gpsModules'];
          setState(() {
            userModules =
                modulesList
                    .map(
                      (json) => GpsAsset.fromJson(json as Map<String, dynamic>),
                    )
                    .toList();
          });
        } else {
          throw Exception('No GPS modules found in response');
        }
      } else {
        throw Exception('Failed to fetch modules: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _initializeData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Map Container
              Container(
                height: MediaQuery.of(context).size.height * 0.5,
                width: double.infinity,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: mapController,
                        options: MapOptions(
                          center:
                              currentPosition != null
                                  ? LatLng(
                                    currentPosition!.latitude,
                                    currentPosition!.longitude,
                                  )
                                  : const LatLng(0, 0),
                          zoom: 13.0,
                          interactiveFlags: InteractiveFlag.all,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.webmark',
                          ),
                          MarkerLayer(
                            markers: [
                              if (currentPosition != null)
                                Marker(
                                  point: LatLng(
                                    currentPosition!.latitude,
                                    currentPosition!.longitude,
                                  ),
                                  child: const Icon(
                                    Icons.my_location,
                                    color: Colors.green,
                                    size: 30,
                                  ),
                                ),
                              ...userModules
                                  .where((module) {
                                    if (module.lastKnownLocation != null) {
                                      print(
                                        'Module ${module.name} has location: ${module.lastKnownLocation?.coordinates}',
                                      );
                                      return true;
                                    }
                                    print(
                                      'Module ${module.name} has no location',
                                    );
                                    return false;
                                  })
                                  .map((module) {
                                    // MongoDB stores coordinates as [longitude, latitude]
                                    final lat =
                                        module
                                            .lastKnownLocation!
                                            .coordinates[1]; // Second value is latitude
                                    final lng =
                                        module
                                            .lastKnownLocation!
                                            .coordinates[0]; // First value is longitude
                                    print(
                                      'Creating marker for ${module.name} at ($lat, $lng)',
                                    );

                                    return Marker(
                                      point: LatLng(lat, lng),
                                      child: Tooltip(
                                        message:
                                            '${module.name}\n${module.serialNumber}',
                                        child: Icon(
                                          Icons.location_on,
                                          color:
                                              module.isActive
                                                  ? Colors.red
                                                  : Colors.grey,
                                          size: 30,
                                        ),
                                      ),
                                    );
                                  }),
                            ],
                          ),
                        ],
                      ),
                      // Map Controls Overlay
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: Column(
                          children: [
                            FloatingActionButton(
                              mini: true,
                              heroTag: 'zoomIn',
                              onPressed: () {
                                final currentZoom = mapController.zoom;
                                mapController.move(
                                  mapController.center,
                                  currentZoom + 1,
                                );
                              },
                              child: const Icon(Icons.add),
                            ),
                            const SizedBox(height: 8),
                            FloatingActionButton(
                              mini: true,
                              heroTag: 'zoomOut',
                              onPressed: () {
                                final currentZoom = mapController.zoom;
                                mapController.move(
                                  mapController.center,
                                  currentZoom - 1,
                                );
                              },
                              child: const Icon(Icons.remove),
                            ),
                            const SizedBox(height: 8),
                            FloatingActionButton(
                              mini: true,
                              heroTag: 'recenter',
                              onPressed: () {
                                if (currentPosition != null) {
                                  mapController.move(
                                    LatLng(
                                      currentPosition!.latitude,
                                      currentPosition!.longitude,
                                    ),
                                    13.0,
                                  );
                                }
                              },
                              child: const Icon(Icons.my_location),
                            ),
                          ],
                        ),
                      ),
                      // Loading Indicator
                      if (isLoading)
                        Container(
                          color: Colors.black26,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Error Display
              if (error != null)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              // Stats and Module List
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GPS Modules Overview',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatCard(
                          'Total',
                          userModules.length.toString(),
                          Icons.devices,
                          Colors.blue,
                        ),
                        _buildStatCard(
                          'Active',
                          userModules
                              .where((m) => m.isActive)
                              .length
                              .toString(),
                          Icons.check_circle,
                          Colors.green,
                        ),
                        _buildStatCard(
                          'Offline',
                          userModules
                              .where((m) => !m.isActive)
                              .length
                              .toString(),
                          Icons.error_outline,
                          Colors.red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: userModules.length,
                      itemBuilder: (context, index) {
                        final module = userModules[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  module.isActive ? Colors.green : Colors.grey,
                              child: const Icon(
                                Icons.gps_fixed,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(module.name),
                            subtitle: Text(module.serialNumber),
                            trailing: IconButton(
                              icon: const Icon(Icons.map),
                              onPressed: () {
                                if (module.lastKnownLocation != null) {
                                  mapController.move(
                                    LatLng(
                                      module.lastKnownLocation!.coordinates[0],
                                      module.lastKnownLocation!.coordinates[1],
                                    ),
                                    15.0,
                                  );
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _initializeData,
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
