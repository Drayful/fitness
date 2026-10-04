import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../api/api_client.dart';
import '../../api/session_controller.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';

/// Login / registration screen shown by the AuthGate when there is no session.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _register = false;
  bool _busy = false;
  String? _error;
  Map<String, List<String>>? _fieldErrors;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _error = null;
      _fieldErrors = null;
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    final session = SessionScope.of(context);
    try {
      if (_register) {
        await session.register(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
        );
      } else {
        await session.login(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
      // On success the AuthGate rebuilds and swaps in the app shell.
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _fieldErrors = e.fieldErrors;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = l.t('auth_error_generic'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _fieldError(String field) {
    final list = _fieldErrors?[field];
    return (list != null && list.isNotEmpty) ? list.first : null;
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild on light/dark switches: AppTheme getters are not inherited.
    AppTheme.watch(context);
    final l = AppLocalizations.of(context);
    final c = context.appColors;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [c.accent, c.accent2],
                        ),
                      ),
                      child: Icon(Icons.bolt,
                          color: AppTheme.onAccent, size: 34),
                    ),
                    SizedBox(height: 20),
                    Text(
                      _register
                          ? l.t('auth_register_title')
                          : l.t('auth_login_title'),
                      style: GoogleFonts.manrope(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.text,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      l.t('auth_welcome'),
                      style: TextStyle(color: c.subtext, fontSize: 14),
                    ),
                    SizedBox(height: 28),
                    if (_register) ...[
                      _field(
                        controller: _name,
                        label: l.t('auth_name'),
                        icon: Icons.person_outline,
                        keyboardType: TextInputType.name,
                        serverError: _fieldError('name'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? l.t('auth_field_required')
                            : null,
                      ),
                      SizedBox(height: 14),
                    ],
                    _field(
                      controller: _email,
                      label: l.t('auth_email'),
                      icon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      serverError: _fieldError('email'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return l.t('auth_field_required');
                        }
                        if (!v.contains('@') || !v.contains('.')) {
                          return l.t('auth_email_invalid');
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 14),
                    _field(
                      controller: _password,
                      label: l.t('auth_password'),
                      icon: Icons.lock_outline,
                      obscure: true,
                      serverError: _fieldError('password'),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return l.t('auth_field_required');
                        }
                        if (_register && v.length < 8) {
                          return l.t('auth_password_short');
                        }
                        return null;
                      },
                    ),
                    if (_error != null) ...[
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: c.danger.withValues(alpha: 0.12),
                          border: Border.all(
                              color: c.danger.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: c.danger, size: 18),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(_error!,
                                  style: TextStyle(
                                      color: c.danger, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: c.accent,
                        disabledBackgroundColor:
                            c.accent.withValues(alpha: 0.4),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _busy
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation(
                                    AppTheme.onAccent),
                              ),
                            )
                          : Text(
                              _register
                                  ? l.t('auth_register_btn')
                                  : l.t('auth_login_btn'),
                              style: TextStyle(
                                  color: AppTheme.onAccent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16),
                            ),
                    ),
                    SizedBox(height: 16),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _register = !_register;
                                _error = null;
                                _fieldErrors = null;
                              }),
                      child: Text(
                        _register ? l.t('auth_to_login') : l.t('auth_to_register'),
                        style: TextStyle(
                            color: c.accent2, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String? serverError,
  }) {
    final c = context.appColors;
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: TextStyle(color: AppTheme.text),
      cursorColor: c.accent,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: c.subtext),
        errorText: serverError,
        prefixIcon: Icon(icon, color: c.subtext, size: 20),
        filled: true,
        fillColor: AppTheme.surface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.danger, width: 1.5),
        ),
      ),
      validator: validator,
    );
  }
}
