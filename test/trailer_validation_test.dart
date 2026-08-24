import 'package:flutter_test/flutter_test.dart';

bool isValidTrailerVin(String v) {
  final value = v.trim();
  if (value.length != 17) return false;
  return RegExp(r'^[A-Za-z0-9]{17}$').hasMatch(value);
}

bool isValidTrailerYear(String v) {
  final year = int.tryParse(v.trim());
  if (year == null) return false;
  return year >= 1900 && year <= 2099;
}

bool isRegistrationAlphanumeric(String v) {
  final value = v.trim();
  if (value.isEmpty) return true;
  return RegExp(r'^[A-Za-z0-9]*$').hasMatch(value);
}

void main() {
  group('Trailer Validation Tests', () {
    test('Trailer VIN validation - 17 alphanumeric chars', () {
      expect(isValidTrailerVin('1TR1234567890ABCD'), isTrue);
      expect(isValidTrailerVin('SHORT'), isFalse);
    });

    test('Trailer Year validation - range 1900 to 2099', () {
      expect(isValidTrailerYear('2022'), isTrue);
      expect(isValidTrailerYear('1899'), isFalse);
      expect(isValidTrailerYear('2100'), isFalse);
    });

    test('Registration Number - alphanumeric format', () {
      expect(isRegistrationAlphanumeric('REG12345'), isTrue);
      expect(isRegistrationAlphanumeric('REG-12345!'), isFalse);
    });
  });
}
