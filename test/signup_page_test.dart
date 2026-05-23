import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_flutter/login/signup_page.dart';

void main() {
  Widget buildSubject() {
    return const MaterialApp(home: SignupPage());
  }

  group('SignupPage', () {
    testWidgets('renders the signup form', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(SignupPage), findsOneWidget);
      expect(
        find.text('Sign up to start your running journey'),
        findsOneWidget,
      );
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
    });

    testWidgets('keeps password fields obscured', (tester) async {
      await tester.pumpWidget(buildSubject());

      final passwordField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Password'),
      );
      final confirmPasswordField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Confirm Password'),
      );

      expect(passwordField.obscureText, isTrue);
      expect(confirmPasswordField.obscureText, isTrue);
    });

    testWidgets('shows a validation snackbar when required fields are empty', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Sign Up'));
      await tester.pump();

      expect(find.text('이메일과 비밀번호를 입력해주세요.'), findsOneWidget);
      expect(find.byType(SignupPage), findsOneWidget);
    });

    testWidgets('shows a validation snackbar when passwords do not match', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      await tester.enterText(
        find.widgetWithText(TextField, 'Email Address'),
        'user@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'password-one',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm Password'),
        'password-two',
      );

      await tester.tap(find.text('Sign Up'));
      await tester.pump();

      expect(find.text('비밀번호가 일치하지 않습니다.'), findsOneWidget);
      expect(find.byType(SignupPage), findsOneWidget);
    });

    testWidgets('pops the page from the app bar back action', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignupPage()),
                  );
                },
                child: const Text('Open Signup'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Signup'));
      await tester.pumpAndSettle();
      expect(find.byType(SignupPage), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(SignupPage), findsNothing);
      expect(find.text('Open Signup'), findsOneWidget);
    });
  });
}
