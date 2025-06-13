import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:webmark/constants.dart';
import 'package:webmark/AUTH/providers/auth_provider.dart';
import 'package:webmark/AUTH/models/gps_asset_model.dart';
import 'package:webmark/body/asset_detail_screen.dart';
import 'package:webmark/body/add_asset_screen.dart';

class MangementScreen extends StatefulWidget {
  const MangementScreen({super.key});

  @override
  State<MangementScreen> createState() => _MangementScreenState();
}

class _MangementScreenState extends State<MangementScreen> {
  List<GpsAsset> assets = [];
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchAssets();
  }

  Future<void> fetchAssets() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userId = auth.user?.id;

      if (userId == null) {
        setState(() {
          errorMessage = 'User not authenticated';
          isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('${Constants.uri}/api/myDevices/user/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Raw API response: $data'); // Debug log

        if (data['gpsModules'] != null) {
          try {
            setState(() {
              assets =
                  (data['gpsModules'] as List).map((asset) {
                    print('Processing asset: $asset'); // Debug log
                    return GpsAsset.fromJson(asset);
                  }).toList();
              isLoading = false;
            });
          } catch (e) {
            print('Error parsing assets: $e'); // Debug log
            setState(() {
              errorMessage = 'Error parsing asset data: $e';
              isLoading = false;
            });
          }
        } else {
          setState(() {
            assets = [];
            errorMessage = 'No GPS modules found';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Failed to fetch assets: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        errorMessage = 'Error fetching assets: $error';
        isLoading = false;
      });
    }
  }

  Future<void> deleteAsset(String assetId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this asset?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        final response = await http.delete(
          Uri.parse('${Constants.uri}/api/gpsModule/$assetId'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          setState(() {
            assets.removeWhere((asset) => asset.id == assetId);
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Asset deleted successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to delete asset: ${response.statusCode}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting asset: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void navigateToAssetDetail(GpsAsset asset) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AssetDetailScreen(asset: asset)),
    );
  }

  void navigateToAddAsset() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddAssetScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: RefreshIndicator(
        color: colorScheme.primary,
        onRefresh: fetchAssets,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Error Message
                    if (errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colorScheme.error),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: colorScheme.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: TextStyle(color: colorScheme.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Loading State
            if (isLoading && assets.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (assets.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.devices_other,
                        size: 64,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No GPS modules found',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your first GPS module to start tracking',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final asset = assets[index];
                  final isActive = asset.isActive;
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    elevation: 2,
                    child: InkWell(
                      onTap: () => navigateToAssetDetail(asset),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color:
                                        isActive
                                            ? colorScheme.primary.withOpacity(
                                              0.1,
                                            )
                                            : colorScheme.error.withOpacity(
                                              0.1,
                                            ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.gps_fixed,
                                    color:
                                        isActive
                                            ? colorScheme.primary
                                            : colorScheme.error,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        asset.name,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        asset.serialNumber,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isActive
                                            ? colorScheme.primary.withOpacity(
                                              0.1,
                                            )
                                            : colorScheme.error.withOpacity(
                                              0.1,
                                            ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isActive ? 'Active' : 'Offline',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          isActive
                                              ? colorScheme.primary
                                              : colorScheme.error,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }, childCount: assets.length),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        onPressed: () => navigateToAddAsset(),
        child: const Icon(Icons.add),
      ),
    );
  }

  // Helper methods to keep code organized
  Widget _buildAssetCard(GpsAsset asset) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => navigateToAssetDetail(asset),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Asset Image
              Expanded(
                flex: 3,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blue[200]!, width: 2),
                  ),
                  child: ClipOval(
                    child:
                        asset.imageUrl.isNotEmpty
                            ? Image.network(
                              asset.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: Icon(
                                    Icons.device_hub,
                                    size: 40,
                                    color: Colors.grey[400],
                                  ),
                                );
                              },
                            )
                            : Container(
                              color: Colors.grey[200],
                              child: Icon(
                                Icons.device_hub,
                                size: 40,
                                color: Colors.grey[400],
                              ),
                            ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Asset Name
              Expanded(
                flex: 1,
                child: Text(
                  asset.name.isNotEmpty ? asset.name : 'Unnamed Asset',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 8),

              // Asset Details
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Serial:', asset.serialNumber),
                    _buildDetailRow(
                      'Model:',
                      asset.model.isNotEmpty ? asset.model : 'Unknown',
                    ),
                    _buildDetailRow(
                      'Device:',
                      asset.deviceName.isNotEmpty
                          ? asset.deviceName
                          : 'Unknown',
                    ),
                    _buildDetailRow('Last Seen:', _formatDate(asset.updatedAt)),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: () => navigateToAssetDetail(asset),
                    icon: const Icon(Icons.visibility),
                    color: Colors.blue[600],
                    tooltip: 'View Details',
                  ),
                  IconButton(
                    onPressed: () => deleteAsset(asset.id),
                    icon: const Icon(Icons.delete),
                    color: Colors.red[600],
                    tooltip: 'Delete Asset',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
