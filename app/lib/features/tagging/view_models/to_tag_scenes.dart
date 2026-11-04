import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/domain/rules/scenes.dart';
import 'package:taketray/features/tagging/view_models/to_tag_controller.dart';
import 'package:taketray/features/tagging/view_models/to_tag_times.dart';

part 'to_tag_scenes.g.dart';

/// The waiting clips grouped into scenes (D-95), for To tag: null until the
/// list has been read (loading, or it could not be).
///
/// Each clip is placed by the time where it was shot (D-83), but **the scenes
/// never wait for those times**: until `toTagTimesProvider` has an answer (or
/// when it fails) a clip uses the phone's time, so the list is on screen at
/// once and regroups, in place, when the times arrive.
@riverpod
List<Scene>? toTagScenes(Ref ref) {
  final clips = ref.watch(toTagControllerProvider).value;
  if (clips == null) return null;
  final times = ref.watch(toTagTimesProvider).value ?? const {};
  return groupIntoScenes(clips, times);
}
