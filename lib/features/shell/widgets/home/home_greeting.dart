import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';

/// Time-of-day greeting + date header.
class HomeGreeting extends StatelessWidget {
  const HomeGreeting({super.key, required this.hasPlayHistory});

  final bool hasPlayHistory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    final greeting = hasPlayHistory ? _timeGreeting(l10n, now) : l10n.homeWelcome;
    final dateStr = DateFormat.yMMMMd().format(now);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(greeting, style: textTheme.headlineSmall),
          ),
          Text(
            dateStr,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _timeGreeting(AppLocalizations l10n, DateTime now) {
    final hour = now.hour;
    if (hour >= 5 && hour < 12) return l10n.homeGreetingMorning;
    if (hour >= 12 && hour < 17) return l10n.homeGreetingAfternoon;
    return l10n.homeGreetingEvening;
  }
}
