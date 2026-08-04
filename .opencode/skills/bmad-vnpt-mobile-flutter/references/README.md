# VNPT Flutter Mobile References & Examples

Comprehensive guides and code examples for Flutter mobile development.

## 📚 Reference Guides

### [flutter-debugging.md](./flutter-debugging.md)
Comprehensive debugging techniques, tools, and best practices.

**Topics:** DevTools, Widget Inspector, Performance debugging, Memory profiling, Network debugging, Crash analysis

### [flutter-performance.md](./flutter-performance.md)
Performance optimization strategies and best practices.

**Topics:** Performance budgets, const widgets, ListView.builder, RepaintBoundary, Profiling, Common issues

### [flutter-offline-guide.md](./flutter-offline-guide.md)
Offline-first architecture and data synchronization.

**Topics:** Local storage options, Sync strategies, Optimistic UI, Network awareness, Best practices

### [flutter-platform-guide.md](./flutter-platform-guide.md)
Platform integration for iOS and Android.

**Topics:** Cupertino widgets, Material Design 3, Permissions, Platform channels, Platform-aware widgets

### [flutter-testing-guide.md](./flutter-testing-guide.md)
Comprehensive testing strategies.

**Topics:** Unit testing, Widget testing, Integration testing, Test patterns, Coverage

---

## 💻 Code Examples

### [../examples/performance_examples.dart](../examples/performance_examples.dart)
Performance optimization code examples.

- const vs non-const widgets
- Virtualized vs non-virtualized lists
- RepaintBoundary usage
- Keys for state preservation

### [../examples/offline_examples.dart](../examples/offline_examples.dart)
Offline-first architecture examples.

- Write-through cache pattern
- Optimistic UI updates
- Offline error handling
- Sync queue implementation

### [../examples/platform_examples.dart](../examples/platform_examples.dart)
Platform integration examples.

- Platform-specific UI (iOS/Android)
- Cupertino widgets (iOS)
- Material Design 3 (Android)
- Platform channels (Dart/Swift/Kotlin)
- Permission handling

### [../examples/testing_examples.dart](../examples/testing_examples.dart)
Testing code examples.

- Unit tests with mocks
- Widget tests
- Integration tests
- Test helpers and patterns

---

## 🚀 Quick Start

### For Debugging

```bash
# Launch DevTools
flutter pub global run devtools

# Enable debug painting
# Add to main.dart:
debugPaintSizeEnabled = true;

# Performance overlay
MaterialApp(showPerformanceOverlay: true)
```

### For Performance

```dart
// Use const widgets
const Text('Hello')

// Virtualized lists
ListView.builder(itemBuilder: (context, index) => ...)

// RepaintBoundary
RepaintBoundary(child: ExpensiveWidget())
```

### For Offline

```dart
// Check connectivity
final connectivity = await Connectivity().checkConnectivity();

// Use Hive for local storage
var box = await Hive.openBox('myBox');
await box.put('key', 'value');
```

### For Platform

```dart
// Platform-specific UI
if (Platform.isIOS) {
  return CupertinoPageScaffold(...);
}
return Scaffold(...);

// Platform channels
const platform = MethodChannel('com.example.app/native');
await platform.invokeMethod('methodName');
```

### For Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run integration tests
flutter test integration_test
```

---

## 📋 Common Issues Lookup

| Issue | Reference |
|-------|-----------|
| App crashes on startup | [Debugging - Common Scenarios](./flutter-debugging.md#common-debugging-scenarios) |
| UI not updating | [Debugging - UI Issues](./flutter-debugging.md#ui-debugging) |
| Memory leaks | [Debugging - Memory](./flutter-debugging.md#memory-debugging) |
| Slow performance | [Performance Guide](./flutter-performance.md) |
| Offline not working | [Offline Guide](./flutter-offline-guide.md) |
| Platform permissions | [Platform Guide](./flutter-platform-guide.md) |
| Writing tests | [Testing Guide](./flutter-testing-guide.md) |

---

## 🔗 Additional Resources

**Official Documentation:**
- [Flutter Docs](https://flutter.dev/)
- [Dart Docs](https://dart.dev/)
- [Flutter Testing](https://docs.flutter.dev/testing)
- [Flutter DevTools](https://docs.flutter.dev/tools/devtools)

**State Management:**
- [Riverpod](https://riverpod.dev/)
- [Flutter Bloc](https://bloclibrary.dev/)

**Packages:**
- [Hive (NoSQL)](https://docs.hivedb.dev/)
- [Drift (SQLite)](https://drift.simonbinder.eu/)
- [Connectivity Plus](https://pub.dev/packages/connectivity_plus)
- [Permission Handler](https://pub.dev/packages/permission_handler)

---

## 📂 Structure

```
bmad-vnpt-mobile-flutter/
├── SKILL.md                    # Main skill file (principles, decisions)
├── workflow.md                 # Working flow
├── references/                 # Theory & guides (this directory)
│   ├── flutter-debugging.md
│   ├── flutter-performance.md
│   ├── flutter-offline-guide.md
│   ├── flutter-platform-guide.md
│   ├── flutter-testing-guide.md
│   └── README.md              # This file
├── examples/                   # Code examples
│   ├── performance_examples.dart
│   ├── offline_examples.dart
│   ├── platform_examples.dart
│   └── testing_examples.dart
├── templates/                  # Feature templates
├── scripts/                    # Utility scripts
└── skeleton/                   # Reference structure
```
