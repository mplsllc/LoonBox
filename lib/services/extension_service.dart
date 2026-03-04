/// Service for managing LoonBox extensions (Lua/WASM plugins).
abstract class ExtensionService {
  Future<void> loadExtension(String path);
  Future<void> unloadExtension(String id);
  Future<void> enableExtension(String id);
  Future<void> disableExtension(String id);
  List<ExtensionInfo> get installedExtensions;
}

class ExtensionInfo {
  const ExtensionInfo({
    required this.id,
    required this.name,
    required this.version,
    this.description,
    this.author,
    this.enabled = true,
  });

  final String id;
  final String name;
  final String version;
  final String? description;
  final String? author;
  final bool enabled;
}
