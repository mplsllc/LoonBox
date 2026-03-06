import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'features/shell/app_shell.dart';
import 'theme/feather_manifest.dart';
import 'theme/loonbox_theme.dart';

class LoonBoxApp extends ConsumerWidget {
  const LoonBoxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(loonBoxThemeProvider);

    // Feathers can force a brightness (e.g. Nightingale forces dark mode)
    final themeMode = switch (theme.manifest?.brightness) {
      FeatherBrightness.dark => ThemeMode.dark,
      FeatherBrightness.light => ThemeMode.light,
      null => ThemeMode.system,
    };

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LoonBox',
      theme: theme.lightTheme,
      darkTheme: theme.darkTheme,
      themeMode: themeMode,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AppShell(),
    );
  }
}
