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
              assets = (data['gpsModules'] as List)
                  .map((asset) {
                    print('Processing asset: $asset'); // Debug log
                    return GpsAsset.fromJson(asset);
                  })
                  .toList();
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
      MaterialPageRoute(
        builder: (context) => AssetDetailScreen(asset: asset),
      ),
    );
  }

  void navigateToAddAsset() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddAssetScreen()),
    );
  }

  Widget _buildAssetListItem(GpsAsset asset) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 30,
          backgroundColor: Colors.blue[100],
          child: asset.imageUrl.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    asset.imageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.device_hub, size: 30);
                    },
                  ),
                )
              : const Icon(Icons.device_hub, size: 30),
        ),
        title: Text(
          asset.name.isNotEmpty ? asset.name : 'Unnamed Asset',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Serial: ${asset.serialNumber}'),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: asset.isActive ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  asset.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: asset.isActive ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          color: Colors.red,
          onPressed: () => deleteAsset(asset.id),
        ),
        onTap: () => navigateToAssetDetail(asset),
      ),
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
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildAssetListItem(assets[index]),
                  childCount: assets.length,
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: navigateToAddAsset,
        child: const Icon(Icons.add),
      ),
    );
  }
}
