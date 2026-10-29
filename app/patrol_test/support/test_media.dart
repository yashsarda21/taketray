import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/platform/media_bridge.dart';

import '../fixtures/test_video.dart';

/// The folder the test videos live in. Nothing else is ever put there, and
/// nothing outside it is ever deleted (D-77).
const String testFolder = 'Movies/TakeTray Test';

/// Test videos in the phone's media library, through the debug-only channel
/// `app.taketray/test_media` (`DebugHooks.kt`, D-77).
///
/// Use [TestMedia.start] at the top of a test: it removes what a crashed run
/// left behind, and registers a tear-down that removes every video this test
/// inserted, even when the test fails.
///
/// The files belong to TakeTray Dev, so the phone asks nothing when they are
/// deleted. A name or path is never printed: failures name the method only.
class TestMedia {
  TestMedia._();

  static const MethodChannel _channel = MethodChannel(
    'app.taketray/test_media',
  );

  final List<InsertedVideo> _inserted = [];
  var _count = 0;

  /// The videos this test inserted and has not deleted.
  List<InsertedVideo> get inserted => List.unmodifiable(_inserted);

  /// Deletes what an earlier crashed run left in the test folder (only rows
  /// TakeTray Dev owns), fails if the folder holds a file it does not own, and
  /// registers the tear-down that deletes everything this test inserts.
  static Future<TestMedia> start() async {
    final media = TestMedia._();
    addTearDown(media.cleanUp);
    final left = await _channel.invokeMapMethod<String, int>('deleteLeftovers');
    final refused = left?['refused'] ?? -1;
    if (refused != 0) {
      throw TestFailure(
        'The test folder holds $refused file(s) that TakeTray Dev does not '
        'own, so the tests cannot start from an empty folder. They may be '
        'left over from before TakeTray Dev was reinstalled: delete the '
        'folder in a file manager.',
      );
    }
    return media;
  }

  /// Puts the test video into the test folder, published (not pending), as
  /// `taketray-test-N.mp4`.
  Future<InsertedVideo> insert() async {
    final reply = await _channel.invokeMapMethod<String, Object?>(
      'insertVideo',
      {'bytes': testVideoBytes, 'displayName': 'taketray-test-${++_count}.mp4'},
    );
    final video = InsertedVideo(
      volumeName: reply!['volumeName']! as String,
      mediaStoreId: (reply['mediaStoreId']! as num).toInt(),
    );
    _inserted.add(video);
    return video;
  }

  /// Deletes [video] from the phone; false if it was gone already.
  Future<bool> delete(InsertedVideo video) async {
    final deleted = await _channel.invokeMethod<bool>('deleteVideo', {
      'mediaStoreId': video.mediaStoreId,
    });
    _inserted.remove(video);
    return deleted ?? false;
  }

  /// Deletes every video this test inserted that is still there. Registered
  /// as a tear-down by [start]; safe to call twice.
  Future<void> cleanUp() async {
    for (final video in List.of(_inserted)) {
      await delete(video);
    }
  }
}

/// A video [TestMedia.insert] made.
class InsertedVideo {
  InsertedVideo({required this.volumeName, required this.mediaStoreId});

  final String volumeName;
  final int mediaStoreId;
}

/// What the bridge says about [video] right now: its row, or null if the
/// phone has no such video.
Future<MediaVideo?> rowOf(MediaBridge bridge, InsertedVideo video) async {
  final rows = await bridge.videosByIds(video.volumeName, [video.mediaStoreId]);
  return rows.isEmpty ? null : rows.single;
}
