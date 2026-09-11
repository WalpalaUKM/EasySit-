import 'package:flutter/material.dart';
import '../utils/password_validator.dart';
import '../utils/app_colors.dart';

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
        barColor = EasySitColors.errorFg;
        strengthText = 'Weak';
        badgeTextColor = EasySitColors.errorFg;
        badgeBgColor = EasySitColors.errorBg;
        break;
      case PasswordStrength.fair:
        barColor = EasySitColors.warningFg;
        strengthText = 'Fair';
        badgeTextColor = EasySitColors.warningFg;
        badgeBgColor = EasySitColors.warningBg;
        break;
      case PasswordStrength.good:
        barColor = EasySitColors.primary;
        strengthText = 'Good';
        badgeTextColor = EasySitColors.primary;
        badgeBgColor = EasySitColors.primaryTint;
        break;
      case PasswordStrength.strong:
        barColor = EasySitColors.successFg;
        strengthText = 'Strong';
        badgeTextColor = EasySitColors.successFg;
        badgeBgColor = EasySitColors.successBg;
        break;
      case PasswordStrength.none:
        barColor = EasySitColors.divider;
        strengthText = '';
        badgeTextColor = EasySitColors.disabledText;
        badgeBgColor = EasySitColors.disabledFill;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EasySitColors.subtleSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EasySitColors.divider),
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
                  color: EasySitColors.bodyText,
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
              final active = (index + 1) <=
                  (result.score > 4
                      ? 4
                      : (result.score <= 1 ? 1 : result.score - 1));
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: active ? barColor : EasySitColors.divider,
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
          _buildRequirementItem(
              'At least one uppercase letter (A-Z)', result.hasUppercase),
          const SizedBox(height: 4),
          _buildRequirementItem(
              'At least one lowercase letter (a-z)', result.hasLowercase),
          const SizedBox(height: 4),
          _buildRequirementItem('At least one number (0-9)', result.hasDigit),
          const SizedBox(height: 4),
          _buildRequirementItem(
              'At least one special character (!@#\$...)', result.hasSpecialChar),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String text, bool isMet) {
    return Row(
      children: [
        Icon(
          isMet
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 15,
          color: isMet ? EasySitColors.successFg : EasySitColors.secondaryText,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: isMet ? FontWeight.w500 : FontWeight.normal,
              color: isMet ? EasySitColors.mainText : EasySitColors.secondaryText,
            ),
          ),
        ),
      ],
    );
  }
}
