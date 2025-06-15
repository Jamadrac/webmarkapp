import 'dart:async';
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
  Map<String, bool> _controlLoading = {};
  bool _showControls = false; // Controls visibility state
  Timer? _statusTimer;
  int _failedAttempts = 0;
  static const int _maxFailedAttempts = 3;
  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.user?.id;

    if (userId == null) {
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

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  // Periodic status updates
  void _startStatusUpdates() {
    // Initial update
    _updateAssetStatus();

    // Start periodic updates every 5 seconds
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _updateAssetStatus();
      } else {
        timer.cancel();
      }
    });
  }

  // Update asset status with comprehensive error handling
  Future<void> _updateAssetStatus() async {
    if (!mounted) return;

    setState(() {
      _controlLoading['status'] = true;
    });

    try {
      final status = await _assetService.getModuleStatus(widget.asset.id);

      if (mounted) {
        setState(() {
          // Reset failed attempts on successful update
          _failedAttempts = 0;

          // Update all status fields
          widget.asset.engineOn = status['engineOn'] ?? widget.asset.engineOn;
          widget.asset.isActive = status['isActive'] ?? widget.asset.isActive;
          widget.asset.isOnline = status['isOnline'] ?? false;
          widget.asset.batteryLevel =
              status['batteryLevel']?.toString() ?? 'Unknown';
          widget.asset.signalStrength = status['signalStrength'] ?? 'unknown';
          widget.asset.speed = status['speed']?.toDouble() ?? 0.0;
          widget.asset.altitude = status['altitude']?.toDouble() ?? 0.0;
          widget.asset.lastUpdated =
              DateTime.tryParse(status['lastUpdated'] ?? '') ?? DateTime.now();
          widget.asset.errorState = status['errorState'];

          _controlLoading['status'] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _failedAttempts++;

        setState(() {
          widget.asset.isOnline = false;
          _controlLoading['status'] = false;

          if (_failedAttempts >= _maxFailedAttempts) {
            widget.asset.errorState = 'Connection lost';
            // Show error only after multiple failed attempts
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Lost connection to device. Retrying...'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        });
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

  Widget _buildControlSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required String controlType,
    Color activeColor = Colors.green,
    Color? textColor,
  }) {
    return Column(
      children: [
        SwitchListTile(
          title: Text(title),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: textColor ?? (value ? activeColor : Colors.grey),
            ),
          ),
          value: value,
          activeColor: activeColor,
          onChanged:
              _isLoading || _controlLoading[controlType] == true
                  ? null
                  : onChanged,
          secondary:
              _controlLoading[controlType] == true
                  ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                    ),
                  )
                  : null,
        ),
        const Divider(),
      ],
    );
  }

  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required VoidCallback onPressed,
    required String controlType,
    Color backgroundColor = Colors.blue,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          ElevatedButton.icon(
            onPressed:
                _isLoading || _controlLoading[controlType] == true
                    ? null
                    : onPressed,
            icon:
                _controlLoading[controlType] == true
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : Icon(icon),
            label: const Text('Activate'),
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build the expansion tile header
  Widget _buildExpansionHeader() {
    return Row(
      children: [
        Icon(
          _showControls ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(width: 8),
        Text(
          'Controls',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIndicators() {
    final deviceStatus = widget.asset;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Device Status',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Online Status
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: deviceStatus.isOnline ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                deviceStatus.isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  color: deviceStatus.isOnline ? Colors.green : Colors.grey,
                ),
              ),
              if (deviceStatus.lastUpdated != null) ...[
                const Text(' • '),
                Text(
                  'Last seen: ${_formatLastSeen(deviceStatus.lastUpdated!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Battery and Signal
          Row(
            children: [
              Icon(
                Icons.battery_full,
                color: _getBatteryColor(deviceStatus.batteryLevel),
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(deviceStatus.batteryLevel ?? 'Unknown'),
              const SizedBox(width: 16),
              Icon(
                Icons.signal_cellular_alt,
                color: _getSignalColor(deviceStatus.signalStrength),
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(
                deviceStatus.signalStrength?.toUpperCase() ?? 'Unknown',
                style: TextStyle(
                  color: _getSignalColor(deviceStatus.signalStrength),
                ),
              ),
            ],
          ),

          // Error State
          if (deviceStatus.errorState != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      deviceStatus.errorState!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatLastSeen(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Color _getBatteryColor(String? level) {
    if (level == null) return Colors.grey;
    final numericLevel = int.tryParse(level.replaceAll('%', '')) ?? 0;
    if (numericLevel > 50) return Colors.green;
    if (numericLevel > 20) return Colors.orange;
    return Colors.red;
  }

  Color _getSignalColor(String? strength) {
    switch (strength?.toLowerCase()) {
      case 'excellent':
        return Colors.green;
      case 'good':
        return Colors.blue;
      case 'fair':
        return Colors.orange;
      case 'poor':
        return Colors.red;
      default:
        return Colors.grey;
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
            _CollapsibleControls(
              asset: widget.asset,
              isLoading: _isLoading,
              controlLoading: _controlLoading,
              onControlAction: (controlType, value) {
                switch (controlType) {
                  case 'engine':
                    _controlEngine(value!);
                    break;
                  case 'power':
                    _controlPower(value!);
                    break;
                  case 'alarm':
                    _triggerAlarm();
                    break;
                  case 'lost-mode':
                    _activateLostMode();
                    break;
                  default:
                    break;
                }
              },
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

class _CollapsibleControls extends StatelessWidget {
  final GpsAsset asset;
  final bool isLoading;
  final Map<String, bool> controlLoading;
  final Function(String, bool?) onControlAction;

  const _CollapsibleControls({
    required this.asset,
    required this.isLoading,
    required this.controlLoading,
    required this.onControlAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ExpansionTile(
            initiallyExpanded: false,
            title: Row(
              children: [
                Icon(Icons.toggle_off, color: theme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Device Controls',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
              ],
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: theme.cardColor,
                child: Column(
                  children: [
                    // Engine Control
                    _buildControl(
                      context,
                      title: 'Engine Control',
                      value: asset.engineOn,
                      onChanged: (value) => onControlAction('engine', value),
                      isLoading: controlLoading['engine'] ?? false,
                      activeColor: Colors.green,
                      subtitle:
                          asset.engineOn ? 'Engine is ON' : 'Engine is OFF',
                      subtitleColor: asset.engineOn ? Colors.green : Colors.red,
                    ),
                    const Divider(),

                    // Power Control
                    _buildControl(
                      context,
                      title: 'Power Control',
                      value: asset.isActive,
                      onChanged: (value) => onControlAction('power', value),
                      isLoading: controlLoading['power'] ?? false,
                      activeColor: Colors.blue,
                      subtitle: asset.isActive ? 'Power is ON' : 'Power is OFF',
                      subtitleColor: asset.isActive ? Colors.blue : Colors.grey,
                    ),
                    const Divider(),

                    // Alarm Control
                    _buildActionButton(
                      context,
                      title: 'Alarm Control',
                      onPressed: () => onControlAction('alarm', null),
                      isLoading: controlLoading['alarm'] ?? false,
                      icon: Icons.volume_up,
                      label: 'Sound Alarm',
                      backgroundColor: Colors.orange,
                    ),
                    const Divider(),

                    // Lost Mode
                    _buildActionButton(
                      context,
                      title: 'Lost Mode',
                      onPressed: () => onControlAction('lost-mode', null),
                      isLoading: controlLoading['lost-mode'] ?? false,
                      icon: Icons.gps_fixed,
                      label: 'Activate',
                      backgroundColor: Colors.red,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControl(
    BuildContext context, {
    required String title,
    required bool value,
    required Function(bool) onChanged,
    required bool isLoading,
    required Color activeColor,
    required String subtitle,
    required Color subtitleColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            Row(
              children: [
                if (isLoading)
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(right: 8),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                    ),
                  ),
                Switch(
                  value: value,
                  onChanged: isLoading ? null : onChanged,
                  activeColor: activeColor,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: subtitleColor, fontSize: 14)),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String title,
    required VoidCallback onPressed,
    required bool isLoading,
    required IconData icon,
    required String label,
    required Color backgroundColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            ElevatedButton.icon(
              onPressed: isLoading ? null : onPressed,
              icon:
                  isLoading
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : Icon(icon),
              label: Text(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: backgroundColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
