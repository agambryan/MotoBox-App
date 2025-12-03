import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../pages/navbar.dart';
import '../pages/motor_setup_page.dart';

/// Check if user has motors and navigate to appropriate page
/// - If motors exist: Navigate to NavBar (main app)
/// - If no motors: Navigate to MotorSetupPage (onboarding)
/// - On error: Navigate to MotorSetupPage (safe fallback)
Future<void> checkMotorAndNavigate(BuildContext context) async {
  if (!context.mounted) return;

  try {
    final motors = await DatabaseHelper().getMotors().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('getMotors() timeout - assuming no motors');
        return <Map<String, dynamic>>[];
      },
    );

    if (!context.mounted) return;

    _navigateToPage(
      context,
      motors.isEmpty ? const MotorSetupPage() : const NavBar(),
    );
  } catch (e) {
    debugPrint('Error checking motor data: $e');
    if (!context.mounted) return;

    // Safe fallback: navigate to setup page
    _navigateToPage(context, const MotorSetupPage());
  }
}

/// Helper to navigate with proper context handling
void _navigateToPage(BuildContext context, Widget page) {
  if (!context.mounted) return;

  Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (_) => page),
  );
}
