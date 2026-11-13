import 'package:flutter/material.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/features/editors/views/editor_text.dart';
import 'package:taketray/features/reels/view_models/reel_edit_state.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/copy_bridge.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The banner of a reel that is being edited (D-128; `screens.js`:
/// `routes.reel`, `.banner.vn`), between the reel's header and its clips. A
/// `TtBanner` of the `vn` kind: its actions are always under the text.
///
/// - **VN:** "Editing in VN · {size}" over "{n} copies in
///   Movies/TakeTray/{folder}", with **Done editing** and **Add more clips**.
/// - **CapCut or Edits:** "Editing in CapCut" (with " · {size}" when the
///   folder holds copies) over "Sent on {date}" (with " · {n} copies in
///   Movies/TakeTray/{folder}"), with **Done editing** only (adding more is
///   Task 12's, after the owner's gate).
/// - **While a copy job of the reel runs** ([job]): "Copying clips for
///   {editor}" over "{done} of {total} clips", and **Show** in place of the
///   actions: Done editing is not offered while the job runs
///   (`doneEditing` would refuse it).
///
/// Nothing (an empty box) when there is neither a session nor a job. The
/// folder is the session's (a renamed reel keeps it); [today] decides
/// whether the date shows its year.
class ReelEditBanner extends StatelessWidget {
  /// The banner of [edit], or of the running [job].
  const ReelEditBanner({
    required this.edit,
    required this.job,
    required this.today,
    required this.onDoneEditing,
    required this.onAddMore,
    required this.onShowJob,
    super.key,
  });

  /// The session and its copies, or null.
  final ReelEditState? edit;

  /// The reel's copy job while it runs, or null.
  final CopyJob? job;

  /// The phone's local day now.
  final DateTime today;

  final VoidCallback onDoneEditing;
  final VoidCallback onAddMore;
  final VoidCallback onShowJob;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final edit = this.edit;
    final job = this.job;
    if (job != null) {
      return TtBanner(
        kind: TtBannerKind.vn,
        icon: Symbols.folder_copy_rounded,
        title: l10n.copyProgressTitle(
          editorShortName(l10n, edit?.editor ?? EditorApp.vn),
        ),
        body: l10n.copyProgressCount(job.done, job.total),
        action: TtButton(
          label: l10n.reelCopyShow,
          kind: TtButtonKind.text,
          size: TtButtonSize.small,
          onPressed: onShowJob,
        ),
      );
    }
    if (edit == null) return const SizedBox.shrink();

    final editor = editorShortName(l10n, edit.editor);
    final size = byteSizeText(l10n, edit.copyBytes);
    final folder = edit.session.folderName;
    final copies = edit.copyCount;
    final vn = edit.editor == EditorApp.vn;
    final sentOn = ttDayText(
      context,
      edit.session.createdAt.toLocal(),
      today: today,
    );
    final done = TtButton(
      label: l10n.reelDoneEditing,
      size: TtButtonSize.small,
      onPressed: onDoneEditing,
    );
    return TtBanner(
      kind: TtBannerKind.vn,
      icon: Symbols.folder_copy_rounded,
      title: vn || copies > 0
          ? l10n.reelEditingInSize(editor, size)
          : l10n.reelEditingIn(editor),
      body: vn
          ? l10n.reelEditingCopies(copies, folder)
          : copies > 0
          ? l10n.reelEditingSentOnCopies(sentOn, copies, folder)
          : l10n.reelEditingSentOn(sentOn),
      action: vn
          ? Wrap(
              spacing: context.tt.spacing.xs,
              runSpacing: context.tt.spacing.xxs,
              children: [
                done,
                TtButton(
                  label: l10n.reelAddMoreClips,
                  kind: TtButtonKind.text,
                  size: TtButtonSize.small,
                  onPressed: onAddMore,
                ),
              ],
            )
          : done,
    );
  }
}
