/// A 10-band equalizer preset.
class EqPreset {
  const EqPreset({
    required this.name,
    required this.bands,
    this.isBuiltIn = false,
  });

  final String name;

  /// 10 gain values, -1.0 to 1.0 (maps to -12dB to +12dB).
  final List<double> bands;

  final bool isBuiltIn;

  /// All 17 presets inherited from Nightingale.
  static const List<EqPreset> builtInPresets = [
    EqPreset(name: 'Flat', bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0], isBuiltIn: true),
    EqPreset(name: 'Classical', bands: [0, 0, 0, 0, 0, 0, -0.2, -0.2, -0.2, -0.4], isBuiltIn: true),
    EqPreset(name: 'Club', bands: [0, 0, 0.15, 0.2, 0.2, 0.2, 0.15, 0, 0, 0], isBuiltIn: true),
    EqPreset(name: 'Dance', bands: [0.5, 0.25, 0.05, 0, 0, -0.2, -0.3, -0.3, 0, 0], isBuiltIn: true),
    EqPreset(name: 'Full Bass', bands: [0.4, 0.4, 0.4, 0.2, 0, -0.2, -0.3, -0.35, -0.4, -0.4], isBuiltIn: true),
    EqPreset(name: 'Full Treble', bands: [-0.4, -0.4, -0.4, -0.15, 0.1, 0.4, 0.8, 0.8, 0.8, 0.8], isBuiltIn: true),
    EqPreset(name: 'Small Speakers', bands: [0.2, 0.4, 0.2, -0.2, -0.15, 0, 0.2, 0.4, 0.6, 0.7], isBuiltIn: true),
    EqPreset(name: 'Large Hall', bands: [0.45, 0.45, 0.2, 0.2, 0, -0.2, -0.2, -0.2, 0, 0], isBuiltIn: true),
    EqPreset(name: 'Live', bands: [-0.2, 0, 0.15, 0.2, 0.2, 0.2, 0.1, 0.05, 0.05, 0], isBuiltIn: true),
    EqPreset(name: 'Party', bands: [0.25, 0.25, 0, 0, 0, 0, 0, 0, 0.25, 0.25], isBuiltIn: true),
    EqPreset(name: 'Pop', bands: [-0.15, 0.15, 0.2, 0.25, 0.15, -0.15, -0.15, -0.15, -0.1, -0.1], isBuiltIn: true),
    EqPreset(name: 'Reggae', bands: [0, 0, -0.1, -0.2, 0, 0.2, 0.2, 0, 0, 0], isBuiltIn: true),
    EqPreset(name: 'Rock', bands: [0.3, 0.15, -0.2, -0.3, -0.1, 0.15, 0.3, 0.35, 0.35, 0.35], isBuiltIn: true),
    EqPreset(name: 'Ska', bands: [-0.1, -0.15, -0.12, -0.05, 0.15, 0.2, 0.3, 0.3, 0.4, 0.3], isBuiltIn: true),
    EqPreset(name: 'Soft', bands: [0.2, 0, -0.1, -0.15, -0.1, 0.2, 0.3, 0.35, 0.4, 0.5], isBuiltIn: true),
    EqPreset(name: 'Soft Rock', bands: [0.2, 0.2, 0, -0.1, -0.2, -0.3, -0.2, -0.1, 0.2, 0.4], isBuiltIn: true),
    EqPreset(name: 'Techno', bands: [0.3, 0.25, 0, -0.25, -0.2, 0, 0.3, 0.35, 0.35, 0.3], isBuiltIn: true),
  ];
}
