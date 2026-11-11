import 'package:drift/drift.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/domain/models/enums.dart';

/// True for a clip that has a picture to show: a clip that is not missing
/// and is either a MediaStore clip that holds a MediaStore number above 0 on a
/// volume, or a picked clip with a picker address (Phase 7, D-84 point 3).
///
/// A detached clip holds `-id` and is missing, and a missing picked clip's
/// grant or video is gone, so neither is offered. The one rule for the
/// Shooting mode card's backdrop (`ClipsRepository.watchFirstShowableClip`)
/// and a reel card's cover (`ReelsRepository.watchReelSummaries`); a clip it
/// passes has a `ClipThumbnailKey` (D-74). [c] may be an alias of `clips`.
Expression<bool> hasPicture($ClipsTable c) =>
    c.missing.equals(false) &
    ((c.source.equalsValue(ClipSource.mediaStore) &
            c.volumeName.isNotNull() &
            c.mediaStoreId.isBiggerThanValue(0)) |
        (c.source.equalsValue(ClipSource.picker) &
            c.pickerUri.isNotNull() &
            c.pickerUri.equals('').not()));
