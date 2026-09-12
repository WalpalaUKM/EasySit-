import 'package:flutter_test/flutter_test.dart';

void main() {
  group('University Email Format Validation Tests', () {
    // University email format: name-ct23001@stu.kln.ac.lk
    // - name: student username/name
    // - department: ct, cs, or et
    // - academic year: 2 digits (e.g. 23 for 2023)
    // - registered number: 3 digits (e.g. 001)
    // - domain: @stu.kln.ac.lk
    final uniEmailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+-(ct|cs|et)\d{2}\d{3}@stu\.kln\.ac\.lk$',
      caseSensitive: false,
    );

    test('Valid university email with CT department and 23 year passes', () {
      expect(uniEmailRegex.hasMatch('name-ct23001@stu.kln.ac.lk'), isTrue);
      expect(uniEmailRegex.hasMatch('tharusha-ct23001@stu.kln.ac.lk'), isTrue);
      expect(uniEmailRegex.hasMatch('NAME-CT23001@STU.KLN.AC.LK'), isTrue);
    });

    test('Valid university email with CS and ET departments passes', () {
      expect(uniEmailRegex.hasMatch('kasun-cs22045@stu.kln.ac.lk'), isTrue);
      expect(uniEmailRegex.hasMatch('john.doe-et24100@stu.kln.ac.lk'), isTrue);
      expect(uniEmailRegex.hasMatch('user_01-et21002@stu.kln.ac.lk'), isTrue);
    });

    test('Invalid departments (not ct, cs, or et) fail', () {
      expect(uniEmailRegex.hasMatch('name-me23001@stu.kln.ac.lk'), isFalse);
      expect(uniEmailRegex.hasMatch('name-ee23001@stu.kln.ac.lk'), isFalse);
      expect(uniEmailRegex.hasMatch('name-it23001@stu.kln.ac.lk'), isFalse);
      expect(uniEmailRegex.hasMatch('name-se23001@stu.kln.ac.lk'), isFalse);
    });

    test('Invalid academic year (not 2 digits) fails', () {
      // 4-digit year fails (must be 23, not 2023)
      expect(uniEmailRegex.hasMatch('name-ct2023001@stu.kln.ac.lk'), isFalse);
      // 1-digit year fails
      expect(uniEmailRegex.hasMatch('name-ct3001@stu.kln.ac.lk'), isFalse);
    });

    test('Invalid student registered number (not 3 digits) fails', () {
      // 2 digits fails (must be 001, not 01)
      expect(uniEmailRegex.hasMatch('name-ct2301@stu.kln.ac.lk'), isFalse);
      // 4 digits fails
      expect(uniEmailRegex.hasMatch('name-ct230001@stu.kln.ac.lk'), isFalse);
    });

    test('Non-university domain fails', () {
      expect(uniEmailRegex.hasMatch('name-ct23001@gmail.com'), isFalse);
      expect(uniEmailRegex.hasMatch('name-ct23001@kln.ac.lk'), isFalse);
      expect(uniEmailRegex.hasMatch('name-ct23001@yahoo.com'), isFalse);
    });

    test('Extraction of student ID from university email prefix', () {
      final prefix = 'name-ct23001';
      final match = RegExp(r'-(ct|cs|et)(\d{2}\d{3})$', caseSensitive: false).firstMatch(prefix);
      expect(match, isNotNull);
      final studentId = '${match!.group(1)!.toUpperCase()}${match.group(2)}';
      expect(studentId, equals('CT23001'));
    });
  });

  group('Sri Lankan Phone Number Validation Tests', () {
    bool isValidSriLankanPhone(String phone) {
      final clean = phone.trim();
      if (clean.length != 10) return false;
      final slMobileRegex = RegExp(r'^07[01245678]\d{7}$');
      final slGeneralRegex = RegExp(r'^0[1-9]\d{8}$');
      return slMobileRegex.hasMatch(clean) || slGeneralRegex.hasMatch(clean);
    }

    test('Valid Sri Lankan 10-digit mobile operators pass', () {
      expect(isValidSriLankanPhone('0712345678'), isTrue); // Mobitel
      expect(isValidSriLankanPhone('0701234567'), isTrue); // Mobitel
      expect(isValidSriLankanPhone('0721234567'), isTrue); // Hutch
      expect(isValidSriLankanPhone('0741234567'), isTrue); // Dialog
      expect(isValidSriLankanPhone('0751234567'), isTrue); // Airtel
      expect(isValidSriLankanPhone('0761234567'), isTrue); // Dialog
      expect(isValidSriLankanPhone('0771234567'), isTrue); // Dialog
      expect(isValidSriLankanPhone('0781234567'), isTrue); // Hutch
    });

    test('Valid Sri Lankan landlines pass', () {
      expect(isValidSriLankanPhone('0112345678'), isTrue); // Colombo
      expect(isValidSriLankanPhone('0812345678'), isTrue); // Kandy
      expect(isValidSriLankanPhone('0332345678'), isTrue); // Gampaha
    });

    test('Phone numbers with incorrect length fail', () {
      expect(isValidSriLankanPhone('071234567'), isFalse); // 9 digits
      expect(isValidSriLankanPhone('07123456789'), isFalse); // 11 digits
      expect(isValidSriLankanPhone(''), isFalse); // empty
    });

    test('Phone numbers not starting with 0 fail', () {
      expect(isValidSriLankanPhone('9471234567'), isFalse);
      expect(isValidSriLankanPhone('+947123456'), isFalse);
    });

    test('Phone numbers containing letters fail', () {
      expect(isValidSriLankanPhone('071234567a'), isFalse);
      expect(isValidSriLankanPhone('071234text'), isFalse);
    });
  });
}
