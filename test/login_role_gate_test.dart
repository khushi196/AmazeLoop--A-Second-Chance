import 'package:flutter_test/flutter_test.dart';
import 'package:amazeloop/views/login_view.dart';

void main() {
  group('roleAllowedForEntry — marketplace (buyer) door', () {
    test('allows a customer account', () {
      expect(roleAllowedForEntry(LoginEntry.buyer, 'customer'), isTrue);
    });
    test('rejects a warehouse (seller) account', () {
      expect(roleAllowedForEntry(LoginEntry.buyer, 'warehouse'), isFalse);
    });
    test('rejects an unknown/null role', () {
      expect(roleAllowedForEntry(LoginEntry.buyer, null), isFalse);
      expect(roleAllowedForEntry(LoginEntry.buyer, 'seller'), isFalse);
    });
  });

  group('roleAllowedForEntry — consumer trade-in door (any seller account)', () {
    test('allows a customer account', () {
      expect(roleAllowedForEntry(LoginEntry.customerSell, 'customer'), isTrue);
    });
    test('allows a warehouse account too', () {
      expect(roleAllowedForEntry(LoginEntry.customerSell, 'warehouse'), isTrue);
    });
    test('rejects an unknown/null role', () {
      expect(roleAllowedForEntry(LoginEntry.customerSell, null), isFalse);
      expect(roleAllowedForEntry(LoginEntry.customerSell, 'seller'), isFalse);
    });
  });

  group('roleAllowedForEntry — warehouse seller door (any seller account)', () {
    test('allows a warehouse account', () {
      expect(roleAllowedForEntry(LoginEntry.warehouseSell, 'warehouse'), isTrue);
    });
    test('allows a customer account too', () {
      expect(roleAllowedForEntry(LoginEntry.warehouseSell, 'customer'), isTrue);
    });
    test('rejects an unknown/null role', () {
      expect(roleAllowedForEntry(LoginEntry.warehouseSell, null), isFalse);
    });
  });

  group('loginEntryMismatchMessage', () {
    test('returns a non-empty message for every entry', () {
      for (final e in LoginEntry.values) {
        expect(loginEntryMismatchMessage(e).trim(), isNotEmpty);
      }
    });
  });
}
