import 'package:flutter/material.dart';
import 'package:webmark/body/simulator/live_socket.dart' show LocationTracker;
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
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  _navigateToHiddenScreen(
                    const LocationTracker(),
                    isUpdate: true,
                  );
                },
                child: const Text('Location Update'),
              ),
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
            icon: const Icon(Icons.system_update_alt),
            onPressed: _navigateToUpdate,
          ),
          // Optional: Keep individual screen navigation if needed
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: () => _navigateToHiddenScreen(const LocationTracker()),
          ),
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
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Labour'),
          BottomNavigationBarItem(
            icon: Icon(Icons.monetization_on),
            label: 'Resources',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_rounded),
            label: 'Comments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }

  String _getPageTitle(int index) {
    switch (index) {
      case 0:
        return 'Home';
      case 1:
        return 'Labour Management';
      case 2:
        return 'Resource Management ddddd';
      case 3:
        return 'Comments';
      case 4:
        return 'Settings';
      default:
        return 'App';
    }
  }
}
