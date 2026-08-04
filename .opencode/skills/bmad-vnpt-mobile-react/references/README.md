# VNPT React Native Mobile References & Examples

Comprehensive guides and code examples for React Native mobile development.

## 📚 Reference Guides

### [react-native-debugging.md](./react-native-debugging.md)
Comprehensive debugging techniques, tools, and best practices.

**Topics:** React DevTools, Flipper, Performance debugging, Memory profiling, Network debugging, Crash analysis

### [react-native-performance.md](./react-native-performance.md)
Performance optimization strategies and best practices.

**Topics:** Performance budgets, FlatList optimization, Memoization, Hermes engine, Bundle size optimization

### [react-native-offline-guide.md](./react-native-offline-guide.md)
Offline-first architecture and data synchronization.

**Topics:** Local storage options, TanStack Query patterns, Optimistic UI, Network awareness, Sync strategies

### [react-native-platform-guide.md](./react-native-platform-guide.md)
Platform integration for iOS and Android.

**Topics:** Platform detection, iOS permissions, Android permissions, Native modules, Platform-aware components

### [react-native-testing-guide.md](./react-native-testing-guide.md)
Comprehensive testing strategies.

**Topics:** Unit tests (Jest), Component tests (RNTL), E2E tests (Detox), Testing hooks and mutations

---

## 💻 Code Examples

### [../examples/performance_examples.tsx](../examples/performance_examples.tsx)
Performance optimization code examples.

- Memoized components with React.memo
- FlatList vs ScrollView comparison
- useMemo and useCallback patterns
- Optimized list rendering

### [../examples/offline_examples.tsx](../examples/offline_examples.tsx)
Offline-first architecture examples.

- TanStack Query optimistic mutations
- Network-aware components
- Sync manager implementation
- Offline error handling

### [../examples/platform_examples.tsx](../examples/platform_examples.tsx)
Platform integration examples.

- Platform detection (Platform.OS)
- Platform-specific components
- iOS Safe Area handling
- Android permissions
- Native module usage
- Platform-aware inputs and buttons

### [../examples/testing_examples.tsx](../examples/testing_examples.tsx)
Testing code examples.

- Unit tests with Jest
- Hook tests with renderHook
- Component tests with RNTL
- TanStack Query testing
- Mutation testing

---

## 🚀 Quick Start

### For Debugging

```bash
# Start Metro with debugging
npx react-native start

# Flipper for iOS/Android
flipper

# React DevTools
npm install -g react-devtools
react-devtools

# LogBox - ignore warnings in development
import { LogBox } from 'react-native';
LogBox.ignoreLogs(['Warning: ...']);
```

### For Performance

```typescript
// Use FlatList instead of ScrollView
<FlatList
  data={items}
  renderItem={({ item }) => <ItemCard item={item} />}
  keyExtractor={(item) => item.id}
  removeClippedSubviews={true}
/>

// Memoize expensive computations
const sortedItems = useMemo(
  () => items.sort((a, b) => a.name.localeCompare(b.name)),
  [items]
);

// Memoize callbacks
const handlePress = useCallback(() => {
  onPressItem();
}, [onPressItem]);
```

### For Offline

```typescript
// TanStack Query for server state
import { useQuery, useMutation } from '@tanstack/react-query';

const { data, isLoading, error } = useQuery({
  queryKey: ['data'],
  queryFn: fetchData,
});

// Optimistic updates
const mutation = useMutation({
  mutationFn: updateData,
  onMutate: async (variables) => {
    // Cancel queries
    await queryClient.cancelQueries(['data']);
    // Snapshot previous value
    const previous = queryClient.getQueryData(['data']);
    // Optimistic update
    queryClient.setQueryData(['data'], (old) => [...old, newItem]);
    return { previous };
  },
  onError: (err, variables, context) => {
    // Rollback
    queryClient.setQueryData(['data'], context.previous);
  },
});
```

### For Platform

```typescript
// Platform detection
import { Platform } from 'react-native';

if (Platform.OS === 'ios') {
  // iOS-specific code
} else {
  // Android-specific code
}

// Platform-specific styles
const styles = Platform.select({
  ios: { shadowColor: '#000', shadowOpacity: 0.25 },
  android: { elevation: 4 },
});

// Platform-aware button
function PlatformButton({ title, onPress }) {
  if (Platform.OS === 'ios') {
    return <TouchableOpacity onPress={onPress} style={styles.iosButton}>...</TouchableOpacity>;
  }
  return <TouchableOpacity onPress={onPress} style={styles.androidButton}>...</TouchableOpacity>;
}
```

### For Testing

```bash
# Run all tests
npm test

# Watch mode
npm test -- --watch

# Coverage
npm test -- --coverage

# E2E with Detox
detox test --configuration ios.sim.debug
```

---

## 📋 Common Issues Lookup

| Issue | Reference |
|-------|-----------|
| App crashes on startup | [Debugging - Common Scenarios](./react-native-debugging.md#common-debugging-scenarios) |
| UI not updating | [Debugging - React Issues](./react-native-debugging.md#2-ui-not-updating) |
| Memory leaks | [Debugging - Memory](./react-native-debugging.md#memory-debugging) |
| Slow list scrolling | [Performance Guide](./react-native-performance.md#issue-slow-list-scrolling) |
| Offline not working | [Offline Guide](./react-native-offline-guide.md) |
| Platform permissions | [Platform Guide](./react-native-platform-guide.md) |
| Writing tests | [Testing Guide](./react-native-testing-guide.md) |

---

## 🔗 Additional Resources

**Official:**
- [React Native Docs](https://reactnative.dev/)
- [Expo Docs](https://docs.expo.dev/)
- [React Navigation](https://reactnavigation.org/)
- [TanStack Query](https://tanstack.com/query/latest)

**State Management:**
- [Zustand](https://github.com/pmndrs/zustand)
- [TanStack Query](https://tanstack.com/query/latest)

**Storage:**
- [AsyncStorage](https://react-native-async-storage.github.io/async-storage/)
- [MMKV](https://github.com/mrousavy/react-native-mmkv)
- [Realm](https://www.mongodb.com/realm)
- [WatermelonDB](https://github.com/Nozbe/WatermelonDB)

**Testing:**
- [React Native Testing Library](https://callstack.github.io/react-native-testing-library/)
- [Detox](https://wix.github.io/Detox/)
- [Jest](https://jestjs.io/)

**Tools:**
- [Flipper](https://fbflipper.com/)
- [React DevTools](https://react.dev/learn/react-developer-tools)
- [Hermes](https://hermesengine.dev/)

---

## 📂 Structure

```
bmad-vnpt-mobile-react/
├── SKILL.md                    # Main skill file (principles, decisions)
├── workflow.md                 # Working flow
├── references/                 # Theory & guides (this directory)
│   ├── react-native-debugging.md
│   ├── react-native-performance.md
│   ├── react-native-offline-guide.md
│   ├── react-native-platform-guide.md
│   ├── react-native-testing-guide.md
│   └── README.md              # This file
├── examples/                   # Code examples (TSX)
│   ├── performance_examples.tsx
│   ├── offline_examples.tsx
│   ├── platform_examples.tsx
│   └── testing_examples.tsx
├── templates/                  # Feature templates
├── scripts/                    # Utility scripts
└── skeleton/                   # Reference structure
```
