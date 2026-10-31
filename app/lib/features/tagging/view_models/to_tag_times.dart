import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/data/media/clip_time.dart';
import 'package:taketray/features/tagging/view_models/to_tag_controller.dart';

part 'to_tag_times.g.dart';

/// The time where each waiting clip was shot, by clip id (D-83): what the To
/// tag tiles show.
///
/// It follows the To tag list (`ToTagController`): each new list asks
/// `ClipTimeService.localTimes`, whose cache answers the clips it has seen,
/// so only new ones cost a bridge entry. The service never throws; a clip
/// missing from the map (a list that arrived while its times are still being
/// read) shows the phone's time.
@riverpod
Future<Map<int, ClipLocalTime>> toTagTimes(Ref ref) async {
  final service = ref.watch(clipTimeServiceProvider);
  final clips = await ref.watch(toTagControllerProvider.future);
  return await service.localTimes(clips);
}
