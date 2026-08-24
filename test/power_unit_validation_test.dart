import 'package:flutter_test/flutter_test.dart';

bool isValidVin(String v) {
  final value = v.trim();
  if (value.length != 17) return false;
  return RegExp(r'^[A-Za-z0-9]{17}$').hasMatch(value);
}

bool isValidYear(String v) {
  final value = v.trim();
  return RegExp(r'^\d{4}$').hasMatch(value);
}

bool isPurchaseDateValid(String v) {
  final value = v.trim();
  if (value.isEmpty) return false;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return false;
  final today = DateTime.now();
  final pDay = DateTime(parsed.year, parsed.month, parsed.day);
  final tDay = DateTime(today.year, today.month, today.day);
  return !pDay.isAfter(tDay);
}

DateTime calculateCvipExpiry(DateTime inspectionDate, String province) {
  final p = province.trim().toLowerCase();
  final shortValidity =
      p == 'british columbia' || p == 'bc' || p == 'saskatchewan' || p == 'sk';
  return DateTime(
    inspectionDate.year,
    inspectionDate.month + (shortValidity ? 6 : 12),
    inspectionDate.day,
  );
}

void main() {
  group('Power Unit Form Validation Tests', () {
    test('VIN validation - valid 17-char alphanumeric', () {
      expect(isValidVin('1HGCR2F83HA000000'), isTrue);
      expect(isValidVin('3AKJHHDR5LS000123'), isTrue);
    });

    test('VIN validation - invalid length or special chars', () {
      expect(isValidVin('SHORT123'), isFalse);
      expect(isValidVin('1HGCR2F83HA000000TOO_LONG'), isFalse);
      expect(isValidVin('1HGCR2F83HA0000!@'), isFalse);
    });

    test('Year validation - 4-digit format', () {
      expect(isValidYear('2024'), isTrue);
      expect(isValidYear('1999'), isTrue);
      expect(isValidYear('24'), isFalse);
      expect(isValidYear('20245'), isFalse);
      expect(isValidYear('abcd'), isFalse);
    });

    test('Purchase Date validation - past/today valid, future invalid', () {
      final today = DateTime.now();
      final yesterdayIso =
          today.subtract(const Duration(days: 1)).toIso8601String().split('T').first;
      final tomorrowIso =
          today.add(const Duration(days: 1)).toIso8601String().split('T').first;
      final todayIso = today.toIso8601String().split('T').first;

      expect(isPurchaseDateValid(yesterdayIso), isTrue);
      expect(isPurchaseDateValid(todayIso), isTrue);
      expect(isPurchaseDateValid(tomorrowIso), isFalse);
    });

    test('CVIP Expiry calculation - BC & SK get 6 months, others get 12 months', () {
      final inspDate = DateTime(2025, 1, 15);

      final expiryBc = calculateCvipExpiry(inspDate, 'BC');
      expect(expiryBc, DateTime(2025, 7, 15));

      final expirySk = calculateCvipExpiry(inspDate, 'Saskatchewan');
      expect(expirySk, DateTime(2025, 7, 15));

      final expiryOn = calculateCvipExpiry(inspDate, 'Ontario');
      expect(expiryOn, DateTime(2026, 1, 15));
    });
  });
}
