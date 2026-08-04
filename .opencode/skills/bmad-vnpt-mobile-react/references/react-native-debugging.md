# React Native Debugging Guide

Comprehensive debugging techniques, tools, and best practices for React Native development.

## Debugging Mindset

### Unique Mobile Debugging Challenges

1. **Device Diversity** - iOS & Android variations
2. **Resource Constraints** - Limited CPU, memory, battery
3. **Network Variability** - WiFi, 4G, 3G, offline
4. **Platform Differences** - iOS vs Android behavior
5. **Real Device Testing** - Simulators don't show real performance
6. **JavaScript Bridge** - Bridge communication overhead

### Golden Rules

1. **Test on real devices** - Emulators lie about performance
2. **Reproduce consistently** - Intermittent bugs need reproducible steps
3. **Check the obvious first** - Network, permissions, resources
4. **Isolate the platform** - iOS-specific vs Android-specific vs both
5. **Monitor resources** - CPU, memory, battery, network
6. **Read the logs** - Metro, device logs contain critical clues

---

## Debugging Tools

### React Native Debugger

```bash
# Install
npm install -g react-devtools

# Launch
react-devtools

# In app: Shake device → "Debug with React DevTools"
```

**Features:**
- React Component tree inspection
- Props and state inspection
- Performance profiling
- Network requests (with Flipper)

### Flipper (Recommended)

```bash
# Install
npm install -g flipper

# Add to app
npm install --save-dev react-native-flipper
```

**Features:**
- Layout inspector
- Network inspector
- Redux DevTools
- Database viewer (AsyncStorage)
- Shared Preferences viewer
- Logs

### Chrome DevTools

```javascript
// In app: Shake device → "Debug"
// Opens Chrome DevTools

// Console.log appears in Chrome
console.log('User data:', userData);

// Set breakpoints in source
debugger; // Pauses execution

// Network tab shows API calls
fetch('https://api.example.com/users')
  .then(res => res.json())
  .then(data => console.log(data));
```

### Hermes Debugger

```bash
# For Hermes engine
npx react-native run-android --hermes
npx react-native run-ios --hermes
```

---

## Performance Debugging

### Performance Monitor

```javascript
// Show in-app performance overlay
// Shake device → "Show Perf Monitor"

// Shows:
// - RAM usage
// - JS frame rate
// - UI frame rate
// - Views count
```

### Frame Rate Issues (< 60 FPS)

**Diagnosis:**

```javascript
// Common issues:
// 1. Heavy computations in render
// 2. Large lists without virtualization
// 3. Unnecessary re-renders
// 4. Expensive operations in useEffect
```

**Solutions:**

```javascript
// ❌ Bad: Heavy computation in render
function UserList({ users }) {
  const sortedUsers = users.sort((a, b) => a.name.localeCompare(b.name));
  return <FlatList data={sortedUsers} />;
}

// ✅ Good: Memoize expensive operations
function UserList({ users }) {
  const sortedUsers = useMemo(
    () => [...users].sort((a, b) => a.name.localeCompare(b.name)),
    [users]
  );
  return <FlatList data={sortedUsers} />;
}

// ❌ Bad: ScrollView with large data
<ScrollView>
  {users.map(user => <UserCard key={user.id} user={user} />)}
</ScrollView>

// ✅ Good: FlatList with virtualization
<FlatList
  data={users}
  renderItem={({ item }) => <ItemCard item={item} />}
  keyExtractor={item => item.id}
  windowSize={5}
  initialNumToRender={10}
  maxToRenderPerBatch={10}
/>
```

### Re-render Debugging

```javascript
import { whyDidYouUpdate } from 'why-did-you-render';

// In development
if (process.env.NODE_ENV === 'development') {
  whyDidYouUpdate(React);
}

// Check console for unnecessary re-renders
```

---

## Memory Debugging

### Memory Profiler

**Flipper Memory Profiler:**
- Track memory allocations
- Find memory leaks
- Heap snapshot analysis

### Common Memory Leaks

```javascript
// ❌ Bad: Event listener not removed
useEffect(() => {
  EventEmitter.on('data', handleData);
  // Missing cleanup
}, []);

// ✅ Good: Cleanup
useEffect(() => {
  EventEmitter.on('data', handleData);
  return () => {
    EventEmitter.off('data', handleData);
  };
}, []);

// ❌ Bad: Timer not cleared
useEffect(() => {
  setInterval(() => {
    console.log('tick');
  }, 1000);
}, []);

// ✅ Good: Clear timer
useEffect(() => {
  const timer = setInterval(() => {
    console.log('tick');
  }, 1000);
  return () => clearInterval(timer);
}, []);

// ❌ Bad: Subscription not cancelled
useEffect(() => {
  const subscription = observable.subscribe(data => {
    setState(data);
  });
  // Missing cleanup
}, []);

// ✅ Good: Cancel subscription
useEffect(() => {
  const subscription = observable.subscribe(data => {
    setState(data);
  });
  return () => subscription.unsubscribe();
}, []);
```

---

## Network Debugging

### Flipper Network Plugin

```javascript
// Automatically captures all fetch/axios requests
fetch('https://api.example.com/users')
  .then(res => res.json())
  .then(data => console.log(data));

// View in Flipper:
// - Request/response headers
// - Request/response body
// - Timing information
```

### Network Simulation

**iOS:**
```
Settings → Developer → Network Link Conditioner
Select: 3G, LTE, EDGE, Full
```

**Android:**
```
Emulator: Settings → Network → Network Profile
```

### Offline Testing

```javascript
import NetInfo from '@react-native-community/netinfo';

// Check connectivity
const checkConnectivity = async () => {
  const state = await NetInfo.fetch();
  return state.isConnected;
};

// Subscribe to network changes
useEffect(() => {
  const unsubscribe = NetInfo.addEventListener(state => {
    if (!state.isConnected) {
      // Show offline UI
    }
  });

  return () => unsubscribe();
}, []);
```

---

## Platform-Specific Debugging

### iOS Debugging

```bash
# View device logs
npx react-native log-ios
# Or in Xcode: Window → Devices and Simulators → View Device Logs

# iOS Simulator logs
console.log('Debug message'); // Shows in Metro terminal

# Network Link Conditioner (simulate poor network)
# Settings → Developer → Network Link Conditioner
```

### Android Debugging

```bash
# View device logs
npx react-native log-android
# Or adb logcat
adb logcat

# Filter by app
adb logcat | grep com.yourcompany.yourapp

# Filter by tag
adb logcat ReactNative:V ReactNativeJS:V *:S

# Clear logs
adb logcat -c
```

---

## Common Debugging Scenarios

### 1. App Crashes on Startup

**Steps:**
1. Check crash logs (Xcode/adb logcat)
2. Look for initialization errors
3. Verify dependencies linked
4. Check permissions

**Example:**
```javascript
// Error: Native module cannot be null
// Fix: Link native module
npx react-native link <module-name>
# or for Expo
npx expo install <module-name>
```

### 2. UI Not Updating

```javascript
// ❌ Bad: Mutating state directly
this.state.users.push(newUser); // Won't trigger re-render

// ✅ Good: Create new state
this.setState({ users: [...this.state.users, newUser] });

// Hooks:
// ❌ Bad: Direct mutation
users.push(newUser);

// ✅ Good: Create new array
setUsers([...users, newUser]);
```

### 3. Navigation Not Working

```javascript
// ❌ Bad: Navigation prop not available
function MyComponent() {
  navigation.navigate('Home'); // Error
}

// ✅ Good: Use hook or prop
function MyComponent({ navigation }) {
  navigation.navigate('Home');
}

// Or with hook
import { useNavigation } from '@react-navigation/native';

function MyComponent() {
  const navigation = useNavigation();
  navigation.navigate('Home');
}
```

### 4. Image Not Loading

```javascript
// Debug image loading
<Image
  source={{ uri: imageUrl }}
  onError={(error) => console.log('Image error:', error)}
  onLoad={() => console.log('Image loaded')}
  onLoadEnd={() => console.log('Image load end')}
/>

// Check network tab for 404, 403, etc.
```

---

## Crash Debugging

### Crashlytics Integration

```javascript
import crashlytics from '@react-native-firebase/crashlytics';

// Log custom events
crashlytics().log('User tapped purchase button');

// Set user identifier
crashlytics().setUserId(userId);

// Record non-fatal error
try {
  await riskyOperation();
} catch (error) {
  crashlytics().recordError(error);
}

// Force crash for testing
crashlytics().crash();
```

### Reading Stack Traces

```
Example crash:
Exception in native call
java.lang.NullPointerException: Attempt to invoke virtual method
    at com.example.app.UserModule.getName(UserModule.java:42)

Fix:
1. Check UserModule.java line 42
2. Find issue (null object)
3. Add null check
```

---

## Console Logging

### LogBox

```javascript
import { LogBox } from 'react-native';

// Ignore specific warnings
LogBox.ignoreLogs([
  'Warning: componentWillReceiveProps',
]);

// Ignore all logs (NOT recommended)
// LogBox.ignoreAllLogs();

// Custom logging
import { Platform } from 'react-native';

const log = (...args) => {
  if (__DEV__) {
    if (Platform.OS === 'ios') {
      console.log(...args);
    } else {
      console.log(...args.join(' '));
    }
  }
};
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
- [ ] Check crash logs

**Investigation:**
- [ ] Enable debug logging
- [ ] Use React DevTools/Flipper
- [ ] Profile performance if slow
- [ ] Monitor memory usage
- [ ] Check network requests
- [ ] Inspect component tree

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
- [ ] Staged rollout
- [ ] Monitor crash rates

---

## Resources

**Official:**
- [React Native Debugging](https://reactnative.dev/docs/debugging)
- [Flipper](https://fbflipper.com/)
- [React DevTools](https://react.dev/learn/react-developer-tools)

**Crash Reporting:**
- [Firebase Crashlytics](https://firebase.google.com/docs/crashlytics)
- [Sentry](https://docs.sentry.io/platforms/react-native/)

**Performance:**
- [React Native Performance](https://reactnative.dev/docs/performance)
- [Hermes Engine](https://hermesengine.dev/)
