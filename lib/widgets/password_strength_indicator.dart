import 'package:flutter/material.dart';
import '../utils/password_validator.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const PasswordStrengthIndicator({
    super.key,
    required this.password,
  });

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) {
      return const SizedBox.shrink();
    }

    final result = PasswordValidator.evaluate(password);

    Color barColor;
    String strengthText;
    Color badgeTextColor;
    Color badgeBgColor;

    switch (result.strength) {
      case PasswordStrength.weak:
        barColor = const Color(0xFFEF4444);
        strengthText = 'Weak';
        badgeTextColor = const Color(0xFFDC2626);
        badgeBgColor = const Color(0xFFFEE2E2);
        break;
      case PasswordStrength.fair:
        barColor = const Color(0xFFF97316);
        strengthText = 'Fair';
        badgeTextColor = const Color(0xFFEA580C);
        badgeBgColor = const Color(0xFFFFEDD5);
        break;
      case PasswordStrength.good:
        barColor = const Color(0xFF3B82F6);
        strengthText = 'Good';
        badgeTextColor = const Color(0xFF2563EB);
        badgeBgColor = const Color(0xFFDBEAFE);
        break;
      case PasswordStrength.strong:
        barColor = const Color(0xFF10B981);
        strengthText = 'Strong';
        badgeTextColor = const Color(0xFF059669);
        badgeBgColor = const Color(0xFFD1FAE5);
        break;
      case PasswordStrength.none:
        barColor = Colors.grey.shade300;
        strengthText = '';
        badgeTextColor = Colors.grey;
        badgeBgColor = Colors.grey.shade100;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Strength label & progress bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Password Strength',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  strengthText,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 4-segment visual bar
          Row(
            children: List.generate(4, (index) {
              final active = (index + 1) <= (result.score > 4 ? 4 : (result.score <= 1 ? 1 : result.score - 1));
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: active ? barColor : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),

          // Detailed Criteria Checklist
          _buildRequirementItem('At least 8 characters', result.hasMinLength),
          const SizedBox(height: 4),
          _buildRequirementItem('At least one uppercase letter (A-Z)', result.hasUppercase),
          const SizedBox(height: 4),
          _buildRequirementItem('At least one lowercase letter (a-z)', result.hasLowercase),
          const SizedBox(height: 4),
          _buildRequirementItem('At least one number (0-9)', result.hasDigit),
          const SizedBox(height: 4),
          _buildRequirementItem('At least one special character (!@#\$...)', result.hasSpecialChar),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String text, bool isMet) {
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 15,
          color: isMet ? const Color(0xFF10B981) : Colors.grey.shade400,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: isMet ? FontWeight.w500 : FontWeight.normal,
              color: isMet ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
            ),
          ),
        ),
      ],
    );
  }
}
