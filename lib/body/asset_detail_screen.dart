import 'package:flutter/material.dart';
import 'package:webmark/AUTH/models/gps_asset_model.dart';

class AssetDetailScreen extends StatelessWidget {
  final GpsAsset asset;

  const AssetDetailScreen({super.key, required this.asset});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(asset.name.isNotEmpty ? asset.name : 'Asset Details'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
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
                        border: Border.all(color: Colors.blue[200]!, width: 3),
                      ),
                      child: ClipOval(
                        child: asset.imageUrl.isNotEmpty
                            ? Image.network(
                                asset.imageUrl,
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
                      asset.name.isNotEmpty ? asset.name : 'Unnamed Asset',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Status Indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Active',
                            style: TextStyle(
                              color: Colors.green,
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
            _buildInfoCard(
              'Device Information',
              [
                _buildInfoRow('Serial Number', asset.serialNumber),
                _buildInfoRow('Model', asset.model.isNotEmpty ? asset.model : 'Unknown'),
                _buildInfoRow('Device Name', asset.deviceName.isNotEmpty ? asset.deviceName : 'Unknown'),
                _buildInfoRow('Asset ID', asset.id),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Location Information Card
            _buildInfoCard(
              'Location Information',
              [
                if (asset.lastKnownLocation != null) ...[
                  _buildInfoRow('Latitude', asset.lastKnownLocation!.coordinates[0].toStringAsFixed(6)),
                  _buildInfoRow('Longitude', asset.lastKnownLocation!.coordinates[1].toStringAsFixed(6)),
                  _buildInfoRow('Location Type', asset.lastKnownLocation!.type),
                ] else
                  _buildInfoRow('Location', 'No location data available'),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Timestamps Card
            _buildInfoCard(
              'Timestamps',
              [
                _buildInfoRow('Created', _formatDateTime(asset.createdAt)),
                _buildInfoRow('Last Updated', _formatDateTime(asset.updatedAt)),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: asset.lastKnownLocation != null
                        ? () => _showLocationOnMap(context)
                        : null,
                    icon: const Icon(Icons.map),
                    label: const Text('View on Map'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _refreshAssetData(context),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
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

  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey[200],
      child: Icon(
        Icons.device_hub,
        size: 60,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
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
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showLocationOnMap(BuildContext context) {
    // TODO: Navigate to map screen with asset location
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Map view coming soon!'),
      ),
    );
  }

  void _refreshAssetData(BuildContext context) {
    // TODO: Implement refresh functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Asset data refreshed!'),
      ),
    );
  }
}
