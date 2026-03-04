import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../database/database.dart';
import '../../../features/library/data/library_repository.dart';
import '../../../theme/feather_engine.dart';
import '../../../theme/loonbox_theme.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final repo = ref.watch(libraryRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          // Watch Directories section
          _SectionHeader(title: l10n.settingsWatchDirs),
          _WatchDirsList(repo: repo),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () => _addWatchDirectory(context, repo),
              icon: const Icon(Icons.add),
              label: Text(l10n.settingsAddDir),
            ),
          ),
          const SizedBox(height: 16),

          // Library actions
          _SectionHeader(title: l10n.libraryTitle),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: Text(l10n.settingsRescanLibrary),
            onTap: () => _rescan(context, repo),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services),
            title: Text(l10n.settingsCleanLibrary),
            onTap: () => _clean(context, repo),
          ),
          const SizedBox(height: 16),

          // Plumage — feather switcher
          _SectionHeader(title: l10n.settingsFeathers),
          _PlumageSection(),
          const SizedBox(height: 16),

          // About
          _SectionHeader(title: l10n.settingsAbout),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('LoonBox v0.1.0'),
            subtitle: Text('A product of MPLS LLC'),
          ),
        ],
      ),
    );
  }

  Future<void> _addWatchDirectory(BuildContext context, LibraryRepository repo) async {
    // Simple text input dialog for now (file_picker package can be added later)
    final controller = TextEditingController();
    final path = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Watch Directory'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter directory path',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (path != null && path.isNotEmpty) {
      await repo.addWatchDirectory(path);
      // Trigger initial scan
      await for (final _ in repo.scanDirectory(path)) {
        // Progress updates could be shown via snackbar
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scan complete')),
        );
      }
    }
  }

  Future<void> _rescan(BuildContext context, LibraryRepository repo) async {
    await for (final _ in repo.rescanAll()) {}
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rescan complete')),
      );
    }
  }

  Future<void> _clean(BuildContext context, LibraryRepository repo) async {
    final removed = await repo.cleanMissingTracks();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed $removed missing tracks')),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _WatchDirsList extends ConsumerWidget {
  const _WatchDirsList({required this.repo});
  final LibraryRepository repo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dirsAsync = ref.watch(_watchDirsProvider);

    return dirsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Text('Error: $e'),
      data: (dirs) {
        if (dirs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('No watch directories configured.'),
          );
        }
        return Column(
          children: dirs.map((dir) {
            return ListTile(
              leading: const Icon(Icons.folder),
              title: Text(dir.path),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: l10n.settingsRemoveDir,
                onPressed: () => repo.removeWatchDirectory(dir.id),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _PlumageSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feathersAsync = ref.watch(featherEngineProvider);
    final currentFeather = ref.watch(loonBoxThemeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return feathersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('Error loading feathers: $e'),
      ),
      data: (feathers) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: feathers.map((feather) {
              final isSelected = feather.id == currentFeather.id;
              final primaryColor = feather.lightTheme.colorScheme.primary;
              return GestureDetector(
                onTap: () {
                  ref.read(loonBoxThemeProvider.notifier).setFeather(feather);
                },
                child: Semantics(
                  label: '${feather.name} theme${isSelected ? ", selected" : ""}',
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: colorScheme.onSurface, width: 3)
                          : Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isSelected)
                          Icon(Icons.check, color: feather.lightTheme.colorScheme.onPrimary),
                        const SizedBox(height: 4),
                        Text(
                          feather.name,
                          style: TextStyle(
                            color: feather.lightTheme.colorScheme.onPrimary,
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

final _watchDirsProvider = FutureProvider<List<WatchDirectory>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.watchDirectories).get();
});
