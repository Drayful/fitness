import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'screens/dashboard_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/sleep_screen.dart';
import 'screens/training_screen.dart';
import 'theme.dart';

/// Bottom navigation from the YUMN design: Home · Sleep · Training · Trends ·
/// Profile. The design's "Team" tab waits for the group feature; Trends takes
/// its slot (same chart icon) until then.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _idx = 0;

  final _tabs = const <Widget>[
    DashboardScreen(),
    SleepScreen(embedded: true),
    TrainingScreen(),
    InsightsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(bottom: false, child: _tabs[_idx]),
      bottomNavigationBar: _NavBar(
        index: _idx,
        onTap: (v) => setState(() => _idx = v),
        labels: [
          l.t('nav_today'),
          l.t('nav_sleep'),
          l.t('nav_training'),
          l.t('nav_trends'),
          l.t('nav_profile'),
        ],
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.index,
    required this.onTap,
    required this.labels,
  });

  final int index;
  final ValueChanged<int> onTap;
  final List<String> labels;

  static const _icons = [
    Icons.home_outlined,
    Icons.bedtime_outlined,
    Icons.bolt_outlined,
    Icons.bar_chart_rounded,
    Icons.person_outline,
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        decoration: const BoxDecoration(
          color: AppTheme.bg,
          border: Border(top: BorderSide(color: AppTheme.outline)),
        ),
        child: Row(
          children: List.generate(labels.length, (i) {
            final active = i == index;
            final color = active ? AppTheme.accent : AppTheme.subtext;
            return Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_icons[i], size: 22, color: color),
                      const SizedBox(height: 5),
                      Text(
                        labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
