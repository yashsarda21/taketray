import 'package:flutter/material.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// How a [TtStatusLayout] feels: the colour of its icon.
enum TtStatusTone {
  /// Something is going on, such as copying (the primary colour).
  primary,

  /// Something failed, such as a full phone (the error colour).
  error,

  /// Something needs a look but is not fatal, such as one clip that could not
  /// be copied (the tertiary colour).
  warning,

  /// It worked (the success colour).
  success,
}

/// A whole-screen status: a big [icon] in the colour of its [tone], a
/// [title], an optional [body] and, at the bottom, a column of [actions].
///
/// The icon, title and body are centred as one block in the space above the
/// actions, 12 dp apart, with 32 dp at the sides. When the text is large and
/// the block is taller than the space, it scrolls and the actions stay in
/// view. The actions are as wide as the screen less 16 dp each side, 8 dp
/// apart, with 16 dp under them (and the system bars' inset); give them
/// `TtButton`s. The title is a heading for a screen reader; the icon is
/// decoration and is hidden from it.
///
/// A plain `Text` [body] is drawn in body-medium on-surface-variant,
/// centred; any other widget, such as a progress bar, is placed as given.
/// The layout fills the height it is given, so use it as the body of a
/// screen.
class TtStatusLayout extends StatelessWidget {
  /// A status screen.
  const new({
    required this.icon,
    required this.tone,
    required this.title,
    required this.actions,
    this.body,
    super.key,
  });

  /// The big glyph above the title.
  final IconData icon;

  /// Which colour the [icon] has.
  final TtStatusTone tone;

  /// What happened, such as "Phone storage is full".
  final String title;

  /// More words (or a progress bar) under the title, or null for none.
  final Widget? body;

  /// The buttons at the bottom, top to bottom; none is allowed.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final text = tt.text.material;
    final color = switch (tone) {
      TtStatusTone.primary => scheme.primary,
      TtStatusTone.error => scheme.error,
      // screens.js: routes['vn-copy'] uses var(--md-tertiary) for the warning.
      TtStatusTone.warning => scheme.tertiary,
      TtStatusTone.success => tt.colors.success,
    };
    final body = this.body;
    // screens.js: routes['vn-copy']: `flex:1; display:flex; column;
    // align-items:center; justify-content:center; text-align:center; gap:12px;
    // padding:24px 32px`, then the buttons: `padding:12px 16px 16px; gap:8px`.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: tt.spacing.xxl,
                      vertical: tt.spacing.xl,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: tt.spacing.s,
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            icon,
                            size: TtMetrics.statusIconSize,
                            color: color,
                          ),
                        ),
                        Semantics(
                          header: true,
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: text.headlineSmall!.copyWith(
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        if (body != null)
                          DefaultTextStyle.merge(
                            style: text.bodyMedium!.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                            child: body,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (actions.isNotEmpty)
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                tt.spacing.m,
                tt.spacing.s,
                tt.spacing.m,
                tt.spacing.m,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: tt.spacing.xs,
                children: actions,
              ),
            ),
          ),
      ],
    );
  }
}
