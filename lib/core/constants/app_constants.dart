abstract final class AppConstants {
  static const String appName = 'Memos One';
  static const String appTagline = 'One Client. Every Device. Your Memos.';
  static const int localDbSchemaVersion = 1;
  static const int historyLimitPerMemo = 20;

  /// How often the worker wakes to drain the push queue.
  static const int syncPollSeconds = 5;

  /// Full list+delete-reconcile pull interval (manual Sync now always full-pulls).
  static const int fullPullIntervalMinutes = 30;

  static const int maxSyncRetries = 12;
  static const int searchDebounceMs = 250;
  static const int autosaveDebounceMs = 400;
  static const int attachmentWarnBytes = 25 * 1024 * 1024;
}
