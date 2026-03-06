import '../feather_manifest.dart';
import '../loonbox_theme.dart';

/// Nightingale feather — classic layout inspired by the original Nightingale
/// music player. Colors extracted from the actual Blue Monday feather CSS:
///   window bg: rgb(51,51,51) #333333
///   sidebar (service pane): rgb(102,102,102) #666666
///   status/command bars: rgb(43,43,43) #2b2b2b
///   groups/trees/lists: rgb(91,91,91) #5b5b5b
///   text: rgb(230,228,240) #e6e4f0
final nightingale = LoonBoxFeather.fromManifest(
  const FeatherManifest(
    id: 'nightingale',
    name: 'Nightingale',
    version: '1.0.0',
    description: 'Classic layout inspired by Songbird/Nightingale — '
        'tree sidebar, top transport bar, and menu bar.',
    colors: FeatherColors(
      primary: '#e6e4f0',
      secondary: '#cacacd',
      tertiary: '#838383',
      surface: '#464646',
      background: '#2b2b2b',
      onPrimary: '#1a1a1a',
      onSurface: '#e6e4f0',
    ),
    sidebarStyle: SidebarStyle.tree,
    playerBarStyle: PlayerBarStyle.topTransport,
    brightness: FeatherBrightness.dark,
  ),
);
