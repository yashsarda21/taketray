// Hand-written; the rest of test/drift/ is generated (D-54).
//
// drift_dev make-migrations writes its own migration_test.dart once a second
// schema version exists. This test sits next to it and checks the other end:
// for every committed schema dump in drift_schemas/taketray/, it builds a
// database exactly as that version left it on a phone, opens it with today's
// AppDatabase (which runs any migrations), and compares the result with the
// tables today's code would create from scratch. At version 1 that means the
// code still matches drift_schema_v1.json, so the tables cannot change
// without a version bump.
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/database/app_database.dart';

import 'generated/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  for (final version in GeneratedHelper.versions) {
    test('a version $version database opens as the current schema', () async {
      final schema = await verifier.schemaAt(version);
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);

      await db.validateDatabaseSchema(
        options: const ValidationOptions(validateDropped: true),
      );
    });
  }
}
