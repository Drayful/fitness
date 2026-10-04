import 'package:flutter/material.dart';

import 'theme.dart';

import '../api/session_controller.dart';
import 'root_shell.dart';
import 'screens/login_screen.dart';

/// Decides what the user sees based on auth state:
/// - while the persisted token is loading → a splash spinner,
/// - no session → [LoginScreen],
/// - authenticated → the main [RootShell].
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuild on light/dark switches: AppTheme getters are not inherited.
    AppTheme.watch(context);
    final session = SessionScope.of(context);

    if (session.bootstrapping) {
      return Scaffold(
        backgroundColor: AppTheme.bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return session.isAuthenticated ? RootShell() : LoginScreen();
  }
}
