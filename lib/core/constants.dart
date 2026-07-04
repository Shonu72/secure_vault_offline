import 'package:flutter/material.dart';

class AppConstants {
  // String Constants
  static const String appTitle = 'Secure Vault';
  static const String lockScreenTitle = 'Enter Secure PIN';
  static const String lockScreenSubtitle = 'Verify identity to access vault';
  static const String portfolioTitle = 'Portfolio';
  static const String addAssetTitle = 'Add Asset';
  
  // Simulated PIN values
  static const String defaultPinSeed = '1234';

  // Responsive padding & margins
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double cardBorderRadius = 16.0;
  static const double inputBorderRadius = 12.0;
}

// Extension for simple media query values (Responsiveness helper)
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  
  bool get isTablet => screenWidth >= 600;
  bool get isDesktop => screenWidth >= 1024;
  
  // Custom responsive padding based on screen size
  EdgeInsets get responsivePadding {
    if (isDesktop) {
      return const EdgeInsets.symmetric(horizontal: 120.0, vertical: 32.0);
    } else if (isTablet) {
      return const EdgeInsets.symmetric(horizontal: 60.0, vertical: 24.0);
    } else {
      return const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0);
    }
  }
}
