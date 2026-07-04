import 'package:flutter/material.dart';
import 'package:secure_vault_offline/core/theme.dart';
import 'package:secure_vault_offline/core/constants.dart';

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final bool isLoading;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.primary,
          foregroundColor: textColor ?? AppColors.background,
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.background,
                ),
              )
            : Text(text),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: backgroundColor ?? AppColors.cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
        side: const BorderSide(color: AppColors.borderNormal, width: 1.0),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppConstants.paddingMedium),
        child: child,
      ),
    );
  }
}
