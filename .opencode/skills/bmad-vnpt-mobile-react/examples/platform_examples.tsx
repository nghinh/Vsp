// React Native Platform Integration Examples
// See also: ../references/react-native-platform-guide.md

import React from 'react';
import {
  Platform,
  StyleSheet,
  Text,
  View,
  TouchableOpacity,
  TextInput,
  ActivityIndicator,
  NativeModules,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { request, PERMISSIONS, RESULTS } from 'react-native-permissions';

// ===== Platform Detection =====

export function PlatformExample() {
  return (
    <View style={styles.container}>
      <Text>Platform: {Platform.OS}</Text>
      <Text>Version: {Platform.Version as string}</Text>

      {/* Platform-specific code */}
      {Platform.OS === 'ios' && <IOSComponent />}
      {Platform.OS === 'android' && <AndroidComponent />}
    </View>
  );
}

function IOSComponent(): JSX.Element {
  return (
    <View style={styles.iosContainer}>
      <Text style={styles.iosText}>iOS-specific UI</Text>
    </View>
  );
}

function AndroidComponent(): JSX.Element {
  return (
    <View style={styles.androidContainer}>
      <Text style={styles.androidText}>Android-specific UI</Text>
    </View>
  );
}

// ===== Platform-Aware Button =====

interface PlatformButtonProps {
  title: string;
  onPress: () => void;
}

export function PlatformButton({ title, onPress }: PlatformButtonProps): JSX.Element {
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

// ===== Platform-Specific Styles =====

export const platformStyles = Platform.select({
  ios: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
  },
  android: {
    elevation: 4,
  },
});

// ===== Safe Area Handling =====

export function SafeAreaExample(): JSX.Element {
  const insets = useSafeAreaInsets();

  return (
    <View style={[styles.container, { paddingTop: insets.top }]}>
      <Text>Content respects safe area</Text>
    </View>
  );
}

// ===== Permissions =====

export async function requestCameraPermission(): Promise<boolean> {
  if (Platform.OS === 'ios') {
    const status = await request(PERMISSIONS.IOS.CAMERA);
    return status === RESULTS.GRANTED;
  }

  const status = await request(PERMISSIONS.ANDROID.CAMERA);
  return status === RESULTS.GRANTED;
}

export async function requestLocationPermission(): Promise<boolean> {
  if (Platform.OS === 'ios') {
    const status = await request(PERMISSIONS.IOS.LOCATION_WHEN_IN_USE);
    return status === RESULTS.GRANTED;
  }

  const status = await request(PERMISSIONS.ANDROID.ACCESS_FINE_LOCATION);
  return status === RESULTS.GRANTED;
}

// ===== Platform Module Usage =====

export function NativeModuleExample(): JSX.Element {
  const [batteryLevel, setBatteryLevel] = React.useState<string>('Loading...');

  React.useEffect(() => {
    getBatteryLevel();
  }, []);

  async function getBatteryLevel() {
    try {
      const { BatteryModule } = NativeModules;
      if (BatteryModule) {
        const level = await BatteryModule.getBatteryLevel();
        setBatteryLevel(`Battery: ${level}%`);
      }
    } catch (error) {
      setBatteryLevel('Failed to get battery level');
    }
  }

  return (
    <View style={styles.container}>
      <Text>{batteryLevel}</Text>
      <PlatformButton title="Refresh" onPress={getBatteryLevel} />
    </View>
  );
}

// ===== Platform-Aware Input =====

interface PlatformInputProps {
  placeholder: string;
  value: string;
  onChangeText: (text: string) => void;
  secureTextEntry?: boolean;
}

export function PlatformInput({
  placeholder,
  value,
  onChangeText,
  secureTextEntry = false,
}: PlatformInputProps): JSX.Element {
  const inputStyle = Platform.select({
    ios: styles.iosInput,
    android: styles.androidInput,
  });

  return (
    <TextInput
      style={inputStyle}
      placeholder={placeholder}
      value={value}
      onChangeText={onChangeText}
      secureTextEntry={secureTextEntry}
      placeholderTextColor="#999"
      underlineColorAndroid="transparent"
    />
  );
}

// ===== Styles =====

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 16,
  },

  // iOS styles
  iosContainer: {
    backgroundColor: '#F2F2F7',
    padding: 16,
    borderRadius: 12,
  },
  iosText: {
    color: '#000',
    fontSize: 17,
    fontWeight: '600',
  },
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
    textAlign: 'center',
  },
  iosInput: {
    backgroundColor: '#FFFFFF',
    borderColor: '#C7C7CC',
    borderWidth: 1,
    borderRadius: 8,
    padding: 12,
    fontSize: 17,
  },

  // Android styles
  androidContainer: {
    backgroundColor: '#FFFFFF',
    padding: 16,
    elevation: 2,
  },
  androidText: {
    color: '#212121',
    fontSize: 16,
    fontWeight: '500',
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
    textAlign: 'center',
    textTransform: 'uppercase',
  },
  androidInput: {
    backgroundColor: '#F5F5F5',
    paddingHorizontal: 12,
    paddingVertical: 8,
    fontSize: 16,
  },
});
