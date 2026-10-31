import 'package:taketray/domain/models/clip.dart';

/// [clips] in shooting order: oldest date taken first, then the lower id. A
/// new list; [clips] is not changed.
///
/// To tag's list, the tag player's session and the scenes (`groupIntoScenes`)
/// all use this one order, so a tile, a scene and the player agree on which
/// clip is next. It sorts on the UTC instant, so clips shot in different
/// zones are in the order they happened.
List<Clip> inShootingOrder(List<Clip> clips) => [...clips]
  ..sort((a, b) {
    final byDate = a.fingerprint.dateTakenUtc.compareTo(
      b.fingerprint.dateTakenUtc,
    );
    return byDate != 0 ? byDate : a.id.compareTo(b.id);
  });
