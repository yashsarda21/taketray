import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The line a sheet shows for **its own** failure, above its buttons (D-85).
///
/// A sheet is modal: a snack shown while it is open lies behind the sheet and
/// its scrim, where nobody sees it. So a failure that keeps the sheet open
/// (the save did not work, the text is kept) is told **in the sheet**, and
/// snacks are for after it has closed.
///
/// It is a warning [TtBanner]: the error colours, the error icon (never
/// colour alone) and a live region, so a screen reader announces it when it
/// appears. Put it in the `TtSheet.footer`, above the `TtButtonRow`, and show
/// it only while the failure stands: clear it on the next attempt and on the
/// next edit.
class SheetFailure extends StatelessWidget {
  /// A failure line saying [message].
  const new({required this.message, super.key});

  /// What went wrong, in words.
  final String message;

  @override
  Widget build(BuildContext context) => TtBanner(
    kind: TtBannerKind.warning,
    icon: Symbols.error_rounded,
    title: message,
  );
}

/// A sheet footer: [buttons], with a [SheetFailure] saying [failure] above
/// them when it is not null.
class SheetFooter extends StatelessWidget {
  /// A footer of [buttons].
  const new({required this.buttons, this.failure, super.key});

  /// The sheet's `TtButtonRow`.
  final Widget buttons;

  /// The failure to show, or null for none.
  final String? failure;

  @override
  Widget build(BuildContext context) {
    final failure = this.failure;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: context.tt.spacing.s,
      children: [
        if (failure != null) SheetFailure(message: failure),
        buttons,
      ],
    );
  }
}
