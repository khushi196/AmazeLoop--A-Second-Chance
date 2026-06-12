import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// This imports your actual main file
import 'package:amazeloop/main.dart'; 

void main() {
  testWidgets('App loads Login placeholder', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AmazonLoopApp());

    // Verify that our Login placeholder text is showing on startup
    expect(find.text('Login View Placeholder'), findsOneWidget);
  });
}