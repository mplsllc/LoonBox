import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../database/database.dart';

final artistListProvider = FutureProvider<List<Artist>>((ref) async {
  final db = ref.watch(databaseProvider);
  return (db.select(db.artists)..orderBy([(a) => OrderingTerm.asc(a.name)])).get();
});

class ArtistsPage extends ConsumerWidget {
  const ArtistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final artistsAsync = ref.watch(artistListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.artistsTitle)),
      body: artistsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (artists) {
          if (artists.isEmpty) {
            return const Center(child: Text('No artists yet.'));
          }
          return ListView.builder(
            itemCount: artists.length,
            itemBuilder: (context, index) {
              final artist = artists[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(artist.name.isNotEmpty ? artist.name[0].toUpperCase() : '?'),
                ),
                title: Text(artist.name),
              );
            },
          );
        },
      ),
    );
  }
}
