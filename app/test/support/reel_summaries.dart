import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/reel_summary.dart';

/// A [ReelSummary] for a screen test: reel [id] named [name] (default
/// "Reel {id}"), created on day [id] of October 2026 so that a higher id is
/// newer.
ReelSummary testSummary(
  int id, {
  String? name,
  ReelStatus status = ReelStatus.collecting,
  int clipCount = 0,
  int missingCount = 0,
  int liveDurationMs = 0,
  Clip? cover,
}) {
  final created = DateTime.utc(2026, 10).add(Duration(days: id));
  return ReelSummary(
    reel: Reel(
      id: id,
      name: name ?? 'Reel $id',
      status: status,
      createdAt: created,
      updatedAt: created,
    ),
    clipCount: clipCount,
    missingCount: missingCount,
    liveDurationMs: liveDurationMs,
    cover: cover,
  );
}
