/// The fixed choices the app stores: plain Dart enums, shared by the domain
/// models and the database.
///
/// The database stores each value by its `name` (D-54), so reordering or
/// adding values is safe, but renaming or removing one changes what is on
/// users' phones and needs a schema migration.
library;

/// Where a reel is in its life.
enum ReelStatus { collecting, ready, published }

/// How a clip came into TakeTray: detected in Android's media library while
/// Shooting mode was on, or picked by hand with the system photo picker.
enum ClipSource { mediaStore, picker }

/// A clip's place in To tag: waiting to be tagged, or skipped by the user.
enum InboxState { pending, skipped }

/// Where a saved reference link points to.
enum ReferenceSource { instagram, youtube, tiktok, link }
