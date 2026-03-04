import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class PlaylistsPage extends StatelessWidget {
  const PlaylistsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.playlistsTitle)),
      body: const Center(child: Text('Playlists — coming soon.')),
    );
  }
}
