import 'package:flutter_test/flutter_test.dart';
import 'package:amazeloop/data/sustainability.dart';

void main() {
  group('buildSustainabilityImpact', () {
    test('Returned Amazon order — reverse + transport + reuse', () {
      final text = buildSustainabilityImpact(
        sourceReason: 'Returned Amazon order',
        disposition: 'Resell',
        reverseKm: 84,
        transportCo2Kg: 3.24,
        reuseCo2Kg: 55,
        ownersTotal: 3,
      );
      // ignore: avoid_print
      print('A) $text');
      expect(text, contains('about 85 km')); // 84 -> nearest 5
      expect(text, contains('roughly 3.2 kg'));
      expect(text, contains('around 55.0 kg'));
      expect(text, contains('This will be owner 3 for this product.'));
      // NOTE: the provided "Returned Amazon order" template (reverse +
      // transport + reuse + owner) runs ~55 words — longer than the 45-word
      // guideline. The explicit templates take precedence, so we sanity-cap
      // length instead of enforcing the (unachievable here) 45-word limit.
      expect(_wordCount(text) <= 60, isTrue);
    });

    test('Returned Amazon order — only reverse km (no transport), reuse > 0',
        () {
      final text = buildSustainabilityImpact(
        sourceReason: 'Returned Amazon order',
        disposition: 'Refurbish',
        reverseKm: 47,
        transportCo2Kg: 0,
        reuseCo2Kg: 20,
        ownersTotal: 2,
      );
      // ignore: avoid_print
      print('B) $text');
      expect(text, contains('about 47 km')); // < 50 -> nearest 1
      expect(text, isNot(contains('transport CO₂')));
      expect(text, contains('around 20.0 kg'));
      expect(text, contains('owner 2'));
    });

    test('Returned Amazon order — only transport, no reuse', () {
      final text = buildSustainabilityImpact(
        sourceReason: 'Returned Amazon order',
        disposition: 'Resell',
        reverseKm: 0,
        transportCo2Kg: 2.5,
        reuseCo2Kg: 0,
        ownersTotal: 2,
      );
      // ignore: avoid_print
      print('C) $text');
      expect(text, contains('roughly 2.5 kg of transport CO₂'));
      expect(text, contains('This will be owner 2 for this product.'));
      expect(text, isNot(contains('compared with buying new')));
    });

    test('Unused at home — reuse only (transport below threshold)', () {
      final text = buildSustainabilityImpact(
        sourceReason: 'Unused at home',
        disposition: 'Resell',
        reverseKm: 0,
        transportCo2Kg: 0.4, // < 1.0 -> not shown
        reuseCo2Kg: 55,
        ownersTotal: 2,
      );
      // ignore: avoid_print
      print('D) $text');
      expect(text, contains('back into circulation'));
      expect(text, contains('roughly 55.0 kg'));
      expect(text, isNot(contains('transport emissions')));
      expect(text, contains('owner 2'));
    });

    test('Unused at home — never mentions transport, even when significant',
        () {
      final text = buildSustainabilityImpact(
        sourceReason: 'Unused at home',
        disposition: 'Resell',
        reverseKm: 120,
        transportCo2Kg: 4.5,
        reuseCo2Kg: 8,
        ownersTotal: 4,
      );
      // ignore: avoid_print
      print('E) $text');
      expect(text, contains('back into circulation'));
      expect(text, contains('roughly 8.0 kg'));
      expect(text, isNot(contains('transport')));
      expect(text, isNot(contains('km')));
      expect(text, contains('owner 4'));
    });

    test('Edge case — nothing saved (both zero) -> fallback', () {
      final text = buildSustainabilityImpact(
        sourceReason: 'Unused at home',
        disposition: 'Recycle',
        reverseKm: 0,
        transportCo2Kg: 0,
        reuseCo2Kg: 0,
        ownersTotal: 1,
      );
      // ignore: avoid_print
      print('F) $text');
      expect(text, contains('kept in the loop instead of going to waste'));
      expect(text, contains('This will be owner 1 for this product.'));
    });

    test('Edge case — very low transport rounds to 0.0 but reuse present', () {
      final text = buildSustainabilityImpact(
        sourceReason: 'Returned Amazon order',
        disposition: 'Resell',
        reverseKm: 12,
        transportCo2Kg: 0.03, // > 0, rounds to 0.0 in display
        reuseCo2Kg: 25,
        ownersTotal: 2,
      );
      // ignore: avoid_print
      print('G) $text');
      // transport > 0, so first sentence includes both reverse + transport.
      expect(text, contains('about 12 km'));
      expect(text, contains('around 25.0 kg'));
      expect(text, contains('owner 2'));
    });

    test('always hedges numbers and never overclaims precision', () {
      final text = buildSustainabilityImpact(
        sourceReason: 'Returned Amazon order',
        disposition: 'Resell',
        reverseKm: 175,
        transportCo2Kg: 21,
        reuseCo2Kg: 320,
        ownersTotal: 2,
      );
      // ignore: avoid_print
      print('H) $text');
      final hedged = text.contains('about') ||
          text.contains('roughly') ||
          text.contains('around');
      expect(hedged, isTrue);
      expect(text.toLowerCase(), isNot(contains('exact')));
      expect(text.toLowerCase(), isNot(contains('certified')));
    });
  });
}

int _wordCount(String s) => s.trim().split(RegExp(r'\s+')).length;
