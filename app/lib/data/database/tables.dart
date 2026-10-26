import 'package:drift/drift.dart';
import 'package:taketray/data/database/converters.dart';
import 'package:taketray/domain/models/enums.dart';

// The schema, version 1 (spec §8.1, D-54). Changing anything here changes the
// tables on users' phones: bump `AppDatabase.schemaVersion`, write the
// migration and run `dart run drift_dev make-migrations` (docs/flow.md,
// "Database open and migrations").
//
// Rules for every table:
// - Times are UTC milliseconds in int columns, through UtcMillisConverter.
// - Enums are stored by name (`textEnum`), so reordering values is safe.
// - Row classes end in `Row`; the domain models (Reel, Clip, …) keep the
//   plain names, and repositories convert between the two.
// - Text limits (a reel name's 40 characters) are counted in characters by
//   the domain rules, not here: SQL cannot count emoji as one character.

/// A reel the user is collecting clips for.
@DataClassName('ReelRow')
class Reels extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get status => textEnum<ReelStatus>()();
  IntColumn get createdAt => integer().map(const UtcMillisConverter())();
  IntColumn get updatedAt => integer().map(const UtcMillisConverter())();
}

/// A video TakeTray knows about. It holds facts about the video, never the
/// video itself.
///
/// Its identity is `volumeName` + `mediaStoreId` for a detected clip, or
/// `pickerUri` for a picked one. SQLite treats NULLs as distinct in a unique
/// key, so a picked clip (no MediaStore identity) never collides with
/// another.
@DataClassName('ClipRow')
@TableIndex(name: 'clips_date_taken_utc', columns: {#dateTakenUtc})
class Clips extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get source => textEnum<ClipSource>()();
  IntColumn get mediaStoreId => integer().nullable()();
  TextColumn get volumeName => text().nullable()();
  TextColumn get pickerUri => text().nullable()();
  IntColumn get sizeBytes => integer()();
  IntColumn get durationMs => integer()();
  IntColumn get dateTakenUtc => integer().map(const UtcMillisConverter())();
  TextColumn get displayName => text()();
  IntColumn get width => integer()();
  IntColumn get height => integer()();
  TextColumn get mimeType => text()();

  /// IANA zone where the clip was shot, e.g. `Europe/London` (spec §8.3a).
  TextColumn get timeZoneId => text().nullable()();
  IntColumn get generationAdded => integer().nullable()();
  IntColumn get firstSeenAt => integer().map(const UtcMillisConverter())();
  BoolColumn get missing => boolean().withDefault(const Constant(false))();
  IntColumn get lastVerifiedAt =>
      integer().map(const UtcMillisConverter()).nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {volumeName, mediaStoreId},
    {pickerUri},
  ];
}

/// Which clips are in which reels. A clip may be in many reels.
@DataClassName('ClipReelRow')
@TableIndex(name: 'clip_reels_reel_id', columns: {#reelId})
class ClipReels extends Table {
  IntColumn get clipId =>
      integer().references(Clips, #id, onDelete: KeyAction.cascade)();
  IntColumn get reelId =>
      integer().references(Reels, #id, onDelete: KeyAction.cascade)();
  IntColumn get addedAt => integer().map(const UtcMillisConverter())();

  @override
  Set<Column> get primaryKey => {clipId, reelId};
}

/// The To tag list (`pending`) and the Skipped list (`skipped`).
@DataClassName('InboxRow')
class Inbox extends Table {
  IntColumn get clipId =>
      integer().references(Clips, #id, onDelete: KeyAction.cascade)();
  TextColumn get state => textEnum<InboxState>()();
  IntColumn get addedAt => integer().map(const UtcMillisConverter())();

  @override
  Set<Column> get primaryKey => {clipId};
}

/// A saved link (an Instagram reel, a video) for a reel. Not called
/// `references`, which is an SQL keyword.
@DataClassName('ReelReferenceRow')
class ReelReferences extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get reelId =>
      integer().references(Reels, #id, onDelete: KeyAction.cascade)();
  TextColumn get url => text()();
  TextColumn get source => textEnum<ReferenceSource>()();
  TextColumn get label => text().nullable()();
  IntColumn get createdAt => integer().map(const UtcMillisConverter())();

  @override
  List<Set<Column>> get uniqueKeys => [
    {reelId, url},
  ];
}

/// A reel's copies for VN being edited: the folder they were copied into.
@DataClassName('VnSessionRow')
class VnSessions extends Table {
  IntColumn get reelId =>
      integer().references(Reels, #id, onDelete: KeyAction.cascade)();
  TextColumn get folderName => text()();
  IntColumn get createdAt => integer().map(const UtcMillisConverter())();

  @override
  Set<Column> get primaryKey => {reelId};
}

/// One copied file of a VN session.
@DataClassName('VnCopyRow')
class VnCopies extends Table {
  IntColumn get reelId =>
      integer().references(VnSessions, #reelId, onDelete: KeyAction.cascade)();
  IntColumn get clipId =>
      integer().references(Clips, #id, onDelete: KeyAction.cascade)();
  IntColumn get copyMediaStoreId => integer()();
  TextColumn get fileName => text()();
  IntColumn get sizeBytes => integer()();

  @override
  Set<Column> get primaryKey => {reelId, clipId};
}

/// Dart-only settings. Each value is JSON-encoded.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// The zone timeline (spec §8.3a): from `at` on, the phone was in `zoneId`.
/// A mirror of the native timeline, filled from phase 3.
@DataClassName('ZoneTimelineRow')
class ZoneTimeline extends Table {
  IntColumn get at => integer().map(const UtcMillisConverter())();
  TextColumn get zoneId => text()();

  @override
  Set<Column> get primaryKey => {at};
}
