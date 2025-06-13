import 'package:flutter/material.dart';
import 'package:webmark/AUTH/models/gps_asset_model.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class AssetDetailScreen extends StatefulWidget {
  final GpsAsset asset;

  const AssetDetailScreen({super.key, required this.asset});

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  final MapController _mapController = MapController();

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

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _refreshAssetData(context),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.secondary,
                      foregroundColor: colorScheme.onSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
}
