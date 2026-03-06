import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../src/rust/api.dart' as rust;

/// Global provider for the browser service.
final browserServiceProvider = Provider<BrowserService>(
  (ref) => throw UnimplementedError('BrowserService not initialized'),
);

/// Manages the browser filtering proxy lifecycle.
class BrowserService {
  final int proxyPort;
  final String cacheDir;

  BrowserService._({required this.proxyPort, required this.cacheDir});

  /// Start the proxy and return a ready-to-use service.
  static Future<BrowserService> create() async {
    final appSupport = await getApplicationSupportDirectory();
    final cacheDir = '${appSupport.path}/loonbox_browser';

    final port = await rust.browserStartProxy(cacheDir: cacheDir);

    return BrowserService._(proxyPort: port, cacheDir: cacheDir);
  }

  /// Stop the proxy.
  Future<void> dispose() async {
    await rust.browserStopProxy();
  }

  /// Update adblock filter lists from the network.
  Future<void> updateFilterLists() async {
    await rust.browserUpdateFilterLists();
  }

  /// Get filter stats as a JSON string.
  Future<String> getFilterStats() async {
    return await rust.browserGetFilterStats();
  }

  /// Verify a package file's SHA-256 hash.
  Future<bool> verifyPackage(String path, String expectedSha256) async {
    return await rust.browserVerifyPackage(
      packagePath: path,
      expectedSha256: expectedSha256,
    );
  }
}
