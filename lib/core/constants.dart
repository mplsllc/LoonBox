/// Application-wide constants.
class LoonBoxConstants {
  LoonBoxConstants._();

  static const String appName = 'LoonBox';
  static const String appVersion = '0.1.0';
  static const String orgName = 'com.loonbox';
  static const String websiteUrl = 'https://loonbox.app';
  static const String companyName = 'MPLS LLC';
  static const String companyUrl = 'https://mp.ls';

  // Audio
  static const int eqBandCount = 10;
  static const List<int> eqFrequencies = [
    32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000,
  ];
  static const double eqMinGain = -12.0;
  static const double eqMaxGain = 12.0;
  static const double volumeMin = 0.0;
  static const double volumeMax = 1.0;

  // Smart playlist auto-update debounce
  static const Duration smartPlaylistInitialDelay = Duration(milliseconds: 1000);
  static const Duration smartPlaylistMaxDelay = Duration(milliseconds: 5000);
  static const Duration smartPlaylistSubsequentDelay = Duration(milliseconds: 500);

  // Library scanning
  static const int scanBatchSize = 100;

  // Supported audio extensions
  static const List<String> audioExtensions = [
    'mp3', 'flac', 'ogg', 'wav', 'aac', 'm4a', 'opus',
    'wma', 'ape', 'wv', 'dsf', 'dff', 'aiff', 'aif',
  ];
}
