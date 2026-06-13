import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amazeloop/views/login_view.dart';

void main() {
  testWidgets('Login view shows the auth form', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginView()));

    expect(find.text('AmazeLoop'), findsOneWidget);
    expect(find.text('EMAIL ADDRESS'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
    expect(find.text('SIGN UP'), findsOneWidget);
    expect(find.text('LOG IN'), findsOneWidget);
  });
}
