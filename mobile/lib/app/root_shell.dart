import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'screens/dashboard_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/training_screen.dart';
import 'screens/profile_screen.dart';
import 'theme.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _idx = 0;

  final _tabs = const <Widget>[
    DashboardScreen(),
    InsightsScreen(),
    TrainingScreen(),
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
          l.t('nav_trends'),
          l.t('nav_training'),
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
    Icons.bolt,
    Icons.show_chart,
    Icons.fitness_center,
    Icons.person_outline,
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
        decoration: const BoxDecoration(
          color: Color(0xFF0A0E13),
          border: Border(top: BorderSide(color: Color(0xFF18222F))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(labels.length, (i) {
            final active = i == index;
            return InkWell(
              onTap: () => onTap(i),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 46,
                      height: 29,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: active
                            ? c.accent.withValues(alpha: 0.14)
                            : Colors.transparent,
                      ),
                      child: Icon(
                        _icons[i],
                        size: 22,
                        color: active ? c.accent : c.subtext,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                        color: active ? c.accent : c.subtext,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
