import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/database.dart' hide EqPreset;
import '../domain/eq_preset.dart';

/// EQ state: current preset and band values.
class EqState {
  const EqState({
    this.enabled = false,
    this.presetName = 'Flat',
    this.bands = const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  });

  final bool enabled;
  final String presetName;
  final List<double> bands;

  /// 10-band center frequencies (Hz).
  static const List<int> frequencies = [
    31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000,
  ];

  EqState copyWith({
    bool? enabled,
    String? presetName,
    List<double>? bands,
  }) {
    return EqState(
      enabled: enabled ?? this.enabled,
      presetName: presetName ?? this.presetName,
      bands: bands ?? this.bands,
    );
  }
}

class EqNotifier extends StateNotifier<EqState> {
  EqNotifier(this._db) : super(const EqState());

  final LoonBoxDatabase _db;

  /// Apply a built-in preset.
  void applyPreset(EqPreset preset) {
    state = state.copyWith(
      presetName: preset.name,
      bands: List.of(preset.bands),
    );
    // TODO: Send to Rust audio engine via FFI when biquad filters are implemented
  }

  /// Adjust a single band.
  void setBand(int index, double value) {
    if (index < 0 || index >= 10) return;
    final newBands = List<double>.of(state.bands);
    newBands[index] = value.clamp(-1.0, 1.0);
    state = state.copyWith(bands: newBands, presetName: 'Custom');
  }

  /// Toggle EQ on/off.
  void toggle() {
    state = state.copyWith(enabled: !state.enabled);
  }

  /// Save current settings as a custom preset.
  Future<void> saveAsPreset(String name) async {
    await _db.into(_db.eqPresets).insertOnConflictUpdate(
          EqPresetsCompanion.insert(
            name: name,
            bands: jsonEncode(state.bands),
          ),
        );
  }

  /// Load saved presets from DB.
  Future<List<EqPreset>> loadSavedPresets() async {
    final rows = await (_db.select(_db.eqPresets)
          ..where((p) => p.isBuiltin.equals(false)))
        .get();
    return rows.map((r) {
      final bands = (jsonDecode(r.bands) as List).cast<num>().map((n) => n.toDouble()).toList();
      return EqPreset(name: r.name, bands: bands);
    }).toList();
  }
}

final eqProvider = StateNotifierProvider<EqNotifier, EqState>((ref) {
  return EqNotifier(ref.watch(databaseProvider));
});
