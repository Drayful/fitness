import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../main.dart';
import '../l10n/app_localizations.dart';
import '../l10n/locale_controller.dart';
import '../theme.dart';
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

  void _chooseLanguage(BuildContext context) {
    final l = AppLocalizations.of(context);
    final controller = LocaleScope.of(context);
    final current = controller.locale.languageCode;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101924),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        final c = sheetCtx.appColors;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Text(l.t('choose_language'),
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                ...AppLocalizations.supportedLocales.map((loc) {
                  final code = loc.languageCode;
                  final selected = code == current;
                  return ListTile(
                    title: Text(AppLocalizations.localeNames[code] ?? code,
                        style: TextStyle(
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected
                                ? c.accent
                                : const Color(0xFFEEF3FB))),
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
    final l = AppLocalizations.of(context);
    final c = context.appColors;
    final band = BandServiceScope.of(context);

    return ListenableBuilder(
      listenable: band,
      builder: (context, _) {
        final connected = band.isConnected;
        final battery = band.deviceInfo?.batteryPercent;
        final firmware = band.deviceInfo?.firmware;

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          children: [
            Text(l.t('profile'),
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFF2F6FF),
                    letterSpacing: -0.5)),
            const SizedBox(height: 16),

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
                    child: Text('AC',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF06120C))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Alex Carter',
                            style: GoogleFonts.spaceGrotesk(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFF2F6FF))),
                        const SizedBox(height: 2),
                        Text(l.t('member_since'),
                            style: TextStyle(color: c.subtext, fontSize: 13)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: c.subtext),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // V8 band card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFF1F2C3D)),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF13202C), Color(0xFF0E1822)],
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
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('V8 Band',
                                style: TextStyle(
                                    color: Color(0xFFEEF3FB),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 3),
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
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    connected
                                        ? l.t('connected')
                                        : l.t('not_connected'),
                                    style: TextStyle(
                                        color: connected ? c.accent : c.subtext,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
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
                          side: BorderSide(color: c.accent.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(connected ? l.t('manage') : l.t('connect')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: _bandStat(c, l.t('battery'),
                            battery != null ? '$battery%' : '—', c.accent),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: _bandStat(c, l.t('firmware'),
                            firmware ?? '—', const Color(0xFFEEF3FB)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Settings list
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: const Color(0xFF101924),
                border: Border.all(color: const Color(0xFF1C2838)),
              ),
              child: Column(
                children: [
                  _settingRow(c, Icons.watch_outlined, c.sleep, l.t('bracelet'),
                      l.t('bracelet_sub'), onTap: () => _openBandScreen(context)),
                  _divider(),
                  _settingRow(c, Icons.lock_outline, c.warn, l.t('privacy'),
                      l.t('privacy_sub')),
                  _divider(),
                  _settingRow(c, Icons.cloud_outlined, c.accent2, l.t('api'),
                      l.t('api_sub')),
                  _divider(),
                  _settingRow(
                    c,
                    Icons.language,
                    c.accent,
                    l.t('language'),
                    l.t('language_sub'),
                    trailingText: AppLocalizations
                            .localeNames[LocaleScope.of(context).locale.languageCode] ??
                        '',
                    onTap: () => _chooseLanguage(context),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: const Color(0xFF101924),
          border: Border.all(color: const Color(0xFF1C2838)),
        ),
        child: child,
      );

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Divider(height: 1, color: Color(0xFF1C2838)),
      );

  Widget _bandStat(AppColors c, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF0C141D),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: c.subtext, fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 18, fontWeight: FontWeight.w700, color: color)),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                color: const Color(0xFF162130),
              ),
              child: Icon(icon, color: iconColor, size: 19),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Color(0xFFEEF3FB),
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 1),
                  Text(subtitle,
                      style: TextStyle(color: c.subtext, fontSize: 11.5)),
                ],
              ),
            ),
            if (trailingText != null && trailingText.isNotEmpty) ...[
              Text(trailingText,
                  style: TextStyle(
                      color: c.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 7),
            ],
            Icon(Icons.chevron_right, color: c.subtext, size: 18),
          ],
        ),
      ),
    );
  }
}
