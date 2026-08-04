# Flutter Testing Guide

Comprehensive testing strategies for Flutter applications.

## Testing Pyramid

```
              /\
             /  \
            / E2E \        ← Few, slow, expensive
           /--------\
          /Integration\    ← More, medium speed
         /------------\
        /   Widget     \   ← Many, fast
       /----------------\
      /    Unit Tests    \ ← Most, fastest
     /--------------------\
```

## Testing Strategy

| Type | When to Use | Coverage Target | Speed |
|------|-------------|-----------------|-------|
| **Unit** | Business logic, pure functions | 70-80% | Fastest |
| **Widget** | Screen state, interactions | Critical screens | Fast |
| **Integration** | User flows, auth, payments | Critical paths | Medium |

## 1. Unit Testing

### Purpose
Test business logic, repositories, services in isolation.

### Setup

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:your_app/features/users/data/repositories/user_repository.dart';

class MockUserRepository extends Mock implements UserRepository {}
```

### Example

```dart
void main() {
  group('UserViewModel', () {
    late MockUserRepository mockRepository;
    late UserViewModel viewModel;

    setUp(() {
      mockRepository = MockUserRepository();
      viewModel = UserViewModel(mockRepository);
    });

    test('loadUsers should update state with users', () async {
      // Given
      final users = [User(id: '1', name: 'Test')];
      when(mockRepository.getUsers()).thenAnswer((_) async => users);

      // When
      await viewModel.loadUsers();

      // Then
      expect(viewModel.users, users);
      verify(mockRepository.getUsers()).called(1);
    });

    test('loadUsers should handle errors', () async {
      // Given
      when(mockRepository.getUsers()).thenThrow(Exception('Network error'));

      // When
      await viewModel.loadUsers();

      // Then
      expect(viewModel.hasError, true);
    });
  });
}
```

## 2. Widget Testing

### Purpose
Test widget rendering, state changes, user interactions.

### Example

```dart
void main() {
  testWidgets('Counter increments', (WidgetTester tester) async {
    // Build widget
    await tester.pumpWidget(const CounterApp());

    // Verify initial state
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap button
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump(); // Rebuild

    // Verify new state
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('LoginScreen validates email', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );

    // Find email field
    final emailField = find.byKey(const Key('email_field'));

    // Enter invalid email
    await tester.enterText(emailField, 'invalid');
    await tester.pump();

    // Verify error
    expect(find.text('Invalid email'), findsOneWidget);

    // Enter valid email
    await tester.enterText(emailField, 'test@example.com');
    await tester.pump();

    // Verify no error
    expect(find.text('Invalid email'), findsNothing);
  });

  testWidgets('ListView.builder renders items', (WidgetTester tester) async {
    final items = List.generate(100, (i) => 'Item $i');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) => Text(items[index]),
          ),
        ),
      ),
    );

    // Verify first item
    expect(find.text('Item 0'), findsOneWidget);

    // Scroll to item 50
    await tester.drag(
      find.byType(ListView),
      const Offset(0, -500),
    );
    await tester.pump();

    // Verify item 50 is visible
    expect(find.text('Item 50'), findsOneWidget);
  });
}
```

### Common Widget Testing Patterns

**Find widgets:**
```dart
find.byType(Text)
find.text('Hello')
find.byKey(Key('my_key'))
find.byIcon(Icons.add)
```

**Interact with widgets:**
```dart
await tester.tap(find.byType(ElevatedButton));
await tester.enterText(find.byKey(Key('field')), 'text');
await tester.drag(find.byType(ListView), Offset(0, -300));
```

**Trigger rebuild:**
```dart
await tester.pump(); // One frame
await tester.pumpAndSettle(); // All animations/async
```

## 3. Integration Testing

### Purpose
Test complete user flows across multiple screens/pages.

### Setup

`integration_test/app_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:your_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('full login flow', (WidgetTester tester) async {
    // Build app
    await tester.pumpWidget(const app.MyApp());

    // Navigate to login
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    // Enter credentials
    await tester.enterText(
      find.byKey(const Key('email_field')),
      'test@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('password_field')),
      'password123',
    );

    // Submit
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    // Verify navigation to home
    expect(find.text('Welcome'), findsOneWidget);
  });
}
```

## Testing Best Practices

### 1. Arrange-Act-Assert Pattern

```dart
test('loadUsers', () async {
  // Arrange
  final users = [User(id: '1', name: 'Test')];
  when(mockRepository.getUsers()).thenAnswer((_) async => users);

  // Act
  await viewModel.loadUsers();

  // Assert
  expect(viewModel.users, users);
});
```

### 2. Descriptive Test Names

```dart
// ❌ Bad
test('test1', () {});

// ✅ Good
test('loadUsers should update state when repository returns data', () {});
```

### 3. Test Helpers

```dart
// Create reusable test helpers
class TestHelpers {
  static Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder,
  ) async {
    var found = false;
    for (var i = 0; i < 5; i++) {
      await tester.pump(Duration(seconds: 1));
      if (finder.evaluate().isNotEmpty) {
        found = true;
        break;
      }
    }
    expect(found, true, reason: 'Widget not found');
  }
}
```

## Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget/login_screen_test.dart

# Run with coverage
flutter test --coverage

# Run integration tests
flutter test integration_test

# Run on specific platform
flutter test -d chrome    # Web
flutter test -d macos    # macOS
```

## Test Coverage

```bash
# Generate coverage report
flutter test --coverage

# Convert to HTML (requires lcov)
genhtml coverage/lcov.info -o coverage/html

# Open in browser
open coverage/html/index.html
```

## Resources

**Official:**
- [Flutter Testing](https://docs.flutter.dev/testing)
- [Widget Testing](https://docs.flutter.dev/cookbook/testing/widget/introduction)

**Packages:**
- [mockito](https://pub.dev/packages/mockito) - Mocking
- [integration_test](https://pub.dev/packages/integration_test) - Integration testing
- [golden_toolkit](https://pub.dev/packages/golden_toolkit) - Golden/screenshot testing

**Examples:**
- See `../examples/testing_examples.dart` for code examples
