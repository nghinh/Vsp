// React Native Testing Examples
// See also: ../references/react-native-testing-guide.md

import React, { useState } from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react-native';
import { renderHook, act } from '@testing-library/react-native';
import { useMutation, useQuery, QueryClient, QueryClientProvider } from '@tanstack/react-query';

// ===== Unit Tests Examples =====

// utils/validation.ts
export function validateEmail(email: string): boolean {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

export function validatePassword(password: string): boolean {
  return password.length >= 8;
}

// tests/validation.test.ts
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
});

// ===== Hook Testing Examples =====

export function useCounter(initialValue = 0) {
  const [count, setCount] = useState(initialValue);

  const increment = () => setCount((prev) => prev + 1);
  const decrement = () => setCount((prev) => prev - 1);
  const reset = () => setCount(initialValue);

  return { count, increment, decrement, reset };
}

// tests/useCounter.test.ts
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
    const { result } = renderHook(() => useCounter(5));

    act(() => {
      result.current.decrement();
    });

    expect(result.current.count).toBe(4);
  });

  it('should reset counter', () => {
    const { result } = renderHook(() => useCounter(10));

    act(() => {
      result.current.increment();
      result.current.increment();
    });

    expect(result.current.count).toBe(12);

    act(() => {
      result.current.reset();
    });

    expect(result.current.count).toBe(10);
  });
});

// ===== Component Testing Examples =====

export function LoginForm({ onLogin }: { onLogin: (email: string, password: string) => void }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [emailError, setEmailError] = useState('');

  const handleSubmit = () => {
    if (!validateEmail(email)) {
      setEmailError('Invalid email');
      return;
    }
    setEmailError('');
    onLogin(email, password);
  };

  return (
    <>
      <TextInput
        testID="email-input"
        placeholder="Email"
        value={email}
        onChangeText={setEmail}
        autoCapitalize="none"
      />
      {emailError !== '' && <Text testID="email-error">{emailError}</Text>}

      <TextInput
        testID="password-input"
        placeholder="Password"
        value={password}
        onChangeText={setPassword}
        secureTextEntry
      />

      <Button testID="login-button" title="Login" onPress={handleSubmit} />
    </>
  );
}

function Button({ testID, title, onPress }: { testID?: string; title: string; onPress: () => void }) {
  return (
    <TouchableOpacity testID={testID} onPress={onPress}>
      <Text>{title}</Text>
    </TouchableOpacity>
  );
}

// tests/LoginForm.test.tsx
describe('LoginForm', () => {
  const mockOnLogin = jest.fn();

  beforeEach(() => {
    mockOnLogin.mockClear();
  });

  it('should render login form', () => {
    render(<LoginForm onLogin={mockOnLogin} />);

    expect(screen.getByPlaceholderText('Email')).toBeTruthy();
    expect(screen.getByPlaceholderText('Password')).toBeTruthy();
    expect(screen.getByText('Login')).toBeTruthy();
  });

  it('should show error for invalid email', () => {
    render(<LoginForm onLogin={mockOnLogin} />);

    const emailInput = screen.getByPlaceholderText('Email');
    fireEvent.changeText(emailInput, 'invalid-email');
    fireEvent.press(screen.getByText('Login'));

    expect(screen.getByTestId('email-error')).toBeTruthy();
    expect(screen.getByText('Invalid email')).toBeTruthy();
  });

  it('should call login on valid input', () => {
    render(<LoginForm onLogin={mockOnLogin} />);

    fireEvent.changeText(screen.getByPlaceholderText('Email'), 'test@example.com');
    fireEvent.changeText(screen.getByPlaceholderText('Password'), 'password123');
    fireEvent.press(screen.getByText('Login'));

    expect(mockOnLogin).toHaveBeenCalledWith('test@example.com', 'password123');
  });
});

// ===== TanStack Query Testing Examples =====

export function useUsers() {
  return useQuery({
    queryKey: ['users'],
    queryFn: async () => {
      const response = await fetch('https://api.example.com/users');
      if (!response.ok) {
        throw new Error('Failed to fetch users');
      }
      return response.json() as Promise<User[]>;
    },
  });
}

interface User {
  id: string;
  name: string;
}

// tests/useUsers.test.ts
describe('useUsers', () => {
  it('should fetch users successfully', async () => {
    const queryClient = new QueryClient({
      defaultOptions: {
        queries: { retry: false },
      },
    });

    const wrapper = ({ children }: { children: React.ReactNode }) => (
      <QueryClientProvider client={queryClient}>
        {children}
      </QueryClientProvider>
    );

    // Mock fetch
    global.fetch = jest.fn(() =>
      Promise.resolve({
        ok: true,
        json: () => Promise.resolve([{ id: '1', name: 'John' }]),
      } as Response)
    );

    const { result } = renderHook(() => useUsers(), { wrapper });

    await waitFor(() => {
      expect(result.current.isSuccess).toBe(true);
    });

    expect(result.current.data).toEqual([{ id: '1', name: 'John' }]);
  });
});

// ===== Mutation Testing Examples =====

export function useCreateUser() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (userData: Omit<User, 'id'>) => {
      const response = await fetch('https://api.example.com/users', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(userData),
      });

      if (!response.ok) {
        throw new Error('Failed to create user');
      }

      return response.json() as Promise<User>;
    },

    onSuccess: (newUser) => {
      queryClient.invalidateQueries({ queryKey: ['users'] });
    },
  });
}

// tests/useCreateUser.test.ts
describe('useCreateUser', () => {
  it('should create user and invalidate queries', async () => {
    const queryClient = new QueryClient({
      defaultOptions: {
        queries: { retry: false },
      },
    });

    const wrapper = ({ children }: { children: React.ReactNode }) => (
      <QueryClientProvider client={queryClient}>
        {children}
      </QueryClientProvider>
    );

    const invalidateSpy = jest.spyOn(queryClient, 'invalidateQueries');

    global.fetch = jest.fn(() =>
      Promise.resolve({
        ok: true,
        json: () => Promise.resolve({ id: '1', name: 'John' }),
      } as Response)
    );

    const { result } = renderHook(() => useCreateUser(), { wrapper });

    act(() => {
      result.current.mutate({ name: 'John' });
    });

    await waitFor(() => {
      expect(result.current.isSuccess).toBe(true);
    });

    expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ['users'] });
    expect(result.current.data).toEqual({ id: '1', name: 'John' });
  });
});

// ===== Async Component Testing Example =====

export function UserList() {
  const { data, isLoading, error } = useUsers();

  if (isLoading) {
    return <Text testID="loading">Loading...</Text>;
  }

  if (error) {
    return <Text testID="error">Error loading users</Text>;
  }

  return (
    <>
      {data?.map((user) => (
        <Text key={user.id} testID={`user-${user.id}`}>
          {user.name}
        </Text>
      ))}
    </>
  );
}

// tests/UserList.test.tsx
describe('UserList', () => {
  it('should show loading initially', () => {
    const queryClient = new QueryClient({
      defaultOptions: {
        queries: {
          retry: false,
          staleTime: Infinity, // Prevent refetch
        },
      },
    });

    const wrapper = ({ children }: { children: React.ReactNode }) => (
      <QueryClientProvider client={queryClient}>
        {children}
      </QueryClientProvider>
    );

    render(<UserList />, { wrapper });

    expect(screen.getByTestId('loading')).toBeTruthy();
  });

  it('should display users after fetch', async () => {
    const queryClient = new QueryClient({
      defaultOptions: {
        queries: { retry: false },
      },
    });

    const wrapper = ({ children }: { children: React.ReactNode }) => (
      <QueryClientProvider client={queryClient}>
        {children}
      </QueryClientProvider>
    );

    global.fetch = jest.fn(() =>
      Promise.resolve({
        ok: true,
        json: () => Promise.resolve([{ id: '1', name: 'John' }, { id: '2', name: 'Jane' }]),
      } as Response)
    );

    render(<UserList />, { wrapper });

    await waitFor(() => {
      expect(screen.getByTestId('user-1')).toBeTruthy();
      expect(screen.getByText('John')).toBeTruthy();
      expect(screen.getByText('Jane')).toBeTruthy();
    });
  });
});

// ===== TypeScript Types =====

import { TouchableOpacity, TextInput, Text } from 'react-native';

declare const jest: {
  fn(): jest.Mock;
  clearAllMocks(): void;
  spyOn(obj: unknown, method: string): jest.SpyInstance;
};

declare function describe(name: string, fn: () => void): void;
declare function it(name: string, fn: () => void): void;
declare function expect(value: unknown): {
  toBe: (expected: unknown) => void;
  toEqual: (expected: unknown) => void;
  toBeTruthy: () => void;
  toHaveBeenCalled: () => void;
  toHaveBeenCalledWith: (...args: unknown[]) => void;
  toHaveBeenCalledTimes: (count: number) => void;
};

declare const test: {
  id: string;
};

declare const beforeEach: (fn: () => void) => void;
declare const act: (fn: () => void | Promise<void>) => void;
