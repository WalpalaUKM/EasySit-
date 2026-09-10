import 'package:flutter_test/flutter_test.dart';
import 'package:easy_sit1212/utils/password_validator.dart';

void main() {
  group('PasswordValidator Tests', () {
    test('Empty password returns none strength and error', () {
      final result = PasswordValidator.evaluate('');
      expect(result.score, equals(0));
      expect(result.strength, equals(PasswordStrength.none));
      expect(result.isStrong, isFalse);
      expect(PasswordValidator.getErrorMessage(''), equals('Please enter a password'));
    });

    test('Short password fails minimum length check', () {
      final result = PasswordValidator.evaluate('Ab1!');
      expect(result.hasMinLength, isFalse);
      expect(result.hasUppercase, isTrue);
      expect(result.hasLowercase, isTrue);
      expect(result.hasDigit, isTrue);
      expect(result.hasSpecialChar, isTrue);
      expect(result.isStrong, isFalse);
      expect(
        PasswordValidator.getErrorMessage('Ab1!'),
        equals('Password must be at least 8 characters long'),
      );
    });

    test('Password missing uppercase fails', () {
      expect(PasswordValidator.hasUppercase('secure123!'), isFalse);
      expect(
        PasswordValidator.getErrorMessage('secure123!'),
        equals('Password must include at least one uppercase letter (A-Z)'),
      );
    });

    test('Password missing lowercase fails', () {
      expect(PasswordValidator.hasLowercase('SECURE123!'), isFalse);
      expect(
        PasswordValidator.getErrorMessage('SECURE123!'),
        equals('Password must include at least one lowercase letter (a-z)'),
      );
    });

    test('Password missing digit fails', () {
      expect(PasswordValidator.hasDigit('SecurePass!'), isFalse);
      expect(
        PasswordValidator.getErrorMessage('SecurePass!'),
        equals('Password must include at least one number (0-9)'),
      );
    });

    test('Password missing special character fails', () {
      expect(PasswordValidator.hasSpecialChar('SecurePass123'), isFalse);
      expect(
        PasswordValidator.getErrorMessage('SecurePass123'),
        equals('Password must include at least one special character (e.g. !@#\$)'),
      );
    });

    test('Strong password passes all criteria', () {
      final result = PasswordValidator.evaluate('EasySit@2026');
      expect(result.hasMinLength, isTrue);
      expect(result.hasUppercase, isTrue);
      expect(result.hasLowercase, isTrue);
      expect(result.hasDigit, isTrue);
      expect(result.hasSpecialChar, isTrue);
      expect(result.score, equals(5));
      expect(result.strength, equals(PasswordStrength.strong));
      expect(result.isStrong, isTrue);
      expect(PasswordValidator.getErrorMessage('EasySit@2026'), isNull);
    });

    test('Score mapping for weak, fair, good, strong', () {
      // 2 criteria (length + lowercase) -> weak
      expect(PasswordValidator.evaluate('abcdefgh').strength, equals(PasswordStrength.weak));
      // 3 criteria (length + lower + upper) -> fair
      expect(PasswordValidator.evaluate('Abcdefgh').strength, equals(PasswordStrength.fair));
      // 4 criteria (length + lower + upper + digit) -> good
      expect(PasswordValidator.evaluate('Abcdefg1').strength, equals(PasswordStrength.good));
      // 5 criteria (length + lower + upper + digit + special) -> strong
      expect(PasswordValidator.evaluate('Abcdef1!').strength, equals(PasswordStrength.strong));
    });
  });
}
