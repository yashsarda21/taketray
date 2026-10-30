import 'package:drift/drift.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/domain/models/enums.dart';

/// True for a clip that has a picture to show: a MediaStore clip that is not
/// missing and holds a MediaStore number above 0 on a volume.
///
/// A detached clip holds `-id` and is missing, and a picked clip has no
/// picture to ask for (D-74), so neither is offered. The one rule for the
/// Shooting mode card's backdrop (`ClipsRepository.watchFirstShowableClip`)
/// and a reel card's cover (`ReelsRepository.watchReelSummaries`). [c] may be
/// an alias of `clips`.
Expression<bool> hasPicture($ClipsTable c) =>
    c.missing.equals(false) &
    c.source.equalsValue(ClipSource.mediaStore) &
    c.volumeName.isNotNull() &
    c.mediaStoreId.isBiggerThanValue(0);
