import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';

class TrainingScreen extends StatelessWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.appColors;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        Text(l.t('training'),
            style: GoogleFonts.spaceGrotesk(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFF2F6FF),
                letterSpacing: -0.5)),
        const SizedBox(height: 16),

        // Recommended session
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF1F5A44)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F3A2C), Color(0xFF0E1822)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.t('recommended_today'),
                  style: TextStyle(
                      color: c.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
              const SizedBox(height: 7),
              Text(l.t('tempo_run'),
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFF2F6FF))),
              const SizedBox(height: 5),
              Text(l.t('tempo_msg'),
                  style: const TextStyle(
                      color: Color(0xFFBFE9D6), fontSize: 13, height: 1.4)),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () {},
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: const Color(0xFF06120C),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text(l.t('start_session'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Quick start
        _sectionLabel(c, l.t('quick_start')),
        const SizedBox(height: 11),
        Row(
          children: [
            _quickTile(c, Icons.directions_run, l.t('run'), c.accent),
            const SizedBox(width: 10),
            _quickTile(c, Icons.directions_bike, l.t('bike'), c.accent2),
            const SizedBox(width: 10),
            _quickTile(c, Icons.pool, l.t('swim'), c.sleep),
            const SizedBox(width: 10),
            _quickTile(c, Icons.fitness_center, l.t('strength'), c.warn),
          ],
        ),
        const SizedBox(height: 16),

        // Recent
        _sectionLabel(c, l.t('recent')),
        const SizedBox(height: 11),
        _recentRow(c, Icons.directions_run, l.t('morning_run'), l.t('run_meta'),
            l.t('yest'), c.accent),
        const SizedBox(height: 10),
        _recentRow(c, Icons.fitness_center, l.t('upper_body'),
            l.t('upper_meta'), l.t('mon'), c.warn),
      ],
    );
  }

  Widget _sectionLabel(AppColors c, String text) => Text(text,
      style: TextStyle(
          color: c.subtext,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8));

  Widget _quickTile(AppColors c, IconData icon, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: const Color(0xFF101924),
                border: Border.all(color: const Color(0xFF1C2838)),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
          ),
          const SizedBox(height: 7),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Color(0xFF9FB0CC),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _recentRow(AppColors c, IconData icon, String title, String meta,
      String when, Color color) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF101924),
        border: Border.all(color: const Color(0xFF1C2838)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: color.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: color, size: 22),
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
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(meta, style: TextStyle(color: c.subtext, fontSize: 12)),
              ],
            ),
          ),
          Text(when,
              style: GoogleFonts.spaceGrotesk(
                  color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
