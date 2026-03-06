import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'feather_manifest.dart';
import 'loonbox_theme.dart';
import 'default_feathers/bluemonday.dart';
import 'default_feathers/gonzo.dart';
import 'default_feathers/pinkmartini.dart';
import 'default_feathers/nightingale.dart';
import 'default_feathers/purplerain.dart';

/// Registry of all available feathers (built-in + user-installed).
class FeatherEngine {
  FeatherEngine._();

  static final Map<String, LoonBoxFeather> _builtIn = {
    blueMonday.id: blueMonday,
    gonzo.id: gonzo,
    pinkMartini.id: pinkMartini,
    purpleRain.id: purpleRain,
    nightingale.id: nightingale,
  };

  static final Map<String, LoonBoxFeather> _userInstalled = {};

  static List<LoonBoxFeather> get availableFeathers => [
        ..._builtIn.values,
        ..._userInstalled.values,
      ];

  static List<LoonBoxFeather> get builtInFeathers => _builtIn.values.toList();
  static List<LoonBoxFeather> get userFeathers => _userInstalled.values.toList();

  static LoonBoxFeather? getFeather(String id) =>
      _builtIn[id] ?? _userInstalled[id];

  static LoonBoxFeather get defaultFeather => blueMonday;

  /// Load user-installed feathers from the feathers directory.
  /// Each subdirectory should contain a `feather.json` manifest.
  static Future<int> loadUserFeathers(String feathersDir) async {
    _userInstalled.clear();
    final dir = Directory(feathersDir);
    if (!dir.existsSync()) return 0;

    var loaded = 0;
    await for (final entity in dir.list()) {
      if (entity is! Directory) continue;
      final manifestFile = File(p.join(entity.path, 'feather.json'));
      if (!manifestFile.existsSync()) continue;

      try {
        final json = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
        final manifest = FeatherManifest.fromJson(json);

        // Don't allow user feathers to override built-in IDs
        if (_builtIn.containsKey(manifest.id)) continue;

        final feather = LoonBoxFeather.fromManifest(
          manifest,
          directoryPath: entity.path,
        );
        _userInstalled[feather.id] = feather;
        loaded++;
      } catch (_) {
        // Skip invalid feathers
      }
    }
    return loaded;
  }

  /// Install a feather from a directory path.
  static Future<LoonBoxFeather?> installFromDirectory(
    String sourcePath,
    String feathersDir,
  ) async {
    final manifestFile = File(p.join(sourcePath, 'feather.json'));
    if (!manifestFile.existsSync()) return null;

    try {
      final json = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      final manifest = FeatherManifest.fromJson(json);
      if (_builtIn.containsKey(manifest.id)) return null;

      // Copy to feathers directory
      final destDir = Directory(p.join(feathersDir, manifest.id));
      if (!destDir.existsSync()) {
        destDir.createSync(recursive: true);
      }
      await _copyDirectory(Directory(sourcePath), destDir);

      final feather = LoonBoxFeather.fromManifest(
        manifest,
        directoryPath: destDir.path,
      );
      _userInstalled[feather.id] = feather;
      return feather;
    } catch (_) {
      return null;
    }
  }

  /// Remove a user-installed feather.
  static Future<bool> uninstall(String id) async {
    final feather = _userInstalled.remove(id);
    if (feather?.directoryPath == null) return false;

    try {
      final dir = Directory(feather!.directoryPath!);
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _copyDirectory(Directory source, Directory destination) async {
    await for (final entity in source.list(recursive: false)) {
      final newPath = p.join(destination.path, p.basename(entity.path));
      if (entity is File) {
        await entity.copy(newPath);
      } else if (entity is Directory) {
        final newDir = Directory(newPath)..createSync();
        await _copyDirectory(entity, newDir);
      }
    }
  }
}

/// Provider that loads feathers on startup.
final featherEngineProvider = FutureProvider<List<LoonBoxFeather>>((ref) async {
  // Determine user feathers directory
  final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '.';
  final feathersDir = p.join(home, '.loonbox', 'feathers');

  // Ensure directory exists
  final dir = Directory(feathersDir);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  await FeatherEngine.loadUserFeathers(feathersDir);
  return FeatherEngine.availableFeathers;
});
