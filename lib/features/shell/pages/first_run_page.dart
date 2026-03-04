import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/library/data/library_repository.dart';
import '../../../theme/feather_engine.dart';
import '../../../theme/loonbox_theme.dart';

/// First-run onboarding: welcome → pick folder → scan → pick feather → done.
class FirstRunPage extends ConsumerStatefulWidget {
  const FirstRunPage({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  ConsumerState<FirstRunPage> createState() => _FirstRunPageState();
}

class _FirstRunPageState extends ConsumerState<FirstRunPage> {
  int _step = 0;
  bool _scanning = false;
  int _scannedCount = 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: switch (_step) {
              0 => _WelcomeStep(
                  textTheme: textTheme,
                  colorScheme: colorScheme,
                  onNext: () => setState(() => _step = 1),
                ),
              1 => _FolderStep(
                  textTheme: textTheme,
                  scanning: _scanning,
                  scannedCount: _scannedCount,
                  onPickFolder: _pickFolder,
                  onSkip: () => setState(() => _step = 2),
                ),
              2 => _FeatherStep(
                  ref: ref,
                  onComplete: widget.onComplete,
                ),
              _ => const SizedBox.shrink(),
            },
          ),
        ),
      ),
    );
  }

  Future<void> _pickFolder() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose Music Folder',
    );

    if (path == null || path.isEmpty) return;

    setState(() {
      _scanning = true;
      _scannedCount = 0;
    });

    final repo = ref.read(libraryRepositoryProvider);
    await repo.addWatchDirectory(path);
    await for (final progress in repo.scanDirectory(path)) {
      if (mounted) {
        setState(() => _scannedCount = progress.scanned);
      }
    }

    if (mounted) {
      setState(() {
        _scanning = false;
        _step = 2;
      });
    }
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({
    required this.textTheme,
    required this.colorScheme,
    required this.onNext,
  });

  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.music_note, size: 80, color: colorScheme.primary),
        const SizedBox(height: 24),
        Text(
          'Welcome to LoonBox',
          style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'A modern music player, inspired by the spirit of Songbird and Nightingale.',
          style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: onNext,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Get Started'),
        ),
      ],
    );
  }
}

class _FolderStep extends StatelessWidget {
  const _FolderStep({
    required this.textTheme,
    required this.scanning,
    required this.scannedCount,
    required this.onPickFolder,
    required this.onSkip,
  });

  final TextTheme textTheme;
  final bool scanning;
  final int scannedCount;
  final VoidCallback onPickFolder;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.folder_open, size: 64, color: colorScheme.primary),
        const SizedBox(height: 24),
        Text(
          'Where is your music?',
          style: textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Point LoonBox at a folder and it will scan for audio files.',
          style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (scanning) ...[
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text('Scanning... $scannedCount tracks found'),
        ] else ...[
          FilledButton.icon(
            onPressed: onPickFolder,
            icon: const Icon(Icons.folder),
            label: const Text('Choose Folder'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onSkip,
            child: const Text('Skip for now'),
          ),
        ],
      ],
    );
  }
}

class _FeatherStep extends StatelessWidget {
  const _FeatherStep({
    required this.ref,
    required this.onComplete,
  });

  final WidgetRef ref;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final feathers = FeatherEngine.builtInFeathers;
    final currentFeather = ref.watch(loonBoxThemeProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.palette, size: 64, color: colorScheme.primary),
        const SizedBox(height: 24),
        Text(
          'Choose your feather',
          style: textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Pick a look. You can always change it later in Settings.',
          style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: feathers.map((feather) {
            final isSelected = feather.id == currentFeather.id;
            return GestureDetector(
              onTap: () {
                ref.read(loonBoxThemeProvider.notifier).setFeather(feather);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: feather.lightTheme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                  border: isSelected
                      ? Border.all(color: colorScheme.onSurface, width: 3)
                      : null,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected)
                        Icon(Icons.check, color: feather.lightTheme.colorScheme.onPrimary),
                      Text(
                        feather.name,
                        style: TextStyle(
                          color: feather.lightTheme.colorScheme.onPrimary,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: onComplete,
          icon: const Icon(Icons.check),
          label: const Text('Start Listening'),
        ),
      ],
    );
  }
}
