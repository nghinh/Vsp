# React Native Platform Integration Guide

Building React Native apps that feel native on iOS and Android.

## Platform-Specific Thinking

### iOS Mental Model

- Users expect **iOS navigation patterns** (swipe back, tab bar)
- Follow **HIG** (Human Interface Guidelines)
- Native iOS components feel
- Test on iPhones (various screen sizes)

### Android Mental Model

- Users expect **Material Design** patterns
- Follow **Material guidelines**
- Respect back button behavior
- Test on various Android devices/OS versions

### Cross-Platform Strategy

```
Platform-specific UI (when needed)
├── iOS: iOS-only components, navigation
└── Android: Material components, navigation

Shared Business Logic
├── TanStack Query (server state)
├── Zustand (client state)
├── Services & APIs
└── Utility functions
```

## Platform Detection

### Basic Platform Check

```typescript
import { Platform, PlatformOSType } from 'react-native';

// Check platform
const isIOS = Platform.OS === 'ios';
const isAndroid = Platform.OS === 'android';

// Platform-specific code
const styles = Platform.select({
  ios: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
  },
  android: {
    elevation: 4,
  },
});

// Component selection
const Button = Platform.select({
  ios: () => require('./IOSButton'),
  android: () => require('./MaterialButton'),
})();

<Button />;
```

### Platform Module

```typescript
import { Platform } from 'react-native';

// Get version
const version = Platform.Version; // iOS version or Android API level

// Get constants
const constants = Platform.constants;
const isPhone = constants?.interfaceIdiom === 'phone';
const isTablet = constants?.interfaceIdiom === 'tablet';

// Screen info
const screenWidth = constants?.screenWidth;
const screenHeight = constants?.screenHeight;
```

## iOS Integration

### iOS Permissions

Add to `ios/YourApp/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to take photos</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to provide accurate results</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need photo library access to upload images</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>We need permission to save photos to your library</string>
```

Request in React Native:

```typescript
import { request, PERMISSIONS, RESULTS } from 'react-native-permissions';

async function requestIOSPermissions() {
  const cameraStatus = await request(PERMISSIONS.IOS.CAMERA);
  const locationStatus = await request(PERMISSIONS.IOS.LOCATION_WHEN_IN_USE);

  if (cameraStatus === RESULTS.GRANTED && locationStatus === RESULTS.GRANTED) {
    // All permissions granted
  }
}
```

### iOS-Specific Components

```typescript
import { SegmentedControlIOS, PickerIOS } from 'react-native';

// Segmented Control
<SegmentedControlIOS
  values={['One', 'Two']}
  selectedIndex={0}
  onChange={(event) => {
    console.log(event.nativeEvent.selectedSegmentIndex);
  }}
/>

// iOS Picker
<PickerIOS
  selectedValue={selectedValue}
  onValueChange={(itemValue) => setSelectedValue(itemValue)}
>
  <PickerIOS.Item label="Option 1" value="option1" />
  <PickerIOS.Item label="Option 2" value="option2" />
</PickerIOS>
```

### Safe Area (iOS Notch)

```typescript
import { useSafeAreaInsets } from 'react-native-safe-area-context';

function MyScreen() {
  const insets = useSafeAreaInsets();

  return (
    <View style={{ paddingTop: insets.top }}>
      {/* Content */}
    </View>
  );
}

// Or with SafeAreaView
import { SafeAreaView } from 'react-native-safe-area-context';

function MyScreen() {
  return (
    <SafeAreaView style={{ flex: 1 }}>
      {/* Content */}
    </SafeAreaView>
  );
}
```

## Android Integration

### Android Permissions

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

Request in React Native:

```typescript
import { request, PERMISSIONS, RESULTS } from 'react-native-permissions';

async function requestAndroidPermissions() {
  const cameraStatus = await request(PERMISSIONS.ANDROID.CAMERA);
  const locationStatus = await request(PERMISSIONS.ANDROID.ACCESS_FINE_LOCATION);

  if (cameraStatus === RESULTS.GRANTED && locationStatus === RESULTS.GRANTED) {
    // All permissions granted
  }
}

// Multiple permissions
const statuses = await requestMultiple([
  PERMISSIONS.ANDROID.CAMERA,
  PERMISSIONS.ANDROID.ACCESS_FINE_LOCATION,
]);
```

### Material Design Components

```typescript
import { TextInput, Button, ActivityIndicator } from 'react-native';

// Material Design inputs
<TextInput
  style={styles.input}
  placeholder="Enter text"
  placeholderTextColor="#999"
  underlineColorAndroid="transparent"
/>

// Material buttons
<Button title="Click me" onPress={handlePress} color="#6200EE" />

// Activity indicator
<ActivityIndicator size="large" color="#6200EE" />
```

## Platform Modules

### Creating Native Modules

**iOS (Swift):**

```swift
// ios/NativeModule.m
#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(NativeModule, NSObject)

RCT_EXTERN_METHOD(getBatteryLevel:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

@end
```

```swift
// ios/NativeModule.swift
import UIKit

@objc(NativeModule)
class NativeModule: NSObject {
  @objc
  static func requiresMainQueueSetup() -> Bool {
    return true
  }

  @objc
  func getBatteryLevel(_ resolve: RCTPromiseResolveBlock,
                       reject: RCTPromiseRejectBlock) {
    UIDevice.current.isBatteryMonitoringEnabled = true
    let batteryLevel = UIDevice.current.batteryLevel
    if batteryLevel >= 0 {
      resolve(batteryLevel * 100)
    } else {
      reject("UNAVAILABLE", "Battery level not available", nil)
    }
  }
}
```

**Android (Kotlin):**

```kotlin
// android/app/src/main/java/com/yourapp/NativeModule.kt
package com.yourapp

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.Promise

class NativeModule(reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  override fun getName(): String {
    return "NativeModule"
  }

  @ReactMethod
  fun getBatteryLevel(promise: Promise) {
    val batteryLevel = getBatteryLevel()
    if (batteryLevel != -1) {
      promise.resolve(batteryLevel)
    } else {
      promise.reject("UNAVAILABLE", "Battery level not available", null)
    }
  }

  private fun getBatteryLevel(): Int {
    val batteryStatus: Intent? = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
    val level: Int = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
    val scale: Int = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
    return if (level != -1 && scale != -1) {
      (level * 100 / scale.toFloat()).toInt()
    } else {
      -1
    }
  }
}
```

**Usage in React Native:**

```typescript
import { NativeModules } from 'react-native';

const { NativeModule } = NativeModules;

async function getBatteryLevel() {
  try {
    const level = await NativeModule.getBatteryLevel();
    console.log(`Battery: ${level}%`);
  } catch (error) {
    console.error('Failed to get battery level:', error);
  }
}
```

## Platform-Aware Components

### Platform-Aware Button

```typescript
import { Platform, TouchableOpacity, Text, StyleSheet } from 'react-native';

interface ButtonProps {
  title: string;
  onPress: () => void;
}

export function PlatformButton({ title, onPress }: ButtonProps) {
  if (Platform.OS === 'ios') {
    return (
      <TouchableOpacity
        onPress={onPress}
        style={styles.iosButton}
        activeOpacity={0.7}
      >
        <Text style={styles.iosButtonText}>{title}</Text>
      </TouchableOpacity>
    );
  }

  return (
    <TouchableOpacity
      onPress={onPress}
      style={styles.androidButton}
      activeOpacity={0.7}
    >
      <Text style={styles.androidButtonText}>{title}</Text>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  iosButton: {
    backgroundColor: '#007AFF',
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderRadius: 8,
  },
  iosButtonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
  },
  androidButton: {
    backgroundColor: '#6200EE',
    paddingVertical: 10,
    paddingHorizontal: 16,
    borderRadius: 4,
    elevation: 2,
  },
  androidButtonText: {
    color: '#FFFFFF',
    fontSize: 14,
    fontWeight: '500',
    textTransform: 'uppercase',
  },
});
```

### Platform-Aware Navigation

```typescript
import { Platform } from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createMaterialBottomTabNavigator } from '@react-navigation/material-bottom-tabs';

const TabScreens = () => {
  if (Platform.OS === 'ios') {
    const Tab = createBottomTabNavigator();
    return (
      <Tab.Navigator>
        <Tab.Screen name="Home" component={HomeScreen} />
        <Tab.Screen name="Profile" component={ProfileScreen} />
      </Tab.Navigator>
    );
  }

  const Tab = createMaterialBottomTabNavigator();
  return (
    <Tab.Navigator>
      <Tab.Screen name="Home" component={HomeScreen} />
      <Tab.Screen name="Profile" component={ProfileScreen} />
    </Tab.Navigator>
  );
};
```

## Best Practices

1. **Respect platform conventions** - iOS feels like iOS, Android like Android
2. **Share business logic** - Use TanStack Query/Zustand across platforms
3. **Test on real devices** - Emulators don't show true platform behavior
4. **Use platform modules sparingly** - Most functionality exists in libraries
5. **Handle permissions gracefully** - Show why permissions are needed
6. **Use safe area** - Handle notches and different screen sizes

---

## Resources

**Official:**
- [Platform-Specific Code](https://reactnative.dev/docs/platform-specific-code)
- [Native Modules iOS](https://reactnative.dev/docs/native-modules-ios)
- [Native Modules Android](https://reactnative.dev/docs/native-modules-android)
- [iOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Material Design](https://m3.material.io/)

**Packages:**
- [react-native-permissions](https://github.com/zo0r/react-native-permissions)
- [react-native-safe-area-context](https://github.com/th3rdwave/react-native-safe-area-context)
- [@react-navigation/native](https://reactnavigation.org/)

**Examples:**
- See `../examples/platform_examples.tsx`
