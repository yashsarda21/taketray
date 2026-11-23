import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/references_repository.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/reel_reference.dart';
import 'package:taketray/domain/models/undo_record.dart';
import 'package:taketray/features/references/view_models/reference_actions.dart';

import '../../../support/vm_harness.dart';

const _secretUrl = 'https://www.instagram.com/reel/SECRETLINK/';
const _secretLabel = 'Secret label words';

/// A repository whose delete fails with a message that holds a link.
class _FailingReferences extends ReferencesRepository {
  // The parameters of ReferencesRepository are private, so they cannot be
  // super parameters.
  // ignore: use_super_parameters, the same reason
  _FailingReferences(AppDatabase db, Clock clock) : super(db, clock);

  @override
  Future<ReferenceRemoveUndo?> delete(int id) async =>
      throw StateError('disk full at $_secretUrl');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VmHarness h;
  late ReelsRepository reels;
  late ReferencesRepository refs;
  late ReferenceActions actions;
  late Reel goa;
  late List<LogRecord> records;

  setUp(() async {
    h = VmHarness();
    reels = h.container.read(reelsRepositoryProvider);
    refs = h.container.read(referencesRepositoryProvider);
    actions = h.container.read(referenceActionsProvider);
    goa = await reels.create('Goa');
    records = [];
    final old = Logger.root.level;
    Logger.root.level = Level.ALL;
    final sub = Logger.root.onRecord.listen(records.add);
    addTearDown(() async {
      await sub.cancel();
      Logger.root.level = old;
    });
  });

  Future<ReelReference> saved({String url = _secretUrl, String? label}) async {
    final result = await refs.add(goa.id, url, label: label ?? _secretLabel);
    return (result as ReferenceAdded).reference;
  }

  /// Everything logged, messages and errors, as one text.
  String logged() => records.map((r) => '${r.message} ${r.error}').join('\n');

  void expectNoSecrets() {
    final text = logged();
    expect(text, isNot(contains('SECRETLINK')));
    expect(text, isNot(contains('instagram')));
    expect(text, isNot(contains('Secret label')));
    expect(text, isNot(contains('Goa')));
    expect(text, isNot(contains('disk full')));
  }

  group('open', () {
    test(
      'asks the bridge to open the stored link and says it opened',
      () async {
        final ref = await saved();
        expect(await actions.open(ref), isTrue);
        expect(h.links.opened, [ref.url]);
      },
    );

    test('says false when no app can open it', () async {
      final ref = await saved();
      h.links.answer = false;
      expect(await actions.open(ref), isFalse);
      expect(h.links.opened, [ref.url]);
    });

    test('a bridge that throws is false, logged by type only', () async {
      final ref = await saved();
      h.links.failWith = StateError('could not open $_secretUrl');
      expect(await actions.open(ref), isFalse);
      expect(logged(), contains('StateError'));
      expect(logged(), contains('${ref.id}'));
      expectNoSecrets();
      expect(logged(), isNot(contains('could not open')));
    });

    test('logs no link or label when it opens or not', () async {
      final ref = await saved();
      await actions.open(ref);
      h.links.answer = false;
      await actions.open(ref);
      expectNoSecrets();
    });
  });

  group('copy', () {
    late List<Object?> written;

    setUp(() {
      written = [];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            ..setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                written.add(call.arguments);
              }
              return null;
            });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
    });

    test('puts the stored link on the clipboard, not the label', () async {
      final ref = await saved();
      await actions.copy(ref);
      expect(written, [
        {'text': ref.url},
      ]);
      expectNoSecrets();
    });

    test('a clipboard that fails is rethrown and logged by type', () async {
      final ref = await saved();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            ..setMockMethodCallHandler(SystemChannels.platform, (call) async {
              throw PlatformException(code: 'nope', message: _secretUrl);
            });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await expectLater(actions.copy(ref), throwsA(isA<PlatformException>()));
      expect(logged(), contains('PlatformException'));
      expectNoSecrets();
    });
  });

  group('remove', () {
    test('deletes the reference and returns what Undo needs', () async {
      final ref = await saved();
      final undo = await actions.remove(ref.id);

      expect(undo, isNotNull);
      expect(undo!.reference, ref);
      expect(await refs.watchForReel(goa.id).first, isEmpty);

      await reels.undoAll([undo]);
      expect(await refs.watchForReel(goa.id).first, [ref]);
    });

    test('an unknown id removes nothing and returns null', () async {
      final ref = await saved();
      expect(await actions.remove(ref.id + 100), isNull);
      expect(await refs.watchForReel(goa.id).first, [ref]);
    });

    test('a database failure is rethrown, logged by type only', () async {
      final ref = await saved();
      final failing = ReferenceActions(
        _FailingReferences(h.media.db, h.media.clock),
        h.links,
      );
      await expectLater(failing.remove(ref.id), throwsStateError);
      expect(logged(), contains('StateError'));
      expectNoSecrets();
    });

    test('logs no link or label', () async {
      final ref = await saved();
      await actions.remove(ref.id);
      expectNoSecrets();
    });
  });
}
