import 'package:flutter/foundation.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/enums.dart';

/// How the native side finds a clip's video: a detected clip by volume and
/// MediaStore id, a picked one by its picker address (D-119).
///
/// Exactly one of the two identities is set. A picked clip never carries a
/// volume or an id, even when its [Clip] row has them, because a picked
/// clip is read only through its saved grant (D-57).
@immutable
class ClipRef {
  const ClipRef({
    required this.mimeType,
    this.volumeName,
    this.mediaStoreId,
    this.pickerUri,
  });

  factory ClipRef.of(Clip clip) {
    if (clip.source == ClipSource.picker) {
      return ClipRef(pickerUri: clip.pickerUri, mimeType: clip.mimeType);
    }
    return ClipRef(
      volumeName: clip.volumeName,
      mediaStoreId: clip.mediaStoreId,
      mimeType: clip.mimeType,
    );
  }

  final String? volumeName;
  final int? mediaStoreId;
  final String? pickerUri;
  final String mimeType;

  @override
  bool operator ==(Object other) =>
      other is ClipRef &&
      other.volumeName == volumeName &&
      other.mediaStoreId == mediaStoreId &&
      other.pickerUri == pickerUri &&
      other.mimeType == mimeType;

  @override
  int get hashCode =>
      Object.hash(volumeName, mediaStoreId, pickerUri, mimeType);

  // No picker address or MIME type in a log line (D-10).
  @override
  String toString() => 'ClipRef(${pickerUri != null ? 'picked' : 'detected'})';
}
