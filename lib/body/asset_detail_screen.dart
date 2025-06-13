import 'package:flutter/material.dart';
import 'package:webmark/AUTH/models/gps_asset_model.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:webmark/services/gps_asset_service.dart';
import 'package:provider/provider.dart';
import 'package:webmark/AUTH/providers/auth_provider.dart';

class AssetDetailScreen extends StatefulWidget {
  final GpsAsset asset;

  const AssetDetailScreen({super.key, required this.asset});

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  final MapController _mapController = MapController();
  late final GpsAssetService _assetService;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.user?.id;

    if (userId == null) {
      // Handle the case where user is not authenticated
      Future.microtask(() {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not authenticated'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pop();
      });

      return;
    }

    _assetService = GpsAssetService(userId: userId);
    _startStatusUpdates();
  }

  // Periodic status updates
  void _startStatusUpdates() {
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _updateAssetStatus();
        _startStatusUpdates();
      }
    });
  }

  // Update asset status
  Future<void> _updateAssetStatus() async {
    try {
      final status = await _assetService.getAssetStatus(widget.asset.id);
      if (mounted) {
        setState(() {
          widget.asset.engineOn = status['engineOn'] ?? widget.asset.engineOn;
          widget.asset.isActive = status['isActive'] ?? widget.asset.isActive;
          widget.asset.speed =
              status['speed']?.toDouble() ?? widget.asset.speed;
          widget.asset.altitude =
              status['altitude']?.toDouble() ?? widget.asset.altitude;
          widget.asset.temperature =
              status['temperature']?.toDouble() ?? widget.asset.temperature;
          widget.asset.humidity =
              status['humidity']?.toDouble() ?? widget.asset.humidity;
          widget.asset.lastUpdated = DateTime.parse(
            status['lastUpdated'] ?? DateTime.now().toIso8601String(),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
      }
    }
  }

  // Control engine state
  Future<void> _controlEngine(bool state) async {
    setState(() => _isLoading = true);
    try {
      await _assetService.controlEngine(widget.asset.id, state);
      if (mounted) {
        setState(() {
          widget.asset.engineOn = state;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to control engine: $e')));
      }
    }
  }

  // Control power state
  Future<void> _controlPower(bool state) async {
    setState(() => _isLoading = true);
    try {
      await _assetService.controlPower(widget.asset.id, state);
      if (mounted) {
        setState(() {
          widget.asset.isActive = state;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to control power: $e')));
      }
    }
  }

  // Trigger alarm
  Future<void> _triggerAlarm() async {
    setState(() => _isLoading = true);
    try {
      await _assetService.triggerAlarm(widget.asset.id);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alarm triggered successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to trigger alarm: $e')));
      }
    }
  }

  // Activate lost mode
  Future<void> _activateLostMode() async {
    setState(() => _isLoading = true);
    try {
      await _assetService.activateLostMode(widget.asset.id);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Lost mode activated')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to activate lost mode: $e')),
        );
      }
    }
  }

  // Restore defaults
  Future<void> _restoreDefaults() async {
    setState(() => _isLoading = true);
    try {
      await _assetService.restoreDefaults(widget.asset.id);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device restored to defaults')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore defaults: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasLocation = widget.asset.lastKnownLocation != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.asset.name.isNotEmpty ? widget.asset.name : 'Asset Details',
        ),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Asset Image and Basic Info Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // Asset Image
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.primary.withOpacity(0.5),
                          width: 3,
                        ),
                      ),
                      child: ClipOval(
                        child:
                            widget.asset.imageUrl.isNotEmpty
                                ? Image.network(
                                  widget.asset.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildPlaceholderImage();
                                  },
                                )
                                : _buildPlaceholderImage(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Asset Name
                    Text(
                      widget.asset.name.isNotEmpty
                          ? widget.asset.name
                          : 'Unnamed Asset',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 8),

                    // Status Indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            widget.asset.isActive
                                ? colorScheme.primary.withOpacity(0.1)
                                : colorScheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color:
                                  widget.asset.isActive
                                      ? colorScheme.primary
                                      : colorScheme.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.asset.isActive ? 'Active' : 'Offline',
                            style: TextStyle(
                              color:
                                  widget.asset.isActive
                                      ? colorScheme.primary
                                      : colorScheme.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Device Information Card
            _buildInfoCard('Device Information', [
              _buildInfoRow('Serial Number', widget.asset.serialNumber),
              _buildInfoRow(
                'Model',
                widget.asset.model.isNotEmpty ? widget.asset.model : 'Unknown',
              ),
              _buildInfoRow(
                'Device Name',
                widget.asset.deviceName.isNotEmpty
                    ? widget.asset.deviceName
                    : 'Unknown',
              ),
              _buildInfoRow('Asset ID', widget.asset.id),
            ]),

            const SizedBox(height: 16),

            // Map Card
            if (hasLocation) ...[
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Location',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          center: LatLng(
                            widget.asset.lastKnownLocation!.coordinates[1],
                            widget.asset.lastKnownLocation!.coordinates[0],
                          ),
                          zoom: 15.0,
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
                              Marker(
                                point: LatLng(
                                  widget
                                      .asset
                                      .lastKnownLocation!
                                      .coordinates[1],
                                  widget
                                      .asset
                                      .lastKnownLocation!
                                      .coordinates[0],
                                ),
                                child: Icon(
                                  Icons.location_on,
                                  color:
                                      widget.asset.isActive
                                          ? colorScheme.primary
                                          : colorScheme.error,
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(
                            'Latitude',
                            widget.asset.lastKnownLocation!.coordinates[1]
                                .toStringAsFixed(6),
                          ),
                          _buildInfoRow(
                            'Longitude',
                            widget.asset.lastKnownLocation!.coordinates[0]
                                .toStringAsFixed(6),
                          ),
                          _buildInfoRow(
                            'Location Type',
                            widget.asset.lastKnownLocation!.type,
                          ),
                          _buildInfoRow(
                            'Last Updated',
                            _formatDateTime(widget.asset.updatedAt),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.location_off,
                        size: 48,
                        color: colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Location Data Available',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This device has not reported its location yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodySmall?.color,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Control Features Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Control Features',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Engine Control
                    SwitchListTile(
                      title: const Text('Engine Control'),
                      subtitle: Text(
                        widget.asset.engineOn
                            ? 'Engine is ON'
                            : 'Engine is OFF',
                        style: TextStyle(
                          color:
                              widget.asset.engineOn ? Colors.green : Colors.red,
                        ),
                      ),
                      value: widget.asset.engineOn,
                      onChanged:
                          _isLoading
                              ? null
                              : (bool value) => _controlEngine(value),
                    ),
                    // Power Control
                    SwitchListTile(
                      title: const Text('Power Control'),
                      subtitle: Text(
                        widget.asset.isActive ? 'Power is ON' : 'Power is OFF',
                      ),
                      value: widget.asset.isActive,
                      onChanged:
                          _isLoading
                              ? null
                              : (bool value) => _controlPower(value),
                    ),
                    // Beep Alarm
                    ListTile(
                      title: const Text('Beep Alarm'),
                      trailing: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _triggerAlarm,
                        icon: const Icon(Icons.volume_up),
                        label: const Text('Sound Alarm'),
                      ),
                    ),
                    // Lost Mode
                    ListTile(
                      title: const Text('Lost Mode'),
                      trailing: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _activateLostMode,
                        icon: const Icon(Icons.gps_fixed),
                        label: const Text('Activate'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    // Restore Button
                    ListTile(
                      title: const Text('Restore Defaults'),
                      trailing: ElevatedButton.icon(
                        onPressed:
                            _isLoading
                                ? null
                                : () {
                                  showDialog(
                                    context: context,
                                    builder:
                                        (context) => AlertDialog(
                                          title: const Text('Restore Defaults'),
                                          content: const Text(
                                            'Are you sure you want to reset this device to factory defaults?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed:
                                                  () => Navigator.pop(context),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(context);
                                                _restoreDefaults();
                                              },
                                              child: const Text('Restore'),
                                            ),
                                          ],
                                        ),
                                  );
                                },
                        icon: const Icon(Icons.restore),
                        label: const Text('Reset'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Status Display Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status Display',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStatusRow(
                      'Battery',
                      '78%',
                      icon: Icons.battery_charging_full,
                      iconColor: Colors.green,
                    ),
                    if (hasLocation) ...[
                      _buildStatusRow(
                        'Last Seen Location',
                        '${widget.asset.lastKnownLocation!.coordinates[1]}, ${widget.asset.lastKnownLocation!.coordinates[0]}',
                        icon: Icons.location_on,
                      ),
                    ],
                    _buildStatusRow(
                      'Current Speed',
                      '${widget.asset.speed ?? 0} km/h',
                      icon: Icons.speed,
                    ),
                    _buildStatusRow(
                      'Altitude',
                      '${widget.asset.altitude ?? 0} m',
                      icon: Icons.height,
                    ),
                    _buildStatusRow(
                      'Temperature',
                      '${widget.asset.temperature ?? 0}°C',
                      icon: Icons.thermostat,
                    ),
                    _buildStatusRow(
                      'Humidity',
                      '${widget.asset.humidity ?? 0}%',
                      icon: Icons.water_drop,
                    ),
                    _buildStatusRow(
                      'Last Update',
                      widget.asset.lastUpdated?.toLocal().toString() ??
                          'Unknown',
                      icon: Icons.update,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey[200],
      child: Icon(Icons.device_hub, size: 60, color: Colors.grey[400]),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _refreshAssetData(BuildContext context) {
    // TODO: Implement refresh functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Refreshing device data...'),
        backgroundColor: Theme.of(context).colorScheme.secondary,
      ),
    );
  }

  Widget _buildStatusRow(
    String label,
    String value, {
    IconData? icon,
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: iconColor ?? Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: TextStyle(color: Theme.of(context).colorScheme.secondary),
          ),
        ],
      ),
    );
  }
}
