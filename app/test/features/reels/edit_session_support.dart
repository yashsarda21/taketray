import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/domain/models/edit_copy.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/features/reels/views/reel_detail_screen.dart';

import '../../support/pump_screen.dart';
import '../../support/vm_harness.dart';

/// The MediaStore id of the copy of the clip at [index] of a test session.
int copyIdAt(int index) => 500 + index;

/// Starts an editing session of reel [reelId] in [editor], in folder
/// [folder], straight in the database: [copied] clips get a copy of
/// [copySize] bytes each (on the fake phone, so the copy check on open finds
/// them, and `existingCopies` is allowed), [sent] clips are recorded as sent.
///
/// Returns the copies' MediaStore ids, in the order of [copied].
Future<List<int>> startEditing(
  VmHarness h,
  int reelId,
  EditorApp editor, {
  String folder = 'Goa',
  List<int> copied = const [],
  List<int> sent = const [],
  int copySize = 300 * 1000 * 1000,
}) async {
  final sessions = h.container.read(editSessionsRepositoryProvider);
  final session = await sessions.startSession(reelId, editor, folder);
  final ids = [for (var i = 0; i < copied.length; i++) copyIdAt(i)];
  await sessions.recordCopies([
    for (var i = 0; i < copied.length; i++)
      EditCopy(
        reelId: reelId,
        clipId: copied[i],
        copyMediaStoreId: ids[i],
        fileName: 'copy_$i.mp4',
        sizeBytes: copySize,
        copiedAt: session.createdAt,
      ),
  ]);
  if (sent.isNotEmpty) await sessions.recordSent(reelId, sent);
  h.editors
    ..existing = {...h.editors.existing, ...ids}
    ..allow({'existingCopies'});
  return ids;
}

/// Runs [job] on the real clock (a database call).
Future<T> real<T>(WidgetTester tester, Future<T> Function() job) async =>
    (await tester.runAsync(job)) as T;

/// Lets the database and the bridges' streams answer, then redraws.
Future<void> settleApp(WidgetTester tester) async {
  await tester.runAsync(settle);
  await tester.pump();
  await tester.pumpAndSettle();
}

/// Opens reel [id]'s page over `h`'s database on a phone-sized view.
Future<void> openReelPage(
  WidgetTester tester,
  VmHarness h,
  int id, {
  double textScale = 1,
  Brightness brightness = Brightness.light,
  bool askDoneEditing = false,
  Size size = const Size(360, 800),
  List<Override> overrides = const [],
}) async {
  await pumpScreen(
    tester,
    ReelDetailScreen(reelId: id, askDoneEditing: askDoneEditing),
    overrides: [...h.appOverrides, ...overrides],
    textScale: textScale,
    brightness: brightness,
    size: size,
    settle: false,
  );
  await settleApp(tester);
}

/// The text of every `Text` on screen, no-break spaces made plain, in tree
/// order.
List<String> textsOnScreen(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(find.byType(Text)))
    (t.data ?? t.textSpan?.toPlainText() ?? '').replaceAll(
      RegExp('[\u00a0\u202f]'),
      ' ',
    ),
];
