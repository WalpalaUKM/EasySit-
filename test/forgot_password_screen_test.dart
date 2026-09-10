import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_sit1212/screens/forgot_password_screen.dart';

void main() {
  group('ForgotPasswordScreen Tests', () {
    testWidgets('Renders all initial UI components correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(),
        ),
      );

      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('Forgot Your Password?'), findsOneWidget);
      expect(find.text('Email Address or Student ID'), findsOneWidget);
      expect(find.text('Send Reset Instructions'), findsOneWidget);
      expect(find.text('Back to Login'), findsOneWidget);
      expect(find.byIcon(Icons.lock_reset_rounded), findsOneWidget);
    });

    testWidgets('Prepopulates initial identifier if supplied', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(
            initialIdentifier: 'CT2021045',
          ),
        ),
      );

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.controller?.text, equals('CT2021045'));
    });

    testWidgets('Shows error SnackBar when submitting an empty identifier', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ForgotPasswordScreen(),
          ),
        ),
      );

      final submitBtn = find.text('Send Reset Instructions');
      await tester.tap(submitBtn);
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text('Please enter your registered email address or Student ID'),
        findsNWidgets(2),
      );
    });
  });
}
