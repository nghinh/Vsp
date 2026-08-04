# Flutter Debugging Strategies

Comprehensive debugging techniques, tools, and best practices for Flutter development.

## Flutter Debugging Mindset

### Unique Mobile Debugging Challenges

1. **Device Diversity** - Thousands of device/OS combinations
2. **Resource Constraints** - Limited CPU, memory, battery
3. **Network Variability** - From WiFi to 2G, offline scenarios
4. **Platform Differences** - iOS vs Android behavior
5. **Real Device Testing** - Emulators don't show real performance
6. **Limited Debugging Access** - Can't SSH into production devices

### Golden Rules

1. **Test on real devices** - Emulators lie about performance
2. **Reproduce consistently** - Intermittent bugs need reproducible steps
3. **Check the obvious first** - Network, permissions, resources
4. **Isolate the platform** - Is it iOS-specific, Android-specific, or both?
5. **Monitor resources** - CPU, memory, battery, network
6. **Read the logs** - Device logs contain critical clues

---

## Flutter DevTools

### Launching DevTools

```bash
# From VS Code
# Debug → Open DevTools

# From command line
flutter pub global activate devtools
flutter pub global run devtools

# From Android Studio/IntelliJ
# Click DevTools icon in debugger toolbar
```

### DevTools Features

**1. Widget Inspector**
- Visual widget tree
- Widget property explorer
- Layout boundaries
- Flex layout visualizer

**2. Timeline View**
- Frame analysis (60 FPS target)
- Build phases (build, layout, paint)
- Identify performance bottlenecks

**3. Memory Profiler**
- Track memory allocation
- Identify memory leaks
- Heap snapshot analysis

**4. Network Profiler**
- HTTP request/response inspection
- Timing information
- Request/response headers and bodies

**5. Logging View**
- Structured logging
- Filter by level
- Timeline events

---

## Widget Inspector Debugging

### Debug Painting

```dart
// Enable debug painting in main.dart
void main() {
  debugPaintSizeEnabled = true;        // Show layout guides
  debugPaintBaselinesEnabled = true;   // Show text baselines
  debugPaintLayerBordersEnabled = true; // Show layer borders
  runApp(MyApp());
}

// Or from DevTools
// Toggle "Debug Paint" button
```

### Widget Tree Inspection

```dart
// Print widget tree
debugDumpApp();

// Print render tree
debugDumpRenderTree();

// Print layer tree
debugDumpLayerTree();

// Usage: Add in build() or during debugging
@override
Widget build(BuildContext context) {
  debugDumpApp(); // Print widget tree to console
  return Scaffold(...);
}
```

### Widget Keys for Debugging

```dart
// Use keys to identify widgets in DevTools
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return ItemCard(
      key: ValueKey(items[index].id), // Shows ID in DevTools
      item: items[index],
    );
  },
)
```

---

## Performance Debugging

### Performance Overlay

```dart
// Show FPS counter
void main() {
  runApp(
    MaterialApp(
      showPerformanceOverlay: true, // FPS counter overlay
      debugShowCheckedModeBanner: false,
      home: MyApp(),
    ),
  );
}

// Or from DevTools
// Toggle "Performance Overlay"
```

### Frame Rate Issues (< 60 FPS)

**Diagnosis:**

```dart
// Check for:
// - Build phase too long (>16ms)
// - Layout phase too long
// - Paint phase too long

// Common issues:
// 1. Heavy computations in build
// 2. Large lists without virtualization
// 3. Unnecessary rebuilds
```

**Solutions:**

```dart
// ❌ Bad: Heavy computation in build
Widget build(BuildContext context) {
  final sortedItems = items.toList()..sort(); // Runs every rebuild
  return ListView.builder(items: sortedItems);
}

// ✅ Good: Memoize expensive operations
class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  List<Item>? _sortedItems;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sortedItems = List.from(widget.items)..sort();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(items: _sortedItems!);
  }
}

// ❌ Bad: ScrollView with large data
ScrollView(
  children: items.map((item) => ItemCard(item)).toList(),
)

// ✅ Good: ListView.builder with virtualization
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemCard(items[index]),
  itemExtent: 80, // Fixed height improves performance
)
```

### Slow Animations

```dart
// Slow down animations for debugging
import 'package:flutter/scheduler.dart';

void main() {
  timeDilation = 5.0; // 5x slower
  runApp(MyApp());
}
```

---

## Memory Debugging

### Memory Profiler

**Usage:**
1. Open DevTools → Memory tab
2. Take heap snapshot
3. Perform actions
3. Take another snapshot
4. Compare to find memory leaks

### Common Memory Leaks

```dart
// ❌ Bad: Controller not disposed
class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late TextEditingController _controller;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _animController = AnimationController(vsync: this);
  }

  // Missing dispose!

  @override
  Widget build(BuildContext context) {
    return TextField(controller: _controller);
  }
}

// ✅ Good: Dispose controllers
class _MyWidgetState extends State<MyWidget> {
  @override
  void dispose() {
    _controller.dispose(); // Must dispose
    _animController.dispose(); // Must dispose
    super.dispose();
  }
}
```

```dart
// ❌ Bad: Timer not cancelled
class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      // Do something
    });
  }

  // Missing cleanup!
}

// ✅ Good: Cancel timer
class _MyWidgetState extends State<MyWidget> {
  @override
  void dispose() {
    _timer?.cancel(); // Cancel timer
    super.dispose();
  }
}
```

```dart
// ❌ Bad: Stream not cancelled
class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = someStream.listen((data) {
      setState(() {});
    });
  }

  // Missing cleanup!
}

// ✅ Good: Cancel stream
class _MyWidgetState extends State<MyWidget> {
  @override
  void dispose() {
    _subscription?.cancel(); // Cancel stream
    super.dispose();
  }
}
```

---

## Network Debugging

### DevTools Network Tab

```dart
// Automatically captures HTTP requests
import 'package:http/http.dart' as http;

Future<User> fetchUser(String id) async {
  final response = await http.get(
    Uri.parse('https://api.example.com/users/$id'),
  );

  // View in DevTools Network tab:
  // - All HTTP requests
  // - Headers and body
  // - Response times
  return User.fromJson(jsonDecode(response.body));
}
```

### Network Simulation

**Android Emulator:**
```
Settings → Network → Network Profile
Select: 3G, 4G, EDGE, Full
```

**iOS Simulator:**
```
Settings → Developer → Network Link Conditioner
Select: 100% Loss, Very Bad Network, etc.
```

### Offline Testing

```dart
// Test offline behavior
import 'package:connectivity_plus/connectivity_plus';

Future<bool> checkConnectivity() async {
  final connectivityResult = await Connectivity().checkConnectivity();
  return connectivityResult != ConnectivityResult.none;
}

// Usage in widget
if (!await checkConnectivity()) {
  // Show offline UI
  return OfflineScreen();
}
```

---

## Logging

### Structured Logging

```dart
import 'dart:developer' as developer;

// Simple print
print('User ID: $userId');

// Structured logging
developer.log(
  'User logged in',
  name: 'app.auth',
  error: error,
  stackTrace: stackTrace,
);

// Timeline events
developer.Timeline.startSync('fetchUsers');
await fetchUsers();
developer.Timeline.finishSync();
```

### Debug Print

```dart
// Only prints in debug mode
import 'package:flutter/foundation.dart';

void debugLog(String message) {
  if (kDebugMode) {
    print(message);
  }
}

// Usage
debugLog('User ID: $userId'); // Only in debug mode
```

---

## Breakpoint Debugging

### VS Code / Android Studio

```dart
// Set breakpoints in IDE
Future<User> fetchUser(String id) async {
  // Breakpoint here (click in gutter)
  final response = await http.get(
    Uri.parse('https://api.example.com/users/$id'),
  );

  // Debugger console commands:
  // p variable - print variable
  // Step over: F10
  // Step into: F11
  // Continue: F5
  return User.fromJson(jsonDecode(response.body));
}
```

### Conditional Breakpoints

```dart
// Right-click breakpoint → Condition
// Example: id == "123"

Future<User> fetchUser(String id) async {
  final response = await http.get(
    Uri.parse('https://api.example.com/users/$id'),
  );
  return User.fromJson(jsonDecode(response.body));
}
```

---

## Platform-Specific Debugging

### iOS Debugging

```bash
# View device logs
xcrun simctl spawn booted log stream --predicate 'processImagePath contains "YourApp"'

# iOS Simulator logs
open ~/Library/Logs/CoreSimulator/<DEVICE>/system.log

# Network Link Conditioner (simulate poor network)
# Settings → Developer → Network Link Conditioner
```

### Android Debugging

```bash
# View device logs
adb logcat

# Filter by app
adb logcat | grep com.yourcompany.yourapp

# Filter by tag
adb logcat MyTag:D *:S

# Clear logs
adb logcat -c

# Take screenshot
adb shell screencap -p /sdcard/screenshot.png
adb pull /sdcard/screenshot.png
```

---

## Common Debugging Scenarios

### 1. App Crashes on Startup

**Steps:**
1. Check crash logs (flutter logs)
2. Look for initialization errors
3. Verify dependencies loaded
4. Check permissions

**Example:**
```dart
// Error: Missing platform permission
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check permissions
  final status = await Permission.location.request();
  if (!status.isGranted) {
    // Handle permission denied
  }

  runApp(MyApp());
}
```

### 2. UI Not Updating

```dart
// ❌ Bad: Not calling setState
class MyWidget extends StatefulWidget {
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        counter++; // Won't rebuild
      },
      child: Text('Count: $counter'),
    );
  }
}

// ✅ Good: Call setState
class _MyWidgetState extends State<MyWidget> {
  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _counter++; // Triggers rebuild
        });
      },
      child: Text('Count: $_counter'),
    );
  }
}
```

### 3. Image Not Loading

```dart
// Debug image loading
Image.network(
  imageUrl,
  errorBuilder: (context, error, stackTrace) {
    print('Image error: $error');
    return Icon(Icons.error);
  },
  loadingBuilder: (context, child, loadingProgress) {
    if (loadingProgress == null) return child;
    return CircularProgressIndicator();
  },
)
```

### 4. Navigation Not Working

```dart
// ❌ Bad: Navigator context not available
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(...)); // May fail
      },
      child: Text('Go'),
    );
  }
}

// ✅ Good: Use Builder or navigatorKey
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => ElevatedButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(...));
        },
        child: Text('Go'),
      ),
    );
  }
}

// Or use GlobalKey
class MyApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      home: MyWidget(),
    );
  }
}

// Usage anywhere
MyApp.navigatorKey.currentState?.push(MaterialPageRoute(...));
```

---

## Crash Debugging

### Firebase Crashlytics

```dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

// Catch errors
FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

// Catch async errors
runZonedGuarded(() {
  runApp(MyApp());
}, (error, stackTrace) {
  FirebaseCrashlytics.instance.recordError(error, stackTrace);
});

// Log custom events
FirebaseCrashlytics.instance.log('User pressed purchase');

// Set user ID
FirebaseCrashlytics.instance.setUserIdentifier(userId);

// Force crash for testing
await FirebaseCrashlytics.instance.crash();
```

### Reading Stack Traces

```
# Example crash
════════ Exception caught by widgets library ═══════
The following assertion was thrown during performResize():
BoxConstraints forces an infinite width.

These invalid constraints were provided to RenderPositionedBox's layout() ...
═════════════════════════════════════════════════════════

Fix:
1. Check line number in stack trace
2. Find widget with infinite width constraint
3. Wrap in Flexible, Expanded, or SizedBox with width
```

---

## Debugging Checklist

**Before Filing Bug:**
- [ ] Reproduce on real device
- [ ] Check both iOS and Android
- [ ] Test on multiple OS versions
- [ ] Verify network connectivity
- [ ] Check app permissions
- [ ] Review recent code changes
- [ ] Check crash logs (flutter logs)

**Investigation:**
- [ ] Enable debug logging
- [ ] Use DevTools (Inspector, Timeline, Memory)
- [ ] Profile performance if slow
- [ ] Monitor memory usage
- [ ] Check network requests
- [ ] Inspect widget tree

**Production Issues:**
- [ ] Check Crashlytics dashboard
- [ ] Review user-reported issues
- [ ] Analyze affected OS versions
- [ ] Check affected devices
- [ ] Review recent app releases
- [ ] Compare crash-free rates

**After Fix:**
- [ ] Test on real devices
- [ ] Verify on affected OS versions
- [ ] Add regression test
- [ ] Monitor crash rates post-release

---

## Resources

**Official:**
- Flutter DevTools: https://docs.flutter.dev/tools/devtools
- Flutter Debugging: https://docs.flutter.dev/testing/debugging
- Performance Best Practices: https://docs.flutter.dev/perf/best-practices

**Crash Reporting:**
- Firebase Crashlytics: https://firebase.google.com/docs/crashlytics
- Sentry: https://docs.sentry.io/platforms/flutter/

**Tools:**
- Flutter DevTools (built-in)
- Android Studio Profiler
- Xcode Instruments (iOS)
