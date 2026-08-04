# Flutter Platform Integration Guide

Building Flutter apps that feel native on iOS and Android.

## Platform-Specific Thinking

### iOS Mental Model

- Users expect **CupertinoWidget** patterns
- Follow **HIG** (Human Interface Guidelines)
- Native navigation: swipe back, tab bar
- Test on iPhones (various screen sizes)

### Android Mental Model

- Users expect **Material Design 3**
- Follow **Material guidelines**
- Respect back button behavior
- Test on various Android devices/OS versions

### Cross-Platform Strategy

```
Platform-specific UI (CupertinoWidget/MaterialWidget)
├── iOS: CupertinoPageScaffold, CupertinoNavigationBar
└── Android: Scaffold, AppBar (Material)

Shared Business Logic
├── State management (Riverpod/Bloc)
├── Repositories & Services
└── Domain models
```

## iOS Integration

### Cupertino Widgets

```dart
import 'package:flutter/cupertino.dart';

// Detect platform
final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

// Use Cupertino widgets for iOS
Widget build(BuildContext context) {
  if (isIOS) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('iOS Style'),
      ),
      child: ListView(...),
    );
  }
  return Scaffold(...); // Material for Android
}
```

### iOS Permissions

Add to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to take photos</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to provide accurate results</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need photo library access to upload images</string>
```

Request in Flutter:

```dart
import 'package:permission_handler/permission_handler.dart';

Future<void> requestIOSPermissions() async {
  final cameraStatus = await Permission.camera.request();
  final locationStatus = await Permission.location.request();

  if (cameraStatus.isGranted && locationStatus.isGranted) {
    // All permissions granted
  }
}
```

### HIG Compliance

**Navigation Patterns:**
- Tab bar for top-level navigation (2-5 items)
- Navigation bar for hierarchical navigation
- Modal presentations for self-contained flows

**Common Cupertino Widgets:**
- `CupertinoTabScaffold` / `CupertinoTabBar`
- `CupertinoNavigationBar`
- `CupertinoPageScaffold`
- `CupertinoListTile`
- `CupertinoSliverNavigationBar`

## Android Integration

### Material Design 3

```dart
MaterialApp(
  theme: ThemeData(
    useMaterial3: true, // Material Design 3
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      // Dynamic color for Android 12+
      dynamicSchemeVariant: DynamicSchemeVariant.tonal,
    ),
  ),
  home: const MyHomeScreen(),
)
```

### Android Permissions

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

Request in Flutter:

```dart
Future<void> requestAndroidPermissions() async {
  final statuses = await [
    Permission.camera,
    Permission.location,
    Permission.storage,
  ].request();

  if (statuses.values.every((status) => status.isGranted)) {
    // All permissions granted
  }
}
```

### Material Design 3 Components

- `NavigationRail` - Side navigation for tablets/desktops
- `NavigationBar` - Bottom navigation for phones
- `NavigationDrawer` - Drawer navigation
- `Card` - Material cards with elevation
- `FloatingActionButton` - FAB for primary actions

## Platform Channels

### When to Use Platform Channels

- Platform-specific features not available in Flutter
- Performance-critical operations
- Third-party SDKs without Flutter plugins

### Basic Pattern

**Dart Side:**

```dart
import 'package:flutter/services.dart';

class NativeHelper {
  static const platform = MethodChannel('com.example.app/native');

  Future<String> getBatteryLevel() async {
    try {
      final result = await platform.invokeMethod('getBatteryLevel');
      return '$result%';
    } on PlatformException catch (e) {
      return 'Failed: ${e.message}';
    }
  }

  Future<void> openNativeCamera() async {
    try {
      await platform.invokeMethod('openCamera');
    } on PlatformException catch (e) {
      debugPrint('Error: ${e.message}');
    }
  }
}
```

**iOS Side (Swift):**

```swift
// ios/Runner/AppDelegate.swift
import Flutter

override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
  let controller = window?.rootViewController as! FlutterViewController
  let channel = FlutterMethodChannel(
    name: "com.example.app/native",
    binaryMessenger: controller.binaryMessenger
  )

  channel.setMethodCallHandler({ [weak self] (call, result) in
    switch call.method {
    case "getBatteryLevel":
      result(UIDevice.current.batteryLevel)
    case "openCamera":
      self?.openCamera()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  })

  return super.application(application, didFinishLaunchingWithOptions: launchOptions)
}

private func openCamera() {
  // Native camera implementation
}
```

**Android Side (Kotlin):**

```kotlin
// android/app/src/main/kotlin/com/example/app/MainActivity.kt
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
  private val CHANNEL = "com.example.app/native"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "getBatteryLevel" -> {
            val batteryLevel = getBatteryLevel()
            result.success(batteryLevel)
          }
          "openCamera" -> {
            openCamera()
            result.success(null)
          }
          else -> result.notImplemented()
        }
      }
  }

  private fun getBatteryLevel(): Int {
    val batteryStatus: Intent? = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
    val level: Int = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
    val scale: Int = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
    return if (level != -1 && scale != -1) (level * 100 / scale.toFloat()).toInt() else -1
  }

  private fun openCamera() {
    // Native camera implementation
  }
}
```

## Platform-Aware Widgets

### Platform Adaptive Builder

```dart
class PlatformAdaptiveWidget extends StatelessWidget {
  const PlatformAdaptiveWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return switch (Theme.of(context).platform) {
      TargetPlatform.iOS => _buildIOS(),
      TargetPlatform.android => _buildAndroid(),
      _ => _buildWeb(), // Fallback
    };
  }

  Widget _buildIOS() {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('iOS')),
      child: CupertinoButton.filled(
        child: const Text('Button'),
        onPressed: () {},
      ),
    );
  }

  Widget _buildAndroid() {
    return Scaffold(
      appBar: AppBar(title: const Text('Android')),
      body: ElevatedButton(
        child: const Text('Button'),
        onPressed: () {},
      ),
    );
  }

  Widget _buildWeb() {
    // Fallback UI
    return const SizedBox.shrink();
  }
}
```

## Best Practices

1. **Respect platform conventions** - iOS feels like iOS, Android like Android
2. **Share business logic** - Use state management across platforms
3. **Test on real devices** - Emulators don't show true platform behavior
4. **Use platform channels sparingly** - Most functionality exists in Flutter plugins
5. **Handle permissions gracefully** - Show why permissions are needed

## Resources

**Official:**
- [Platform Channels](https://docs.flutter.dev/development/platform-integration/platform-channels)
- [iOS HIG](https://developer.apple.com/design/human-interface-guidelines/)
- [Material Design 3](https://m3.material.io/)

**Packages:**
- [permission_handler](https://pub.dev/packages/permission_handler)
- [flutter_platform_widgets](https://pub.dev/packages/flutter_platform_widgets)

**Examples:**
- See `../examples/platform_examples.dart` for code examples
