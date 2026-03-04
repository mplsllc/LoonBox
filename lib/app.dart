import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/loonbox_theme.dart';

class LoonBoxApp extends ConsumerWidget {
  const LoonBoxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(loonBoxThemeProvider);

    return MaterialApp(
      title: 'LoonBox',
      theme: theme.lightTheme,
      darkTheme: theme.darkTheme,
      themeMode: ThemeMode.system,
      home: const Scaffold(
        body: Center(
          child: Text('LoonBox — Phase 1 Foundation'),
        ),
      ),
    );
  }
}
