/// Base error class for LoonBox.
sealed class LoonBoxError implements Exception {
  const LoonBoxError(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class AudioError extends LoonBoxError {
  const AudioError(super.message);
}

class DatabaseError extends LoonBoxError {
  const DatabaseError(super.message);
}

class MetadataError extends LoonBoxError {
  const MetadataError(super.message);
}

class ExtensionError extends LoonBoxError {
  const ExtensionError(super.message);
}

class ScanError extends LoonBoxError {
  const ScanError(super.message);
}
