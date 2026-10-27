import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:taketray/domain/models/enums.dart';

part 'reel.freezed.dart';
part 'reel.g.dart';

/// A reel the user is collecting clips for. Times are UTC.
@freezed
abstract class Reel with _$Reel {
  const factory Reel({
    required int id,
    required String name,
    required ReelStatus status,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? description,
  }) = _Reel;

  factory Reel.fromJson(Map<String, dynamic> json) => _$ReelFromJson(json);
}
