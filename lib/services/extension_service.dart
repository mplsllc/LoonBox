import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../src/rust/api.dart' as rust;

/// Service for managing LoonBox extensions (Lua/WASM plugins).
abstract class ExtensionService {
  Future<ExtensionInfo> loadExtension(String path);
  Future<void> unloadExtension(String id);
  Future<void> enableExtension(String id);
  Future<void> disableExtension(String id);
  Future<List<String>> dispatchCall(String callName, Map<String, dynamic> args);
  Future<String> callFunction(String extensionId, String functionName, Map<String, dynamic> args);
  List<ExtensionInfo> get installedExtensions;
}

class ExtensionInfo {
  const ExtensionInfo({
    required this.id,
    required this.name,
    required this.version,
    this.description,
    this.author,
    this.permissions = const [],
    this.hooks = const [],
    this.enabled = true,
  });

  final String id;
  final String name;
  final String version;
  final String? description;
  final String? author;
  final List<String> permissions;
  final List<String> hooks;
  final bool enabled;
}

/// Concrete extension service backed by Rust FFI.
class RustExtensionService extends ExtensionService {
  final Map<String, ExtensionInfo> _loaded = {};
  final Set<String> _disabled = {};

  @override
  List<ExtensionInfo> get installedExtensions => _loaded.values.toList();

  @override
  Future<ExtensionInfo> loadExtension(String path) async {
    final info = await rust.extensionLoad(path: path);
    final ext = ExtensionInfo(
      id: info.id,
      name: info.name,
      version: info.version,
      description: info.description.isNotEmpty ? info.description : null,
      author: info.author.isNotEmpty ? info.author : null,
      permissions: info.permissions,
      hooks: info.hooks,
    );
    _loaded[ext.id] = ext;
    return ext;
  }

  @override
  Future<void> unloadExtension(String id) async {
    await rust.extensionUnload(id: id);
    _loaded.remove(id);
    _disabled.remove(id);
  }

  @override
  Future<void> enableExtension(String id) async {
    _disabled.remove(id);
  }

  @override
  Future<void> disableExtension(String id) async {
    _disabled.add(id);
  }

  @override
  Future<List<String>> dispatchCall(String callName, Map<String, dynamic> args) async {
    return rust.extensionDispatchCall(
      callName: callName,
      argsJson: jsonEncode(args),
    );
  }

  @override
  Future<String> callFunction(
    String extensionId,
    String functionName,
    Map<String, dynamic> args,
  ) async {
    return rust.extensionCallFunction(
      extensionId: extensionId,
      functionName: functionName,
      argsJson: jsonEncode(args),
    );
  }

  /// Load all extensions from a directory.
  Future<int> loadAllFromDirectory(String extensionsDir) async {
    final dir = Directory(extensionsDir);
    if (!dir.existsSync()) return 0;

    var loaded = 0;
    await for (final entity in dir.list()) {
      if (entity is! Directory) continue;
      final manifestFile = File(p.join(entity.path, 'extension.json'));
      if (!manifestFile.existsSync()) continue;

      try {
        await loadExtension(entity.path);
        loaded++;
      } catch (e) {
        // Skip invalid extensions
      }
    }
    return loaded;
  }
}

final extensionServiceProvider = Provider<RustExtensionService>((ref) {
  return RustExtensionService();
});
