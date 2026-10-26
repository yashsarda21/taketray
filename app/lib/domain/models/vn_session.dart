import 'package:freezed_annotation/freezed_annotation.dart';

part 'vn_session.freezed.dart';
part 'vn_session.g.dart';

/// The folder a reel's clips were copied into for VN.
@freezed
abstract class VnSession with _$VnSession {
  const factory VnSession({
    required int reelId,
    required String folderName,
    required DateTime createdAt,
  }) = _VnSession;

  factory VnSession.fromJson(Map<String, dynamic> json) =>
      _$VnSessionFromJson(json);
}
