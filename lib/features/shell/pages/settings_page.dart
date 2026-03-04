import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../database/database.dart' hide EqPreset;
import '../../../features/library/data/library_repository.dart';
import '../../../features/shell/pages/library_page.dart';
import '../../../services/audio_service.dart';
import '../../../services/extension_service.dart';
import '../../../theme/feather_engine.dart';
import '../../../theme/loonbox_theme.dart';
import '../../player/domain/eq_preset.dart';
import '../../player/presentation/player_provider.dart';

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
              onPressed: () => _addWatchDirectory(context, repo, ref),
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
            onTap: () => _rescan(context, repo, ref),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services),
            title: Text(l10n.settingsCleanLibrary),
            onTap: () => _clean(context, repo),
          ),
          const SizedBox(height: 16),

          // Equalizer
          _SectionHeader(title: l10n.settingsEqualizer),
          const _EqualizerSection(),
          const SizedBox(height: 16),

          // Plumage — feather switcher
          _SectionHeader(title: l10n.settingsFeathers),
          _PlumageSection(),
          const SizedBox(height: 16),

          // Extensions
          _SectionHeader(title: l10n.settingsExtensions),
          _ExtensionsSection(),
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

  Future<void> _addWatchDirectory(BuildContext context, LibraryRepository repo, WidgetRef ref) async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose Music Folder',
    );

    if (path == null || path.isEmpty) return;

    await repo.addWatchDirectory(path);
    ref.invalidate(_watchDirsProvider);

    if (!context.mounted) return;

    // Show scanning progress
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Scanning $path...'), duration: const Duration(seconds: 30)),
    );

    var count = 0;
    await for (final progress in repo.scanDirectory(path)) {
      count = progress.scanned;
    }

    ref.invalidate(trackListProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan complete — $count tracks found')),
      );
    }
  }

  Future<void> _rescan(BuildContext context, LibraryRepository repo, WidgetRef ref) async {
    await for (final _ in repo.rescanAll()) {}
    ref.invalidate(trackListProvider);
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

const _eqBandLabels = [
  '32', '64', '125', '250', '500', '1k', '2k', '4k', '8k', '16k',
];

class _EqualizerSection extends ConsumerWidget {
  const _EqualizerSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final eqEnabled = ref.watch(eqEnabledProvider);
    final currentPreset = ref.watch(eqPresetProvider);
    final audio = ref.watch(audioServiceProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enable toggle + preset selector row
          Row(
            children: [
              Switch(
                value: eqEnabled,
                onChanged: (v) {
                  ref.read(eqEnabledProvider.notifier).state = v;
                  if (v) {
                    audio.setEq(currentPreset.bands);
                  } else {
                    audio.setEq(List.filled(10, 0.0));
                  }
                },
              ),
              const SizedBox(width: 8),
              Text(l10n.eqEnabled),
              const Spacer(),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  initialValue: currentPreset.name,
                  decoration: InputDecoration(
                    labelText: l10n.eqPreset,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  items: EqPreset.builtInPresets.map((p) {
                    return DropdownMenuItem(value: p.name, child: Text(p.name));
                  }).toList(),
                  onChanged: eqEnabled
                      ? (name) {
                          if (name == null) return;
                          final preset = EqPreset.builtInPresets.firstWhere((p) => p.name == name);
                          ref.read(eqPresetProvider.notifier).state = preset;
                          audio.setEq(preset.bands);
                        }
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Band sliders
          if (eqEnabled)
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(10, (i) {
                  return Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Slider(
                              value: currentPreset.bands[i],
                              min: -1.0,
                              max: 1.0,
                              onChanged: (v) {
                                final newBands = List<double>.from(currentPreset.bands);
                                newBands[i] = v;
                                final updated = EqPreset(
                                    name: currentPreset.name,
                                    bands: newBands,
                                  );
                                ref.read(eqPresetProvider.notifier).state = updated;
                                audio.setEq(newBands);
                              },
                            ),
                          ),
                        ),
                        Text(
                          _eqBandLabels[i],
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
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

class _ExtensionsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final extService = ref.watch(extensionServiceProvider);
    final extensions = extService.installedExtensions;

    if (extensions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(l10n.extensionsNone),
      );
    }

    return Column(
      children: extensions.map((ext) {
        return ListTile(
          leading: const Icon(Icons.extension),
          title: Text(ext.name),
          subtitle: Text(
            [ext.version, if (ext.author != null) ext.author]
                .join(' — '),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.extensionsRemove,
            onPressed: () async {
              await extService.unloadExtension(ext.id);
            },
          ),
        );
      }).toList(),
    );
  }
}

final _watchDirsProvider = StreamProvider<List<WatchDirectory>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.watchDirectories).watch();
});
