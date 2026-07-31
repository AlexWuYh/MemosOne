import '../../domain/entities/memo.dart';

enum ConflictWinner { local, remote }

/// V1 Last-Write-Wins using comparable timestamps.
class ConflictResolver {
  ConflictWinner decide({
    required Memo local,
    required DateTime? remoteUpdatedAt,
  }) {
    final remote = remoteUpdatedAt;
    if (remote == null) return ConflictWinner.local;
    if (!local.dirty) return ConflictWinner.remote;

    final localTime = local.updatedAtLocal;
    if (localTime.isAfter(remote) || localTime.isAtSameMomentAs(remote)) {
      return ConflictWinner.local;
    }
    return ConflictWinner.remote;
  }
}
