import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:taketray/data/database/app_database.dart';

/// A Drift interceptor that records every statement the database runs, and
/// can make one of them fail.
///
/// Use it through [loggedTestDatabase]: [selects] counts the queries a stream
/// needs per emission, and [failWhen] injects a failure in the middle of a
/// transaction to prove it rolls back.
class StatementLog extends QueryInterceptor {
  /// Every `SELECT` run, in order.
  final List<String> selects = [];

  /// Every write (insert, update, delete), in order.
  final List<String> writes = [];

  /// When set, the first write it returns true for throws instead of running
  /// (and the hook is cleared, so a retry works).
  bool Function(String sql)? failWhen;

  void clear() {
    selects.clear();
    writes.clear();
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    selects.add(statement);
    return executor.runSelect(statement, args);
  }

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    _write(statement);
    return executor.runInsert(statement, args);
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    _write(statement);
    return executor.runUpdate(statement, args);
  }

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    _write(statement);
    return executor.runDelete(statement, args);
  }

  void _write(String statement) {
    final fail = failWhen;
    if (fail != null && fail(statement)) {
      failWhen = null;
      throw StateError('Injected failure');
    }
    writes.add(statement);
  }
}

/// A fresh in-memory database whose statements go through [log].
AppDatabase loggedTestDatabase(StatementLog log) =>
    AppDatabase(NativeDatabase.memory().interceptWith(log));
