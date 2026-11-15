import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/clip_ref.dart';
import 'package:taketray/platform/editors_bridge.dart';

import '../support/fake_editors_bridge.dart';

CopyFileRef _ref(int id) =>
    CopyFileRef(mediaStoreId: id, folderName: 'Goa', fileName: '$id.mp4');

void main() {
  late FakeEditorsBridge fake;

  setUp(() => fake = FakeEditorsBridge());

  test('apps answers from installed, icons only for installed ones', () async {
    final icon = Uint8List.fromList([1]);
    fake
      ..installed = {'a': true, 'b': false}
      ..icons = {'a': icon, 'b': icon};
    expect(await fake.apps(['a', 'b', 'c'], iconPx: 48), [
      InstalledApp(packageName: 'a', installed: true, iconPng: icon),
      const InstalledApp(packageName: 'b', installed: false),
      const InstalledApp(packageName: 'c', installed: false),
    ]);
  });

  test('sends are recorded in order with the set result', () async {
    const clip = ClipRef(
      volumeName: 'v',
      mediaStoreId: 1,
      mimeType: 'video/mp4',
    );
    fake.sendResult = SendResult.notInstalled;
    expect(await fake.sendTo('p', [clip]), SendResult.notInstalled);
    expect(await fake.shareWithChooser([clip], 't'), true);
    expect(fake.sent.single.$1, 'p');
    expect(fake.sent.single.$2, [clip]);
    expect(fake.chooserShares.single.$2, 't');
  });

  test('existing and the default delete keep each other in step', () async {
    fake.existing = {1, 2};
    expect(await fake.existingCopies([_ref(1), _ref(3)]), {1});
    expect(
      await fake.deleteCopies([_ref(1), _ref(3)]),
      const DeleteReport(deleted: {1}, gone: {3}),
    );
    expect(fake.existing, {2});
    fake.deleteReport = const DeleteReport(refused: {2});
    expect(
      await fake.deleteCopies([_ref(2)]),
      const DeleteReport(refused: {2}),
    );
    expect(fake.existing, {2});
  });

  test('failNext fails the next call only, and every call is logged', () async {
    fake.failNext('freeBytes');
    await expectLater(fake.freeBytes(), throwsA(isA<PlatformException>()));
    expect(await fake.freeBytes(), fake.bytesFree);
    expect(fake.calls, ['freeBytes', 'freeBytes']);
  });
}
