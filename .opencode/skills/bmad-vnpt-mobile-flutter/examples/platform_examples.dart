// Flutter Platform Integration Examples
// See also: ../references/flutter-platform-guide.md

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Example: Platform-specific UI
class PlatformSpecificExample extends StatelessWidget {
  const PlatformSpecificExample({super.key});

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    if (isIOS) {
      return _buildIOS();
    }
    return _buildAndroid();
  }

  Widget _buildIOS() {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('iOS Style'),
      ),
      child: ListView.builder(
        itemCount: 10,
        itemBuilder: (context, index) => CupertinoListTile(
          title: Text('Item $index'),
        ),
      ),
    );
  }

  Widget _buildAndroid() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Material Style'),
      ),
      body: ListView.builder(
        itemCount: 10,
        itemBuilder: (context, index) => ListTile(
          title: Text('Item $index'),
        ),
      ),
    );
  }
}

/// Example: iOS HIG Compliance (Tab Bar)
class IOSTabBarExample extends StatelessWidget {
  const IOSTabBarExample({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.profile_circled),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.settings),
            label: 'Settings',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        return CupertinoTabView(
          builder: (context) => _screens[index],
        );
      },
    );
  }

  static const List<Widget> _screens = [
    _HomeScreen(),
    _ProfileScreen(),
    _SettingsScreen(),
  ];
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Home'));
  }
}

class _ProfileScreen extends StatelessWidget {
  const _ProfileScreen();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Profile'));
  }
}

class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Settings'));
  }
}

/// Example: Android Material Design 3
class MaterialDesign3Example extends StatelessWidget {
  const MaterialDesign3Example({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true, // Material Design 3
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          // Dynamic color for Android 12+
          brightness: Brightness.light,
        ),
      ),
      home: const MyHomeScreen(),
    );
  }
}

class MyHomeScreen extends StatelessWidget {
  const MyHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NavigationRail(
        destinations: const [
          NavigationRailDestination(
            icon: Icon(Icons.home),
            label: Text('Home'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.person),
            label: Text('Profile'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.settings),
            label: Text('Settings'),
          ),
        ],
        selectedIndex: 0,
        onDestinationSelected: (index) {
          // Handle navigation
        },
      ),
    );
  }
}

/// Example: Platform Channel - Dart Side
import 'package:flutter/services.dart' as services;

class NativeHelper {
  static const platform = services.MethodChannel('com.example.app/native');

  Future<String> getBatteryLevel() async {
    try {
      final result = await platform.invokeMethod('getBatteryLevel');
      return '$result%';
    } on services.PlatformException catch (e) {
      return 'Failed to get battery level: ${e.message}';
    }
  }

  Future<void> openNativeCamera() async {
    try {
      await platform.invokeMethod('openCamera');
    } on services.PlatformException catch (e) {
      print('Error opening camera: ${e.message}');
    }
  }
}

/// Example: Requesting Permissions
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  static Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  static Future<Map<Permission, bool>> requestMultiplePermissions() async {
    final statuses = await [
      Permission.camera,
      Permission.location,
      Permission.storage,
    ].request();

    return statuses.map((key, value) => MapEntry(key, value.isGranted));
  }

  static Future<bool> checkPermission(Permission permission) async {
    final status = await permission.status;
    return status.isGranted;
  }

  static Future<void> openAppSettings() async {
    await openAppSettings();
  }
}

/// Example: Platform-aware widget
class PlatformAwareButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const PlatformAwareButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    if (isIOS) {
      return CupertinoButton(
        onPressed: onPressed,
        child: Text(text),
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      child: Text(text),
    );
  }
}

typedef VoidCallback = void Function();
