import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../api/session_controller.dart';
import '../../band/body_profile.dart';
import '../../main.dart';
import '../l10n/app_localizations.dart';
import '../l10n/locale_controller.dart';
import '../theme.dart';
import '../theme_controller.dart';
import 'band_connect_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _openBandScreen(BuildContext context) {
    final service = BandServiceScope.of(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BandConnectScreen(service: service),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final c = context.appColors;
    final session = SessionScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l.t('logout_confirm'),
          style: TextStyle(
            color: AppTheme.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          l.t('logout_confirm_sub'),
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.t('cancel'), style: TextStyle(color: c.subtext)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l.t('profile_logout'),
              style: TextStyle(color: c.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final band = BandServiceScope.of(context);
      await band.forgetDevice();
      band.workoutHistory.clear();
      await session.logout();
      // AuthGate rebuilds and shows the login screen automatically.
    }
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts[1].characters.first)
        .toUpperCase();
  }

  static String _themeLabel(AppLocalizations l, ThemeMode mode) =>
      switch (mode) {
        ThemeMode.system => l.t('theme_system'),
        ThemeMode.light => l.t('theme_light'),
        ThemeMode.dark => l.t('theme_dark'),
      };

  /// Light / dark / system, as on the design's Onb-03-Theme screen.
  void _chooseTheme(BuildContext context) {
    final l = AppLocalizations.of(context);
    final controller = ThemeScope.of(context);
    final current = controller.mode;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        final c = sheetCtx.appColors;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, 14, 8, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Text(
                    l.t('choose_theme'),
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                for (final (mode, icon) in const [
                  (ThemeMode.system, Icons.brightness_auto_outlined),
                  (ThemeMode.light, Icons.light_mode_outlined),
                  (ThemeMode.dark, Icons.dark_mode_outlined),
                ])
                  ListTile(
                    leading: Icon(
                      icon,
                      color: mode == current ? c.accent : c.subtext,
                    ),
                    title: Text(
                      _themeLabel(l, mode),
                      style: TextStyle(
                        fontWeight: mode == current
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: mode == current ? c.accent : AppTheme.text,
                      ),
                    ),
                    trailing: mode == current
                        ? Icon(Icons.check, color: c.accent)
                        : null,
                    onTap: () {
                      controller.setMode(mode);
                      Navigator.of(sheetCtx).pop();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _chooseLanguage(BuildContext context) {
    final l = AppLocalizations.of(context);
    final controller = LocaleScope.of(context);
    final current = controller.locale.languageCode;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        final c = sheetCtx.appColors;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, 14, 8, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Text(
                    l.t('choose_language'),
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ...AppLocalizations.supportedLocales.map((loc) {
                  final code = loc.languageCode;
                  final selected = code == current;
                  return ListTile(
                    title: Text(
                      AppLocalizations.localeNames[code] ?? code,
                      style: TextStyle(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected ? c.accent : AppTheme.text,
                      ),
                    ),
                    trailing: selected
                        ? Icon(Icons.check, color: c.accent)
                        : null,
                    onTap: () {
                      controller.setLocale(loc);
                      Navigator.of(sheetCtx).pop();
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild on light/dark switches: AppTheme getters are not inherited.
    AppTheme.watch(context);
    final l = AppLocalizations.of(context);
    final c = context.appColors;
    final band = BandServiceScope.of(context);
    final session = SessionScope.of(context);

    return ListenableBuilder(
      listenable: band,
      builder: (context, _) {
        final connected = band.isConnected;
        final battery = band.deviceInfo?.batteryPercent;
        final firmware = band.deviceInfo?.firmware;

        return ListView(
          padding: EdgeInsets.fromLTRB(18, 14, 18, 24),
          children: [
            Text(
              l.t('profile'),
              style: GoogleFonts.manrope(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppTheme.text,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 16),

            // Profile card
            _card(
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [c.accent, c.accent2],
                      ),
                    ),
                    child: Text(
                      _initials(session.userName),
                      style: GoogleFonts.manrope(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onAccent,
                      ),
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.userName ?? 'User',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.text,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          session.userEmail ?? '—',
                          style: TextStyle(color: c.subtext, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 14),

            // V8 band card
            Container(
              padding: EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppTheme.outline),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.surface, AppTheme.surface],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: c.accent.withValues(alpha: 0.12),
                        ),
                        child: Icon(Icons.watch_outlined, color: c.accent),
                      ),
                      SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              band.deviceInfo?.name ?? l.t('bracelet'),
                              style: TextStyle(
                                color: AppTheme.text,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: connected ? c.accent : c.subtext,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    connected
                                        ? l.t('connected')
                                        : l.t('not_connected'),
                                    style: TextStyle(
                                      color: connected ? c.accent : c.subtext,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => _openBandScreen(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: c.accent,
                          side: BorderSide(
                            color: c.accent.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(connected ? l.t('manage') : l.t('connect')),
                      ),
                    ],
                  ),
                  SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: _bandStat(
                          c,
                          l.t('battery'),
                          battery != null ? '$battery%' : '—',
                          c.accent,
                        ),
                      ),
                      SizedBox(width: 11),
                      Expanded(
                        child: _bandStat(
                          c,
                          l.t('firmware'),
                          firmware ?? '—',
                          AppTheme.text,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 14),

            // Settings list
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: AppTheme.surface,
                border: Border.all(color: AppTheme.outline),
              ),
              child: Column(
                children: [
                  _settingRow(
                    c,
                    Icons.watch_outlined,
                    c.sleep,
                    l.t('bracelet'),
                    l.t('bracelet_sub'),
                    onTap: () => _openBandScreen(context),
                  ),
                  _divider(),
                  _settingRow(
                    c,
                    Icons.accessibility_new,
                    c.accent2,
                    l.t('body_profile'),
                    session.bodyProfile.isComplete
                        ? l.t('body_profile_sub_done')
                        : l.t('body_profile_sub'),
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: AppTheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      builder: (_) => _BodyProfileSheet(session: session),
                    ),
                  ),
                  _divider(),
                  _settingRow(
                    c,
                    Icons.lock_outline,
                    c.warn,
                    l.t('privacy'),
                    l.t('privacy_sub'),
                  ),
                  _divider(),
                  _settingRow(
                    c,
                    Icons.cloud_outlined,
                    c.accent2,
                    l.t('api'),
                    l.t('api_sub'),
                  ),
                  _divider(),
                  _settingRow(
                    c,
                    Icons.language,
                    c.accent,
                    l.t('language'),
                    l.t('language_sub'),
                    trailingText:
                        AppLocalizations.localeNames[LocaleScope.of(
                          context,
                        ).locale.languageCode] ??
                        '',
                    onTap: () => _chooseLanguage(context),
                  ),
                  _divider(),
                  _settingRow(
                    c,
                    Icons.contrast,
                    c.accent,
                    l.t('theme'),
                    l.t('theme_sub'),
                    trailingText: _themeLabel(
                      l,
                      ThemeScope.of(context).mode,
                    ),
                    onTap: () => _chooseTheme(context),
                  ),
                ],
              ),
            ),
            SizedBox(height: 22),

            // Account section
            Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                l.t('account'),
                style: TextStyle(
                  color: c.subtext,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: AppTheme.surface,
                border: Border.all(color: AppTheme.outline),
              ),
              child: _settingRow(
                c,
                Icons.logout,
                c.danger,
                l.t('profile_logout'),
                session.userEmail ?? '',
                onTap: () => _logout(context),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _card({required Widget child}) => Container(
    padding: EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      color: AppTheme.surface,
      border: Border.all(color: AppTheme.outline),
    ),
    child: child,
  );

  Widget _divider() => Padding(
    padding: EdgeInsets.symmetric(horizontal: 16),
    child: Divider(height: 1, color: AppTheme.outline),
  );

  Widget _bandStat(AppColors c, String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppTheme.surfaceAlt,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: c.subtext,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingRow(
    AppColors c,
    IconData icon,
    Color iconColor,
    String title,
    String subtitle, {
    String? trailingText,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                color: AppTheme.outline,
              ),
              child: Icon(icon, color: iconColor, size: 19),
            ),
            SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(color: c.subtext, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            if (trailingText != null && trailingText.isNotEmpty) ...[
              Text(
                trailingText,
                style: TextStyle(
                  color: c.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 7),
            ],
            if (onTap != null)
              Icon(Icons.chevron_right, color: c.subtext, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Body data for the band's calorie/distance estimates and heart-rate zones.
class _BodyProfileSheet extends StatefulWidget {
  const _BodyProfileSheet({required this.session});

  final SessionController session;

  @override
  State<_BodyProfileSheet> createState() => _BodyProfileSheetState();
}

class _BodyProfileSheetState extends State<_BodyProfileSheet> {
  late String? _sex = widget.session.bodyProfile.sex;
  late DateTime? _birthDate = widget.session.bodyProfile.birthDate;
  late final _height = TextEditingController(
    text: widget.session.bodyProfile.heightCm?.toString() ?? '',
  );
  late final _weight = TextEditingController(
    text: widget.session.bodyProfile.weightKg?.toString() ?? '',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 14, 1, 1),
      firstDate: DateTime(1920),
      lastDate: now.subtract(Duration(days: 1)),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final height = int.tryParse(_height.text.trim());
    final weight = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
    if ((_height.text.trim().isNotEmpty &&
            (height == null || height < 80 || height > 250)) ||
        (_weight.text.trim().isNotEmpty &&
            (weight == null || weight < 20 || weight > 250))) {
      setState(() => _error = l.t('body_profile_invalid'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.session.updateBodyProfile(
        BodyProfile(
          sex: _sex,
          birthDate: _birthDate,
          heightCm: height,
          weightKg: weight,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = l.t('body_profile_failed');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final loc = MaterialLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.t('body_profile'), style: AppTheme.numeric(fontSize: 18)),
          SizedBox(height: 4),
          Text(
            l.t('body_profile_why'),
            style: TextStyle(fontSize: 13, color: AppTheme.subtext),
          ),
          SizedBox(height: 16),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'female', label: Text(l.t('sex_female'))),
              ButtonSegment(value: 'male', label: Text(l.t('sex_male'))),
            ],
            selected: {?_sex},
            emptySelectionAllowed: true,
            onSelectionChanged: (s) =>
                setState(() => _sex = s.isEmpty ? null : s.first),
          ),
          SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickBirthDate,
            icon: Icon(Icons.cake_outlined),
            label: Text(
              _birthDate == null
                  ? l.t('birth_date')
                  : '${l.t('birth_date')}: ${loc.formatMediumDate(_birthDate!)}',
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _height,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l.t('height_cm'),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _weight,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l.t('weight_kg'),
                  ),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: AppTheme.danger)),
          ],
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l.t('save')),
            ),
          ),
        ],
      ),
    );
  }
}
