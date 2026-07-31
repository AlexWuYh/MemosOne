/// Application-wide constants.
abstract final class AppConstants {
  static const String appName = 'Memos One';
  static const String appTagline = 'One Client. Every Device. Your Memos.';

  /// Local schema version (Drift migrations). Independent of app version.
  static const int localDbSchemaVersion = 1;
}
