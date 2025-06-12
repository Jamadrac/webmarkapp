import 'package:flutter/material.dart';

import 'package:webmark/body/simulator/positio_location.dart' show GPSDevice;
import '../body/HomePage.dart';
import '../body/comments.dart';
import '../body/management.dart';
import '../body/profile.dart';
import '../body/settings.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final PageController _pageController = PageController();

  final List<Widget> _pages = [
    DashboardScreen(),
    const ProfileScreen(),
    const MangementScreen(),
    const commentsScreen(),
    const SettingsScreen(),
  ];

  // Method to navigate to hidden screens with optional update parameter
  void _navigateToHiddenScreen(Widget screen, {bool isUpdate = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => screen,
        // Optional: Add settings for update-specific navigation
        settings: RouteSettings(arguments: {'isUpdate': isUpdate}),
      ),
    );
  }

  // New method specifically for updates
  void _navigateToUpdate() {
    // You can customize this to navigate to a specific update screen
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update Options'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ElevatedButton(
              // onPressed: () {
              //   // Navigator.of(context).pop(); // Close dialog
              //   // _navigateToHiddenScreen(
              //   //   // const LocationTracker(),
              //   //   // isUpdate: true,
              //   // );
              // },
              //   child: const Text('Location Update'),
              // ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  _navigateToHiddenScreen(const GPSDevice(), isUpdate: true);
                },
                child: const Text('GPS Update'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getPageTitle(_selectedIndex)),
        actions: [
          // Update button with a distinct icon
          IconButton(
            icon: const Icon(Icons.gps_fixed),
            onPressed: () => _navigateToHiddenScreen(const GPSDevice()),
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.gps_fixed_outlined),
            activeIcon: Icon(Icons.gps_fixed),
            label: 'Track',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.route_outlined),
            activeIcon: Icon(Icons.route),
            label: 'Routes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }

  String _getPageTitle(int index) {
    switch (index) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Track Device';
      case 2:
        return 'Live Map';
      case 3:
        return 'Route History';
      case 4:
        return 'Settings';
      default:
        return 'GPS Tracking';
    }
  }
}
