// Flutter Testing Examples
// See also: ../references/flutter-testing-guide.md

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mockito/mockito.dart';

// ========== Mock Classes ==========

class MockUserRepository extends Mock implements UserRepository {}

// ========== Unit Testing ==========

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
      expect(viewModel.users, isEmpty);
      expect(viewModel.hasError, true);
    });
  });
}

// ========== Widget Testing ==========

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(const MyApp());

    // Verify that our counter starts at 0
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('LoginScreen validates email', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    // Find email field
    final emailField = find.byKey(const Key('email_field'));

    // Enter invalid email
    await tester.enterText(emailField, 'invalid-email');
    await tester.pump();

    // Verify error message
    expect(find.text('Invalid email'), findsOneWidget);

    // Enter valid email
    await tester.enterText(emailField, 'test@example.com');
    await tester.pump();

    // Verify no error
    expect(find.text('Invalid email'), findsNothing);
  });
}

// ========== Integration Testing ==========

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('full app login flow', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Test login flow
    await tester.enterText(
      find.byKey(const Key('email_field')),
      'test@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('password_field')),
      'password123',
    );
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();

    // Verify navigation to home screen
    expect(find.text('Welcome'), findsOneWidget);
  });

  group('end-to-end user journey', () {
    testWidgets('new user can register and login', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      // Navigate to registration
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      // Fill registration form
      await tester.enterText(
        find.byKey(const Key('name_field')),
        'John Doe',
      );
      await tester.enterText(
        find.byKey(const Key('email_field')),
        'john@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'password123',
      );

      // Submit registration
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Verify success message
      expect(find.text('Registration successful'), findsOneWidget);
    });
  });
}

// ========== Helper Classes for Examples ==========

class UserViewModel {
  final UserRepository _repository;
  List<User> users = [];
  bool hasError = false;

  UserViewModel(this._repository);

  Future<void> loadUsers() async {
    try {
      users = await _repository.getUsers();
      hasError = false;
    } catch (e) {
      hasError = true;
      users = [];
    }
  }
}

abstract class UserRepository {
  Future<List<User>> getUsers();
}

class User {
  final String id;
  final String name;
  User({required this.id, required this.name});
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Test')),
        body: Column(
          children: [
            const Text('0'),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _emailError;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextField(
            key: const Key('email_field'),
            controller: _emailController,
            decoration: InputDecoration(
              errorText: _emailError,
            ),
          ),
          TextField(
            key: const Key('password_field'),
            controller: _passwordController,
            obscureText: true,
          ),
          ElevatedButton(
            key: const Key('login_button'),
            onPressed: _validateAndLogin,
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  void _validateAndLogin() {
    setState(() {
      if (_emailController.text.contains('@')) {
        _emailError = null;
      } else {
        _emailError = 'Invalid email';
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
