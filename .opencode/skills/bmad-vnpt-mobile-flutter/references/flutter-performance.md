# Flutter Performance Guide

Performance optimization strategies and best practices for Flutter applications.

## Performance Budgets

### Recommended Targets

| Metric | Target | User Impact |
|--------|--------|-------------|
| **App size** | <50MB initial, <200MB total | Download abandonment |
| **Launch time** | <2s cold start | 70% abandon if >3s |
| **Screen load** | <1s cached, <2s network | Perceived performance |
| **Memory** | <100MB typical, <200MB peak | Crashes, OOM kills |
| **Battery** | <5% per hour active | Uninstall reason #1 |
| **Frame rate** | 60 FPS (16.67ms) | Janky animations |

## Performance Optimization Techniques

### 1. Use const Widgets

**Why:** Compile-time constants are created once and reused, avoiding rebuild overhead.

```dart
// ✅ Good: Compile-time constant
const Text('Hello')
const SizedBox(height: 16)

// ❌ Bad: Rebuilt every render
Text('Hello')
SizedBox(height: 16)
```

### 2. ListView.builder for Long Lists

**Why:** Virtualization renders only visible items, not all items at once.

```dart
// ✅ Good: Virtualized list
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemCard(items[index]),
)

// ❌ Bad: All items built at once
Column(
  children: items.map((item) => ItemCard(item)).toList(),
)
```

### 3. RepaintBoundary for Expensive Widgets

**Why:** Isolates repaints to specific widget subtrees.

```dart
RepaintBoundary(
  child: ExpensiveWidget(),
)
```

### 4. Use Keys to Preserve State

**Why:** Keys help Flutter identify widgets and preserve their state across rebuilds.

```dart
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return ItemCard(
      key: ValueKey(items[index].id), // Preserve state
      item: items[index],
    );
  },
)
```

### 5. Avoid rebuilds with useMemoized / useCallback equivalents

```dart
// Use Riverpod's ref.watch or ref.read appropriately
// Use provider's select to only listen to specific values
final filteredItems = ref.watch(itemProvider.select((items) =>
  items.where((item) => item.isActive).toList()
));
```

## Performance Profiling

### Flutter DevTools

**Timeline View:**
- Identify slow frames (>16ms)
- Break down: Build, Layout, Paint phases

**Memory View:**
- Track memory allocations
- Find memory leaks
- Heap snapshot analysis

### Performance Overlay

```dart
MaterialApp(
  showPerformanceOverlay: true, // FPS counter
  home: MyApp(),
)
```

### Profile Mode

```bash
# Run in profile mode for realistic performance
flutter run --profile

# Build for release testing
flutter build apk --release
```

## Common Performance Issues

### Issue: Janky Animations

**Symptoms:** Frame rate drops below 60 FPS

**Solutions:**
- Use `RepaintBoundary` for animated widgets
- Avoid expensive operations in build()
- Use `const` constructors where possible
- Reduce widget tree depth

### Issue: Slow App Launch

**Solutions:**
- Defer non-critical initialization
- Use lazy loading for features
- Show UI before data is ready
- Avoid heavy computations in `main()`

### Issue: High Memory Usage

**Solutions:**
- Dispose controllers and subscriptions
- Use `ListView.builder` instead of `Column` for lists
- Optimize image loading (caching, resizing)
- Profile with DevTools Memory view

## Performance Tips by Category

### Startup Performance

```dart
// Defer initialization
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Only initialize critical services
  await initCriticalServices();

  runApp(MyApp());

  // Initialize non-critical services after first frame
  WidgetsBinding.instance.addPostFrameCallback((_) {
    initNonCriticalServices();
  });
}
```

### Runtime Performance

```dart
// Use itemBuilder for large lists
ListView.builder(
  itemBuilder: (context, index) => ItemWidget(items[index]),
)

// Avoid expensive operations in build
@override
Widget build(BuildContext context) {
  // ❌ Bad: Expensive computation
  final sorted = items.toList()..sort();

  // ✅ Good: Cache or use memoized value
  final sorted = _sortedItems ?? _computeSorted();
}
```

### Image Performance

```dart
// Use cached network images
CachedNetworkImage(
  imageUrl: url,
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.error),
)

// Optimize image sizes
// Resize images before loading
// Use appropriate formats (WebP for photos)
```

## Resources

**Official:**
- [Flutter Performance Best Practices](https://docs.flutter.dev/perf/best-practices)
- [Flutter Performance Profiling](https://docs.flutter.dev/perf/rendering/best-practices)

**Examples:**
- See `../examples/performance_examples.dart` for code examples
