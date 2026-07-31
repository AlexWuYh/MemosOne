import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

@DataClassName('WorkspaceRow')
class Workspaces extends Table {
  TextColumn get localId => text()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // local | memos | cloud
  TextColumn get serverBaseUrl => text().nullable()();
  TextColumn get databasePath => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();
  BoolColumn get initialSyncCompleted =>
      boolean().withDefault(const Constant(false))();
  TextColumn get authState =>
      text().withDefault(const Constant('none'))(); // none|ok|needsReauth
  TextColumn get serverVersion => text().nullable()();
  TextColumn get username => text().nullable()();
  BoolColumn get allowInsecureTls =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {localId};
}

@DataClassName('MemoRow')
class Memos extends Table {
  TextColumn get localId => text()();
  TextColumn get workspaceId => text()();
  TextColumn get serverName => text().nullable()();
  TextColumn get content => text()();
  TextColumn get visibility =>
      text().withDefault(const Constant('private'))();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get createdAtLocal => dateTime()();
  DateTimeColumn get updatedAtLocal => dateTime()();
  DateTimeColumn get createdAtServer => dateTime().nullable()();
  DateTimeColumn get updatedAtServer => dateTime().nullable()();
  TextColumn get syncStatus =>
      text().withDefault(const Constant('clean'))();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();
  TextColumn get contentHash => text().nullable()();
  TextColumn get lastError => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {localId};
}

@DataClassName('TagRow')
class Tags extends Table {
  TextColumn get localId => text()();
  TextColumn get workspaceId => text()();
  TextColumn get name => text()();

  @override
  Set<Column<Object>> get primaryKey => {localId};
}

@DataClassName('MemoTagRow')
class MemoTags extends Table {
  TextColumn get memoLocalId => text()();
  TextColumn get tagLocalId => text()();

  @override
  Set<Column<Object>> get primaryKey => {memoLocalId, tagLocalId};
}

@DataClassName('MemoHistoryRow')
class MemoHistories extends Table {
  TextColumn get localId => text()();
  TextColumn get memoLocalId => text()();
  TextColumn get content => text()();
  DateTimeColumn get capturedAt => dateTime()();
  TextColumn get reason => text()();
  TextColumn get serverName => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {localId};
}

@DataClassName('SyncTaskRow')
class SyncTasks extends Table {
  TextColumn get id => text()();
  TextColumn get workspaceId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityLocalId => text()();
  TextColumn get action => text()();
  TextColumn get payloadJson => text().nullable()();
  TextColumn get status => text()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime()();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SyncCursorRow')
class SyncCursors extends Table {
  TextColumn get key => text()();
  TextColumn get workspaceId => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key, workspaceId};
}

@DataClassName('AttachmentRow')
class Attachments extends Table {
  TextColumn get localId => text()();
  TextColumn get memoLocalId => text()();
  TextColumn get workspaceId => text()();
  TextColumn get serverName => text().nullable()();
  TextColumn get mimeType => text()();
  IntColumn get sizeBytes => integer()();
  TextColumn get hashSha256 => text().nullable()();
  TextColumn get localPath => text().nullable()();
  TextColumn get remoteUrl => text().nullable()();
  TextColumn get fileName => text().nullable()();
  DateTimeColumn get createdAtLocal => dateTime()();
  DateTimeColumn get updatedAtLocal => dateTime()();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {localId};
}

@DriftDatabase(
  tables: [
    Workspaces,
    Memos,
    Tags,
    MemoTags,
    MemoHistories,
    SyncTasks,
    SyncCursors,
    Attachments,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.forTesting() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_memos_ws_updated '
            'ON memos (workspace_id, pinned, updated_at_local)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_memos_dirty ON memos (dirty)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_memos_server ON memos (server_name)',
          );
          await customStatement(
            'CREATE VIRTUAL TABLE IF NOT EXISTS memo_fts USING fts5('
            'local_id UNINDEXED, workspace_id UNINDEXED, content)',
          );
        },
      );

  static Future<AppDatabase> open() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'memos_one.sqlite'));
    return AppDatabase(NativeDatabase.createInBackground(file));
  }
}
