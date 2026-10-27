import 'package:drift/drift.dart';

/// Stores an instant as UTC milliseconds since the epoch in an int column,
/// and reads it back as a UTC [DateTime] (D-54).
///
/// Drift's own `DateTime` columns store whole seconds, which would lose the
/// milliseconds that order clips shot in the same second. Microseconds are
/// dropped. A local [DateTime] is stored as the same instant.
///
/// Enums use drift's `textEnum`, which stores each value by its `name`.
class UtcMillisConverter extends TypeConverter<DateTime, int> {
  const new();

  @override
  DateTime fromSql(int fromDb) =>
      DateTime.fromMillisecondsSinceEpoch(fromDb, isUtc: true);

  @override
  int toSql(DateTime value) => value.millisecondsSinceEpoch;
}
