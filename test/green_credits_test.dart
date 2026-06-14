import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amazeloop/data/models/purchase.dart';
import 'package:amazeloop/widgets/green_credit_badge.dart';

void main() {
  group('Purchase.greenCreditsEarned parsing', () {
    test('parses an integer credits value', () {
      final p = Purchase.fromJson({
        'evaluationId': 'E1',
        'title': 'Phone',
        'price': 5000,
        'purchaseStatus': 'SOLD',
        'greenCreditsEarned': 10,
      });
      expect(p.greenCreditsEarned, 10);
    });

    test('parses a num (double) credits value', () {
      final p = Purchase.fromJson({
        'evaluationId': 'E1',
        'greenCreditsEarned': 12.0,
      });
      expect(p.greenCreditsEarned, 12);
    });

    test('defaults to 0 when field is absent (backward compatible)', () {
      final p = Purchase.fromJson({'evaluationId': 'E2'});
      expect(p.greenCreditsEarned, 0);
    });

    test('defaults to 0 when field is null', () {
      final p = Purchase.fromJson({
        'evaluationId': 'E3',
        'greenCreditsEarned': null,
      });
      expect(p.greenCreditsEarned, 0);
    });
  });

  group('GreenCreditBadge widget', () {
    testWidgets('renders the credit amount when credits > 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: GreenCreditBadge(credits: 15))),
      );
      expect(find.text('+15 credits'), findsOneWidget);
      expect(find.byIcon(Icons.eco), findsOneWidget);
    });

    testWidgets('renders nothing when credits == 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: GreenCreditBadge(credits: 0))),
      );
      expect(find.byIcon(Icons.eco), findsNothing);
      expect(find.textContaining('credits'), findsNothing);
    });

    testWidgets('renders nothing for negative credits', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: GreenCreditBadge(credits: -5))),
      );
      expect(find.byIcon(Icons.eco), findsNothing);
    });
  });
}
