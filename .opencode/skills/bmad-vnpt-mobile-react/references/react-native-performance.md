# React Native Performance Guide

Performance optimization strategies and best practices for React Native applications.

## Performance Budgets

### Recommended Targets

| Metric | Target | User Impact |
|--------|--------|-------------|
| **App size** | <50MB initial (Expo), <30MB (bare) | Download abandonment |
| **Launch time** | <2s cold start | 70% abandon if >3s |
| **Screen load** | <1s cached, <2s network | Perceived performance |
| **Memory** | <100MB typical, <200MB peak | Crashes, OOM kills |
| **Battery** | <5% per hour active | Uninstall reason #1 |
| **Frame rate** | 60 FPS (16.67ms) | Janky animations |

## React Native-Specific Considerations

### Bridge Communication

The JavaScript bridge is a bottleneck. Minimize bridge calls:

```javascript
// ❌ Bad: Many bridge calls
{items.map(item => <Text key={item.id}>{item.name}</Text>)}

// ✅ Good: Reduce bridge calls with optimized rendering
<FlatList
  data={items}
  renderItem={({ item }) => <Item name={item.name} />}
  keyExtractor={item => item.id}
/>
```

### Hermes Engine

**Always use Hermes** for production:

```json
// metro.config.js
{
  "transformer": "hermes-transformer"
}

// Or with Expo (default in SDK 46+)
// app.json
{
  "jsEngine": "hermes"
}
```

**Benefits:**
- 30-40% faster startup
- Reduced memory usage
- Pre-compiled bytecode

---

## Optimization Techniques

### 1. Use FlatList for Long Lists

```javascript
// ✅ Good: Virtualized list
<FlatList
  data={items}
  renderItem={({ item }) => <ItemCard item={item} />}
  keyExtractor={item => item.id}
  initialNumToRender={10}
  maxToRenderPerBatch={10}
  windowSize={5}
/>

// ❌ Bad: ScrollView renders all items
<ScrollView>
  {items.map(item => <ItemCard key={item.id} item={item} />)}
</ScrollView>
```

**Important props:**
- `removeClippedSubviews={true}` - Remove off-screen views
- `maxToRenderPerBatch={10}` - Limit per batch
- `windowSize={5}` - Small rendering window
- `getItemLayout` - Fixed height improves performance

### 2. Memoize Expensive Computations

```javascript
import { useMemo, useCallback } from 'react';

// Memoize expensive calculations
const sortedList = useMemo(
  () => items.sort((a, b) => a.name.localeCompare(b.name)),
  [items]
);

// Memoize callbacks
const handlePress = useCallback(
  (itemId) => {
    onPressItem(itemId);
  },
  [onPressItem]
);
```

### 3. Avoid Inline Functions/Objects

```javascript
// ❌ Bad: Creates new function on every render
<Item onPress={() => console.log('pressed')} />
<Item style={{ padding: 16 }} />

// ✅ Good: Stable reference
const handlePress = useCallback(() => {
  console.log('pressed');
}, []);

const itemStyle = useMemo(() => ({ padding: 16 }), []);

<Item onPress={handlePress} style={itemStyle} />
```

### 4. Use React.memo for Components

```javascript
// Prevent re-renders when props haven't changed
const ItemCard = React.memo(({ item, onPress }) => {
  return <TouchableOpacity onPress={onPress}>
    <Text>{item.name}</Text>
  </TouchableOpacity>;
});

// With custom comparison
const ItemCard = React.memo(
  ({ item, onPress }) => {
    return <TouchableOpacity onPress={onPress}>
      <Text>{item.name}</Text>
    </TouchableOpacity>;
  },
  (prevProps, nextProps) => {
    return prevProps.item.id === nextProps.item.id;
  }
);
```

### 5. Optimize Images

```javascript
// Use optimized images
import { Image } from 'react-native';

<FlatList
  data={images}
  renderItem={({ item }) => (
    <Image
      source={{ uri: item.url }}
      resizeMode="cover"
      // Optimize
      style={{ width: 100, height: 100 }}
      // Progressive loading
      defaultSource={require('./placeholder.png')}
    />
  )}
/>;

// Or use react-native-fast-image
import FastImage from 'react-native-fast-image';

<FastImage
  source={{ uri: item.url, priority: FastImage.priority.normal }}
  resizeMode={FastImage.resizeMode.contain}
/>
```

---

## Performance Profiling

### React Native Performance Monitor

```javascript
// Enable performance overlay
// Shake device → "Show Perf Monitor"

// Shows:
// - RAM usage
// - JS and UI frame rates
// - Views count
```

### Flipper Performance Plugin

```bash
# Install Flipper
npm install -g flipper

# Add to app
npm install --save-dev react-native-flipper

# Features:
# - CPU profiler
# - Memory profiler
# - Network inspector
```

### Systrace (Android)

```bash
# Capture performance trace
python systrace.py --time=10 -o trace.html sched freq idle am wm gfx view binder_driver hal dalvik camera input res

# Open in browser
# Look for long frames (>16ms)
```

---

## Common Performance Issues

### Issue: Slow List Scrolling

**Symptoms:** Frame drops when scrolling

**Solutions:**
- Use `FlatList` instead of `ScrollView`
- Implement `getItemLayout` for fixed height items
- Use `removeClippedSubviews`
- Optimize `renderItem` component with `React.memo`

### Issue: Slow App Launch

**Solutions:**
- Defer non-critical initialization
- Use lazy loading for features
- Enable Hermes
- Optimize bundle size

### Issue: High Memory Usage

**Solutions:**
- Dispose subscriptions and listeners
- Use `FlatList` instead of `ScrollView`
- Optimize image loading and caching
- Profile with Flipper Memory plugin

---

## Bundle Size Optimization

### Analyze Bundle Size

```bash
# For Android
npx react-native bundle --platform android --dev false --entry-file index.js --bundle-output output.js

# Analyze
npx react-native-bundle-visualizer

# For Expo
eas build --profile
```

### Reduction Strategies

```javascript
// 1. Tree shaking
// Only import what you use
import { Text } from 'react-native'; // ✅
import * as RN from 'react-native';  // ❌

// 2. Conditional imports
import { Platform } from 'react-native';

const Component = Platform.select({
  ios: () => require('./IOSComponent'),
  android: () => require('./AndroidComponent'),
})();

// 3. Lazy loading
const HeavyScreen = React.lazy(() => import('./HeavyScreen'));
```

---

## Hermes Optimization

### Configuration

```javascript
// metro.config.js
module.exports = {
  transformer: {
    getTransformOptions: async () => ({
      transform: {
        experimentalImportSupport: false,
        inlineRequires: true,
      },
    }),
  },
};
```

### Benefits

- **Pre-compiled bytecode** - No JIT compilation at runtime
- **Smaller APK/IPA** - Bytecode is smaller than JS source
- **Faster startup** - No parsing/compiling at launch
- **Lower memory** - More efficient garbage collection

---

## Platform-Specific Optimization

### iOS

```javascript
// Use compile-time constants
const Constants = {
  API_URL: 'https://api.example.com',
};

// Avoid inline styles in hot paths
const styles = StyleSheet.create({
  container: {
    padding: 16,
  },
});
```

### Android

```javascript
// Enable Proguard (release builds)
// android/app/build.gradle
android {
  buildTypes {
    release {
      minifyEnabled true
      shrinkResources true
      proguardFiles getDefaultProguardFile('proguard-android.txt')
    }
  }
}

// Use Hermes
// app.json or android/app/build.gradle
project.ext.react = [
  enableHermes: true
]
```

---

## Testing Performance

### Performance Testing

```javascript
// Measure render time
import { Performance } from 'react-native';

const measureFunction = (fn) => {
  const start = Performance.now();
  fn();
  const end = Performance.now();
  console.log(`Execution time: ${end - start}ms`);
};

// Test list performance
measureFunction(() => {
  renderList();
});
```

### Benchmarking

```bash
# Run on release build
npx react-native run-android --variant=release
npx react-native run-ios --configuration=Release

# Profile with Flipper
flipper
```

---

## Resources

**Official:**
- [React Native Performance](https://reactnative.dev/docs/performance)
- [Hermes Engine](https://hermesengine.dev/)
- [Flipper](https://fbflipper.com/)

**Tools:**
- [react-native-bundle-visualizer](https://www.npmjs.com/package/react-native-bundle-visualizer)
- [react-native-fast-image](https://github.com/DylanVann/react-native-fast-image)

**Examples:**
- See `../examples/performance_examples.tsx`
