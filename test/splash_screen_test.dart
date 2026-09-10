import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_sit1212/screens/splash_screen.dart';

void main() {
  testWidgets('SplashScreen renders EasySit and tagline correctly',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(),
      ),
    );

    // Initial render
    await tester.pump();

    // Verify "No More Searching" tagline
    expect(find.text('No More Searching'), findsOneWidget);

    // Verify "EasySit" RichText
    final richTextFinder = find.byWidgetPredicate((widget) {
      if (widget is RichText) {
        final text = widget.text.toPlainText();
        return text == 'EasySit';
      }
      return false;
    });
    expect(richTextFinder, findsOneWidget);
  });

  testWidgets('SplashScreen supports reduced motion',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: SplashScreen(),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('No More Searching'), findsOneWidget);
  });
}
