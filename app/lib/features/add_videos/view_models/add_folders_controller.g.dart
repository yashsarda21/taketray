// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'add_folders_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The folders of Add videos' list (`browseFolders`, D-113, D-114): every
/// folder with videos on every volume, named and in order.
///
/// A failed read is the error state (the screen offers **Try again**,
/// [retry]); [refresh] reads again when the app comes back to the front,
/// keeping the list shown meanwhile.
///
/// It also keeps the previews it was asked for ([previewOf]) for as long as
/// the list lives, so a row scrolled away and back is not read again.

@ProviderFor(AddFoldersController)
final addFoldersControllerProvider = AddFoldersControllerProvider._();

/// The folders of Add videos' list (`browseFolders`, D-113, D-114): every
/// folder with videos on every volume, named and in order.
///
/// A failed read is the error state (the screen offers **Try again**,
/// [retry]); [refresh] reads again when the app comes back to the front,
/// keeping the list shown meanwhile.
///
/// It also keeps the previews it was asked for ([previewOf]) for as long as
/// the list lives, so a row scrolled away and back is not read again.
final class AddFoldersControllerProvider
    extends $AsyncNotifierProvider<AddFoldersController, List<BrowseFolder>> {
  /// The folders of Add videos' list (`browseFolders`, D-113, D-114): every
  /// folder with videos on every volume, named and in order.
  ///
  /// A failed read is the error state (the screen offers **Try again**,
  /// [retry]); [refresh] reads again when the app comes back to the front,
  /// keeping the list shown meanwhile.
  ///
  /// It also keeps the previews it was asked for ([previewOf]) for as long as
  /// the list lives, so a row scrolled away and back is not read again.
  AddFoldersControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'addFoldersControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$addFoldersControllerHash();

  @$internal
  @override
  AddFoldersController create() => AddFoldersController();
}

String _$addFoldersControllerHash() =>
    r'aaee0a801523637d7880e6934e3dc67326d886cf';

/// The folders of Add videos' list (`browseFolders`, D-113, D-114): every
/// folder with videos on every volume, named and in order.
///
/// A failed read is the error state (the screen offers **Try again**,
/// [retry]); [refresh] reads again when the app comes back to the front,
/// keeping the list shown meanwhile.
///
/// It also keeps the previews it was asked for ([previewOf]) for as long as
/// the list lives, so a row scrolled away and back is not read again.

abstract class _$AddFoldersController
    extends $AsyncNotifier<List<BrowseFolder>> {
  FutureOr<List<BrowseFolder>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<BrowseFolder>>, List<BrowseFolder>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<BrowseFolder>>, List<BrowseFolder>>,
              AsyncValue<List<BrowseFolder>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The first [folderPreviewCount] videos of the folder [relativePath] on
/// [volumeName] (newest shot first), for its row's preview. Read only when
/// the row is built, so a long list reads a screenful, and kept by the list
/// ([AddFoldersController.previewOf]), so scrolling back over a row reads
/// nothing. A failure is an error, which the row shows as the folder icon.

@ProviderFor(folderPreview)
final folderPreviewProvider = FolderPreviewFamily._();

/// The first [folderPreviewCount] videos of the folder [relativePath] on
/// [volumeName] (newest shot first), for its row's preview. Read only when
/// the row is built, so a long list reads a screenful, and kept by the list
/// ([AddFoldersController.previewOf]), so scrolling back over a row reads
/// nothing. A failure is an error, which the row shows as the folder icon.

final class FolderPreviewProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<FolderVideo>>,
          List<FolderVideo>,
          FutureOr<List<FolderVideo>>
        >
    with
        $FutureModifier<List<FolderVideo>>,
        $FutureProvider<List<FolderVideo>> {
  /// The first [folderPreviewCount] videos of the folder [relativePath] on
  /// [volumeName] (newest shot first), for its row's preview. Read only when
  /// the row is built, so a long list reads a screenful, and kept by the list
  /// ([AddFoldersController.previewOf]), so scrolling back over a row reads
  /// nothing. A failure is an error, which the row shows as the folder icon.
  FolderPreviewProvider._({
    required FolderPreviewFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: noRetry,
         name: r'folderPreviewProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$folderPreviewHash();

  @override
  String toString() {
    return r'folderPreviewProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<FolderVideo>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<FolderVideo>> create(Ref ref) {
    final argument = this.argument as (String, String);
    return folderPreview(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is FolderPreviewProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$folderPreviewHash() => r'f6952126bc22098464be59cc557a6f2e0f21f05c';

/// The first [folderPreviewCount] videos of the folder [relativePath] on
/// [volumeName] (newest shot first), for its row's preview. Read only when
/// the row is built, so a long list reads a screenful, and kept by the list
/// ([AddFoldersController.previewOf]), so scrolling back over a row reads
/// nothing. A failure is an error, which the row shows as the folder icon.

final class FolderPreviewFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<FolderVideo>>,
          (String, String)
        > {
  FolderPreviewFamily._()
    : super(
        retry: noRetry,
        name: r'folderPreviewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The first [folderPreviewCount] videos of the folder [relativePath] on
  /// [volumeName] (newest shot first), for its row's preview. Read only when
  /// the row is built, so a long list reads a screenful, and kept by the list
  /// ([AddFoldersController.previewOf]), so scrolling back over a row reads
  /// nothing. A failure is an error, which the row shows as the folder icon.

  FolderPreviewProvider call(String volumeName, String relativePath) =>
      FolderPreviewProvider._(argument: (volumeName, relativePath), from: this);

  @override
  String toString() => r'folderPreviewProvider';
}

/// Whether the folder tip "Keep friends' clips sharp" was dismissed on this
/// phone (`PhoneStateRepository.folderTipSeen`, D-114). The screen shows the
/// tip only when this is known to be false.

@ProviderFor(FolderTip)
final folderTipProvider = FolderTipProvider._();

/// Whether the folder tip "Keep friends' clips sharp" was dismissed on this
/// phone (`PhoneStateRepository.folderTipSeen`, D-114). The screen shows the
/// tip only when this is known to be false.
final class FolderTipProvider extends $AsyncNotifierProvider<FolderTip, bool> {
  /// Whether the folder tip "Keep friends' clips sharp" was dismissed on this
  /// phone (`PhoneStateRepository.folderTipSeen`, D-114). The screen shows the
  /// tip only when this is known to be false.
  FolderTipProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'folderTipProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$folderTipHash();

  @$internal
  @override
  FolderTip create() => FolderTip();
}

String _$folderTipHash() => r'1d09d17783cd03078ef873885748902a39f3dc2a';

/// Whether the folder tip "Keep friends' clips sharp" was dismissed on this
/// phone (`PhoneStateRepository.folderTipSeen`, D-114). The screen shows the
/// tip only when this is known to be false.

abstract class _$FolderTip extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
