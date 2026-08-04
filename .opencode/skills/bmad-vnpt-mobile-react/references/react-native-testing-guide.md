# React Native Testing Guide

Comprehensive testing strategies for React Native applications.

## Testing Pyramid

```
              /\
             /  \
            / E2E \        ← Few, slow, expensive (Detox/Appium)
           /--------\
          /Integration\    ← More, medium speed
         /------------\
        /   Component    \   ← Many, fast (React Native Testing Library)
       /----------------\
      /     Unit Tests     \ ← Most, fastest (Jest)
     /-----------------------\
```

## Testing Strategy

| Type | When to Use | Coverage Target | Speed |
|------|-------------|-----------------|-------|
| **Unit** | Business logic, utilities, hooks | 70-80% | Fastest |
| **Component** | Screen states, interactions | Critical screens | Fast |
| **E2E** | Auth, payment, critical flows | Critical paths | Medium |

---

## 1. Unit Testing with Jest

### Purpose
Test pure functions, utilities, hooks in isolation.

### Setup

```javascript
// jest.setup.js
import '@testing-library/jest-native/extend-expect';

// Mock native modules
jest.mock('react-native/Libraries/Utilities/Platform', () => ({
  OS: 'ios',
  select: jest.fn(),
}));

jest.mock('@react-native-async-storage/async-storage', () =>
  require('@react-native-async-storage/async-storage/jest/async-storage-mock')
);
```

### Example Tests

```typescript
// utils/validation.test.ts
import { validateEmail, validatePassword } from './validation';

describe('Validation Utils', () => {
  describe('validateEmail', () => {
    it('should return true for valid email', () => {
      expect(validateEmail('test@example.com')).toBe(true);
    });

    it('should return false for invalid email', () => {
      expect(validateEmail('invalid')).toBe(false);
      expect(validateEmail('test@')).toBe(false);
    });
  });

  describe('validatePassword', () => {
    it('should return true for strong password', () => {
      expect(validatePassword('StrongPass123!')).toBe(true);
    });

    it('should return false for weak password', () => {
      expect(validatePassword('weak')).toBe(false);
    });
  });
});
```

### Testing Hooks

```typescript
// hooks/useCounter.test.ts
import { renderHook, act } from '@testing-library/react-native';
import { useCounter } from './useCounter';

describe('useCounter', () => {
  it('should increment counter', () => {
    const { result } = renderHook(() => useCounter());

    expect(result.current.count).toBe(0);

    act(() => {
      result.current.increment();
    });

    expect(result.current.count).toBe(1);
  });

  it('should decrement counter', () => {
    const { result } = renderHook(() => useCounter());

    act(() => {
      result.current.decrement();
    });

    expect(result.current.count).toBe(-1);
  });
});
```

### Testing TanStack Query Hooks

```typescript
// hooks/useUsers.test.ts
import { renderHook, waitFor } from '@testing-library/react-native';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useUsers } from './useUsers';
import { server } from './mocks/server';

describe('useUsers', () => {
  beforeAll(() => server.listen());
  afterEach(() => server.resetHandlers());
  afterAll(() => server.close());

  it('should fetch users successfully', async () => {
    const queryClient = new QueryClient({
      defaultOptions: {
        queries: { retry: false },
      },
    });

    const wrapper = ({ children }) => (
      <QueryClientProvider client={queryClient}>
        {children}
      </QueryClientProvider>
    );

    const { result } = renderHook(() => useUsers(), { wrapper });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toEqual([
      { id: '1', name: 'John' },
      { id: '2', name: 'Jane' },
    ]);
  });
});
```

---

## 2. Component Testing with RNTL

### Purpose
Test component rendering, user interactions, state changes.

### Setup

```javascript
// jest.setup.js
import '@testing-library/jest-native/extend-expect';

// Mock navigation
jest.mock('@react-navigation/native', () => ({
  useNavigation: () => ({ navigate: jest.fn(), goBack: jest.fn() }),
  useRoute: () => ({ params: {} }),
}));
```

### Example Tests

```typescript
// screens/LoginScreen.test.tsx
import { render, screen, fireEvent, waitFor } from '@testing-library/react-native';
import { LoginScreen } from './LoginScreen';

describe('LoginScreen', () => {
  it('should render login form', () => {
    render(<LoginScreen />);

    expect(screen.getByPlaceholderText('Email')).toBeTruthy();
    expect(screen.getByPlaceholderText('Password')).toBeTruthy();
    expect(screen.getByText('Login')).toBeTruthy();
  });

  it('should show error for invalid email', () => {
    render(<LoginScreen />);

    const emailInput = screen.getByPlaceholderText('Email');
    fireEvent.changeText(emailInput, 'invalid-email');
    fireEvent.press(screen.getByText('Login'));

    expect(screen.getByText('Invalid email')).toBeTruthy();
  });

  it('should call login on valid input', async () => {
    const mockLogin = jest.fn();
    render(<LoginScreen onLogin={mockLogin} />);

    fireEvent.changeText(screen.getByPlaceholderText('Email'), 'test@example.com');
    fireEvent.changeText(screen.getByPlaceholderText('Password'), 'password123');
    fireEvent.press(screen.getByText('Login'));

    await waitFor(() => {
      expect(mockLogin).toHaveBeenCalledWith('test@example.com', 'password123');
    });
  });
});
```

### Testing with Navigation

```typescript
// screens/HomeScreen.test.tsx
import { render, screen, fireEvent } from '@testing-library/react-native';
import { NavigationContainer } from '@react-navigation/native';
import { HomeScreen } from './HomeScreen';

describe('HomeScreen', () => {
  const mockNavigate = jest.fn();

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('should navigate to profile on button press', () => {
    render(
      <NavigationContainer>
        <HomeScreen />
      </NavigationContainer>
    );

    fireEvent.press(screen.getByText('Profile'));

    // Verify navigation was called
    // In real test, use useNavigation mock
  });
});
```

---

## 3. E2E Testing with Detox

### Purpose
Test complete user flows across multiple screens.

### Setup

```javascript
// detox.config.js
module.exports = {
  testRunner: {
    args: {
      '$0': 'jest',
      config: 'e2e/config.json',
    },
  },
  apps: {
    'ios.debug': {
      type: 'ios.app',
      binaryPath: 'ios/build/Build/Products/Debug-iphonesimulator/MyApp.app',
    },
    'ios.release': {
      type: 'ios.app',
      binaryPath: 'ios/build/Build/Products/Release-iphonesimulator/MyApp.app',
    },
    'android.debug': {
      type: 'android.apk',
      binaryPath: 'android/app/build/outputs/apk/debug/app-debug.apk',
    },
  },
  devices: {
    simulator: {
      type: 'ios.simulator',
      device: { type: 'iPhone 14' },
    },
    emulator: {
      type: 'android.emulator',
      device: { avdName: 'Pixel_5_API_31' },
    },
  },
  configurations: {
    'ios.sim.debug': {
      device: 'simulator',
      app: 'ios.debug',
    },
    'android.emu.debug': {
      device: 'emulator',
      app: 'android.debug',
    },
  },
};
```

### Example E2E Tests

```typescript
// e2e/login.test.ts
describe('Login Flow', () => {
  beforeAll(async () => {
    await device.launchApp();
  });

  beforeEach(async () => {
    await device.reloadReactNative();
  });

  it('should login successfully', async () => {
    // Enter email
    await element(by.id('email-input')).typeText('test@example.com');

    // Enter password
    await element(by.id('password-input')).typeText('password123');

    // Tap login button
    await element(by.id('login-button')).tap();

    // Verify navigation to home screen
    await expect(element(by.id('home-screen'))).toBeVisible();
    await expect(element(by.text('Welcome'))).toBeVisible();
  });

  it('should show error for invalid credentials', async () => {
    await element(by.id('email-input')).typeText('wrong@example.com');
    await element(by.id('password-input')).typeText('wrongpassword');
    await element(by.id('login-button')).tap();

    await expect(element(by.text('Invalid credentials'))).toBeVisible();
  });
});
```

---

## Testing Best Practices

### 1. Test User Behavior, Not Implementation

```typescript
// ❌ Bad: Testing implementation
it('should set state to loading', () => {
  // Testing internal state
});

// ✅ Good: Testing user behavior
it('should show loading indicator while fetching', () => {
  render(<UserProfile userId="123" />);
  expect(screen.getByTestId('loading-indicator')).toBeTruthy();
});
```

### 2. Use Test IDs

```typescript
// Component
<TouchableOpacity testID="login-button" onPress={handleLogin}>
  <Text>Login</Text>
</TouchableOpacity>

// Test
await element(by.id('login-button')).tap();
```

### 3. Mock External Dependencies

```typescript
// Mock API
jest.mock('./api', () => ({
  login: jest.fn(() => Promise.resolve({ token: 'fake-token' })),
}));

// Mock AsyncStorage
jest.mock('@react-native-async-storage/async-storage', () =>
  require('@react-native-async-storage/async-storage/jest/async-storage-mock')
);
```

### 4. Test Async Operations

```typescript
it('should fetch and display data', async () => {
  render(<DataScreen />);

  // Loading state
  expect(screen.getByTestId('loading')).toBeTruthy();

  // Wait for data
  await waitFor(() => {
    expect(screen.getByText('Item 1')).toBeTruthy();
  });
});
```

---

## Running Tests

```bash
# Unit tests
npm test

# Watch mode
npm test -- --watch

# Coverage
npm test -- --coverage

# Component tests
npm test -- tests/components

# E2E tests with Detox
# Build app
npm run build:e2e

# Run tests
detox test --configuration ios.sim.debug

# Android E2E
detox test --configuration android.emu.debug
```

---

## Test Coverage

```bash
# Generate coverage
npm test -- --coverage

# View coverage report
open coverage/lcov-report/index.html
```

---

## Common Testing Patterns

### Testing TanStack Query

```typescript
import { renderHook, waitFor } from '@testing-library/react-native';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useData } from './useData';

const createWrapper = () => {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false },
    },
  });

  return ({ children }) => (
    <QueryClientProvider client={queryClient}>
      {children}
    </QueryClientProvider>
  );
};

describe('useData', () => {
  it('should fetch data successfully', async () => {
    const { result } = renderHook(() => useData(), {
      wrapper: createWrapper(),
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));
  });
});
```

### Testing Navigation

```typescript
import { render, screen } from '@testing-library/react-native';
import { NavigationContainer } from '@react-navigation/native';
import { RootNavigator } from './RootNavigator';

const renderWithNavigation = (component) => {
  return render(
    <NavigationContainer>
      {component}
    </NavigationContainer>
  );
};

describe('Navigation', () => {
  it('should navigate to details screen', () => {
    renderWithNavigation(<RootNavigator />);

    fireEvent.press(screen.getByText('Item 1'));

    expect(screen.getByText('Details')).toBeTruthy();
  });
});
```

---

## Resources

**Official:**
- [React Native Testing](https://reactnative.dev/docs/testing-overview)
- [Testing Library](https://callstack.github.io/react-native-testing-library/)
- [Detox](https://wix.github.io/Detox/)
- [Jest](https://jestjs.io/)

**Packages:**
- [@testing-library/react-native](https://github.com/callstack/react-native-testing-library)
- [@testing-library/jest-native](https://github.com/testing-library/jest-native)
- [react-native-mock-render](https://github.com/RootTechnology/react-native-mock-render)

**Examples:**
- See `../examples/testing_examples.tsx`
