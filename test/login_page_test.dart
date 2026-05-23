import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_flutter/login/login_page.dart';
import 'package:runner_flutter/login/signup_page.dart';

void main() {
  Widget buildSubject() {
    return const MaterialApp(home: LoginPage());
  }

  group('LoginPage', () {
    testWidgets('renders the login form', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('Run and Conquer your territory'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
    });

    testWidgets('keeps the password field obscured', (tester) async {
      await tester.pumpWidget(buildSubject());

      final passwordField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Password'),
      );

      expect(passwordField.obscureText, isTrue);
    });

    testWidgets('shows a validation snackbar when fields are empty', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Get Started'));
      await tester.pump();

      expect(find.text('이메일과 비밀번호를 입력해주세요.'), findsOneWidget);
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('navigates to the signup page from the signup action', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      expect(find.byType(SignupPage), findsOneWidget);
      expect(
        find.text('Sign up to start your running journey'),
        findsOneWidget,
      );
    });
  });
}
