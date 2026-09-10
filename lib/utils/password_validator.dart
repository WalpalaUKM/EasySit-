enum PasswordStrength {
  none,
  weak,
  fair,
  good,
  strong,
}

class PasswordValidationResult {
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasDigit;
  final bool hasSpecialChar;
  final int score;
  final PasswordStrength strength;

  const PasswordValidationResult({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasDigit,
    required this.hasSpecialChar,
    required this.score,
    required this.strength,
  });

  bool get isStrong => score == 5;
}

class PasswordValidator {
  static const int minLength = 8;
  static final RegExp _uppercaseRegExp = RegExp(r'[A-Z]');
  static final RegExp _lowercaseRegExp = RegExp(r'[a-z]');
  static final RegExp _digitRegExp = RegExp(r'[0-9]');
  static final RegExp _specialCharRegExp = RegExp(r'[!@#$%^&*(),.?":{}|<>_\-\+=~/\\\[\]]');

  static bool hasMinLength(String password) => password.length >= minLength;
  static bool hasUppercase(String password) => _uppercaseRegExp.hasMatch(password);
  static bool hasLowercase(String password) => _lowercaseRegExp.hasMatch(password);
  static bool hasDigit(String password) => _digitRegExp.hasMatch(password);
  static bool hasSpecialChar(String password) => _specialCharRegExp.hasMatch(password);

  static PasswordValidationResult evaluate(String password) {
    if (password.isEmpty) {
      return const PasswordValidationResult(
        hasMinLength: false,
        hasUppercase: false,
        hasLowercase: false,
        hasDigit: false,
        hasSpecialChar: false,
        score: 0,
        strength: PasswordStrength.none,
      );
    }

    final len = hasMinLength(password);
    final upper = hasUppercase(password);
    final lower = hasLowercase(password);
    final digit = hasDigit(password);
    final special = hasSpecialChar(password);

    int score = 0;
    if (len) score++;
    if (upper) score++;
    if (lower) score++;
    if (digit) score++;
    if (special) score++;

    PasswordStrength strength;
    if (score <= 2) {
      strength = PasswordStrength.weak;
    } else if (score == 3) {
      strength = PasswordStrength.fair;
    } else if (score == 4) {
      strength = PasswordStrength.good;
    } else {
      strength = PasswordStrength.strong;
    }

    return PasswordValidationResult(
      hasMinLength: len,
      hasUppercase: upper,
      hasLowercase: lower,
      hasDigit: digit,
      hasSpecialChar: special,
      score: score,
      strength: strength,
    );
  }

  /// Returns error message if password does not satisfy strong password policy, or null if valid.
  static String? getErrorMessage(String password) {
    if (password.isEmpty) {
      return 'Please enter a password';
    }
    if (!hasMinLength(password)) {
      return 'Password must be at least $minLength characters long';
    }
    if (!hasUppercase(password)) {
      return 'Password must include at least one uppercase letter (A-Z)';
    }
    if (!hasLowercase(password)) {
      return 'Password must include at least one lowercase letter (a-z)';
    }
    if (!hasDigit(password)) {
      return 'Password must include at least one number (0-9)';
    }
    if (!hasSpecialChar(password)) {
      return 'Password must include at least one special character (e.g. !@#\$)';
    }
    return null;
  }
}
