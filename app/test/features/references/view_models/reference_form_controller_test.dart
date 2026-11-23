import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/references_repository.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/reel_reference.dart';
import 'package:taketray/features/references/view_models/reference_form_controller.dart';

import '../../../support/vm_harness.dart';

/// A references repository that counts its writes and can be held or failed.
class _CountingReferences extends ReferencesRepository {
  // The parameters of ReferencesRepository are private, so they cannot be
  // super parameters.
  // ignore: use_super_parameters, the same reason
  _CountingReferences(AppDatabase db, Clock clock) : super(db, clock);

  int adds = 0;
  int labels = 0;
  Error? failWith;

  /// Holds a write until it completes (a slow database).
  Completer<void>? hold;

  @override
  Future<AddReferenceResult> add(
    int reelId,
    String rawUrl, {
    String? label,
  }) async {
    adds++;
    await hold?.future;
    final failure = failWith;
    if (failure != null) throw failure;
    return await super.add(reelId, rawUrl, label: label);
  }

  @override
  Future<void> setLabel(int id, String? label) async {
    labels++;
    await hold?.future;
    final failure = failWith;
    if (failure != null) throw failure;
    await super.setLabel(id, label);
  }
}

/// A reels repository that has lost the reel when it is asked for it.
class _ForgetfulReels extends ReelsRepository {
  // ignore: use_super_parameters, the parameters of ReelsRepository are private
  _ForgetfulReels(AppDatabase db, Clock clock) : super(db, clock);

  @override
  Future<Reel?> getById(int id) async => null;
}

void main() {
  late VmHarness h;
  late _CountingReferences refs;
  late ReelsRepository reels;
  late ProviderContainer container;
  late int goa;

  setUp(() async {
    h = VmHarness();
    refs = _CountingReferences(h.media.db, h.media.clock);
    reels = ReelsRepository(h.media.db, h.media.clock);
    container = ProviderContainer.test(
      overrides: [
        ...h.overrides,
        referencesRepositoryProvider.overrideWithValue(refs),
        reelsRepositoryProvider.overrideWithValue(reels),
      ],
    );
    goa = (await reels.create('Goa')).id;
  });

  ReferenceFormController form([int? reelId]) {
    final provider = referenceFormControllerProvider(reelId ?? goa);
    container.listen(provider, (_, _) {});
    return container.read(provider.notifier);
  }

  bool saving([int? reelId]) =>
      container.read(referenceFormControllerProvider(reelId ?? goa));

  Future<List<ReelReference>> stored([int? reelId]) =>
      refs.watchForReel(reelId ?? goa).first;

  group('saveNew', () {
    test('saves a link with its label and says so', () async {
      final result = await form().saveNew(
        'https://www.instagram.com/reel/A1/?igsh=zz',
        '  Fast cuts ',
      );

      expect(result, isA<ReferenceSaved>());
      final saved = (result as ReferenceSaved).reference;
      expect(saved.url, 'https://www.instagram.com/p/A1/');
      expect(saved.label, 'Fast cuts');
      expect(saved.source, ReferenceSource.instagram);
      expect(saved.reelId, goa);
      expect(await stored(), [saved]);
      expect(saving(), isFalse);
    });

    test('a caption with a link around it saves the first link', () async {
      final result = await form().saveNew(
        'Look https://instagram.com/reel/A1 and https://youtu.be/B2 wow',
        '',
      );
      expect((result as ReferenceSaved).reference.url, contains('/p/A1/'));
      expect(await stored(), hasLength(1));
    });

    test('a bare address is given https://', () async {
      final result = await form().saveNew('www.youtube.com/watch?v=abc', '');
      expect(
        (result as ReferenceSaved).reference.url,
        'https://www.youtube.com/watch?v=abc',
      );
    });

    test('a blank label is no label', () async {
      final result = await form().saveNew('https://x.com/a', '   ');
      expect((result as ReferenceSaved).reference.label, isNull);
    });

    test(
      'a 60 emoji label is fine, 61 is too long and saves nothing',
      () async {
        final controller = form();
        final fine = await controller.saveNew('https://x.com/a', '🎬' * 60);
        expect(fine, isA<ReferenceSaved>());

        final adds = refs.adds;
        final long = await controller.saveNew('https://x.com/b', '🎬' * 61);
        expect(long, isA<ReferenceLabelTooLong>());
        expect(refs.adds, adds, reason: 'the repository was never asked');
        expect(await stored(), hasLength(1));
      },
    );

    for (final text in [
      '',
      '   ',
      'hello',
      'hello.',
      '.com',
      'a..com',
      'see x.com',
      '3.5',
      'user@example.com',
      'ftp://x.com/a',
      'https://hello',
    ]) {
      test('"$text" is not a link and saves nothing', () async {
        final result = await form().saveNew(text, 'Label');
        expect(result, isA<ReferenceNotALink>());
        expect(refs.adds, 0, reason: 'junk never reaches the repository');
        expect(await stored(), isEmpty);
        expect(saving(), isFalse);
      });
    }

    test('not a link wins over a label that is too long', () async {
      final result = await form().saveNew('hello', 'x' * 100);
      expect(result, isA<ReferenceNotALink>());
    });

    test('the same page again says where it is saved, as stored', () async {
      final controller = form();
      final first = await controller.saveNew(
        'https://www.instagram.com/reel/A1/',
        'First',
      );
      final again = await controller.saveNew(
        'instagram.com/reel/A1?igsh=other',
        'Second',
      );

      expect(first, isA<ReferenceSaved>());
      expect(again, isA<ReferenceAlreadyIn>());
      expect((again as ReferenceAlreadyIn).reelName, 'Goa');
      final rows = await stored();
      expect(rows, hasLength(1));
      expect(rows.single.label, 'First', reason: 'the saved one is untouched');
    });

    test('the same link in another reel is not a duplicate', () async {
      final paris = (await reels.create('Paris')).id;
      await form().saveNew('https://x.com/a', '');
      final result = await form(paris).saveNew('https://x.com/a', '');
      expect(result, isA<ReferenceSaved>());
    });

    test('a reel deleted before Save fails and saves nothing', () async {
      await reels.delete(goa);
      final result = await form().saveNew('https://x.com/a', '');
      expect(result, isA<ReferenceSaveFailed>());
      expect(refs.adds, 1);
      expect(await stored(), isEmpty);
      expect(saving(), isFalse);
    });

    test('a database failure fails, logs the type only', () async {
      refs.failWith = StateError('disk full: https://secret.example/a');
      final records = <LogRecord>[];
      final old = Logger.root.level;
      Logger.root.level = Level.ALL;
      final sub = Logger.root.onRecord.listen(records.add);
      addTearDown(() async {
        await sub.cancel();
        Logger.root.level = old;
      });

      final result = await form().saveNew('https://secret.example/a', 'Mine');

      expect(result, isA<ReferenceSaveFailed>());
      expect(saving(), isFalse);
      final logged = records.map((r) => '${r.message} ${r.error}').join('\n');
      expect(logged, contains('StateError'));
      expect(logged, isNot(contains('secret')));
      expect(logged, isNot(contains('Mine')));
      expect(logged, isNot(contains('disk full')));
    });

    test('Save works again after a failure', () async {
      refs.failWith = StateError('disk full');
      final controller = form();
      expect(
        await controller.saveNew('https://x.com/a', ''),
        isA<ReferenceSaveFailed>(),
      );
      refs.failWith = null;
      expect(
        await controller.saveNew('https://x.com/a', ''),
        isA<ReferenceSaved>(),
      );
    });

    test('Save works again after a refused one', () async {
      final controller = form();
      expect(await controller.saveNew('hello', ''), isA<ReferenceNotALink>());
      expect(
        await controller.saveNew('https://x.com/a', ''),
        isA<ReferenceSaved>(),
      );
    });

    test('a reel that vanished after the add says it could not save', () async {
      // The reel is there for the repository's add (so the link is a
      // duplicate), and gone when the controller asks for its name.
      final forgetful = ProviderContainer.test(
        overrides: [
          ...h.overrides,
          referencesRepositoryProvider.overrideWithValue(refs),
          reelsRepositoryProvider.overrideWithValue(
            _ForgetfulReels(h.media.db, h.media.clock),
          ),
        ],
      );
      final provider = referenceFormControllerProvider(goa);
      forgetful.listen(provider, (_, _) {});
      final controller = forgetful.read(provider.notifier);
      await controller.saveNew('https://x.com/a', '');
      final result = await controller.saveNew('https://x.com/a', '');
      expect(result, isA<ReferenceSaveFailed>());
    });

    test('double Save saves once', () async {
      final controller = form();
      refs.hold = Completer<void>();
      final first = controller.saveNew('https://x.com/a', 'One');
      final second = controller.saveNew('https://x.com/a', 'One');
      // The second call is the first call's own future.
      expect(identical(first, second), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(saving(), isTrue);
      refs.hold!.complete();
      final results = await Future.wait([first, second]);

      expect(results[0], isA<ReferenceSaved>());
      expect(
        (results[0] as ReferenceSaved).reference.id,
        (results[1] as ReferenceSaved).reference.id,
      );
      expect(refs.adds, 1);
      expect(await stored(), hasLength(1));
      expect(saving(), isFalse);
    });

    test('a save that outlives the sheet still finishes', () async {
      final provider = referenceFormControllerProvider(goa);
      final sub = container.listen(provider, (_, _) {});
      final controller = container.read(provider.notifier);
      refs.hold = Completer<void>();
      final run = controller.saveNew('https://x.com/a', '');
      sub.close();
      await Future<void>.delayed(Duration.zero);
      refs.hold!.complete();

      expect(await run, isA<ReferenceSaved>());
      expect(await stored(), hasLength(1));
    });
  });

  group('saveLabel', () {
    Future<ReelReference> existing([String? label]) async {
      final result = await refs.add(goa, 'https://x.com/a', label: label);
      return (result as ReferenceAdded).reference;
    }

    test('sets the label', () async {
      final ref = await existing('Old');
      expect(await form().saveLabel(ref.id, '  New one '), isTrue);
      expect((await stored()).single.label, 'New one');
    });

    test('a blank label clears it', () async {
      final ref = await existing('Old');
      expect(await form().saveLabel(ref.id, '   '), isTrue);
      expect((await stored()).single.label, isNull);
    });

    test('61 characters is refused and the label stays', () async {
      final ref = await existing('Old');
      expect(await form().saveLabel(ref.id, 'x' * 61), isFalse);
      expect((await stored()).single.label, 'Old');
    });

    test('a reference that is gone is refused', () async {
      expect(await form().saveLabel(999, 'x'), isFalse);
    });

    test('a database failure is refused and the form can try again', () async {
      final ref = await existing('Old');
      final controller = form();
      refs.failWith = StateError('disk full');
      expect(await controller.saveLabel(ref.id, 'New'), isFalse);
      expect(saving(), isFalse);
      refs.failWith = null;
      expect(await controller.saveLabel(ref.id, 'New'), isTrue);
    });

    test('double Save writes once', () async {
      final ref = await existing('Old');
      final controller = form();
      refs.hold = Completer<void>();
      final first = controller.saveLabel(ref.id, 'New');
      final second = controller.saveLabel(ref.id, 'New');
      expect(identical(first, second), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(saving(), isTrue);
      refs.hold!.complete();
      expect(await Future.wait([first, second]), [true, true]);
      expect(refs.labels, 1);
      expect(saving(), isFalse);
    });
  });
}
