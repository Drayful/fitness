import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.t('trends'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 20),
          Text(l.t('trends_pending')),
        ],
      ),
    );
  }
}
