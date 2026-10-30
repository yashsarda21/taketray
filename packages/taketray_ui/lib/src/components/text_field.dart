import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// The TakeTray text field: an outlined box whose label sits on its top edge,
/// with a help row underneath.
///
/// Built on Material's [TextField]. The border is 1 dp, and 2 dp in the
/// primary colour while focused or in the error colour while [error] is
/// given. The help row shows [helper], or the [error] with an error icon in
/// its place, and an `n/max` counter on the right when [maxLength] is given;
/// [maxLength] also refuses input past it.
class TtTextField extends StatefulWidget {
  /// A field named [label].
  const new({
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.error,
    this.maxLength,
    this.counterText,
    this.multiline = false,
    this.autofocus = false,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    super.key,
  }) : assert(
         maxLength == null || counterText != null,
         'A field with a maxLength needs a counterText',
       );

  /// The label on the box's top edge.
  final String label;

  /// Holds the text, or null for the field to keep its own.
  final TextEditingController? controller;

  /// Shown inside the empty box.
  final String? hint;

  /// A line of help under the box.
  final String? helper;

  /// What is wrong, or null if nothing is. Replaces [helper] and turns the
  /// box red.
  final String? error;

  /// The most characters accepted, or null for no limit. Shows the counter.
  final int? maxLength;

  /// The counter's text for the text's length and [maxLength], or null when
  /// there is no [maxLength]. The caller supplies it so that the package
  /// composes no user-facing string (for example `'$length/$max'`).
  final String Function(int length, int max)? counterText;

  /// Whether the box is several lines tall and Enter starts a new line.
  final bool multiline;

  /// Whether the field takes focus when it first appears.
  final bool autofocus;

  /// What the keyboard's action key does.
  final TextInputAction? textInputAction;

  /// Called with the text after each edit.
  final ValueChanged<String>? onChanged;

  /// Called with the text when the keyboard's action key is pressed.
  final ValueChanged<String>? onSubmitted;

  @override
  State<TtTextField> createState() => _TtTextFieldState();
}

class _TtTextFieldState extends State<TtTextField> {
  TextEditingController? _own;

  TextEditingController get _controller =>
      widget.controller ?? (_own ??= TextEditingController());

  @override
  void didUpdateWidget(TtTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.controller;
    final given = widget.controller;
    if (old == null && given != null) {
      // From the field's own controller to the caller's: the caller's text
      // wins, unless it is empty, in which case the typed text moves over. The
      // move waits for the end of the frame: the caller's listeners must not
      // be told of a change in the middle of a build.
      final typed = _own?.value;
      if (typed != null && typed.text.isNotEmpty && given.text.isEmpty) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.controller == given && given.text.isEmpty) {
            given.value = typed;
          }
        });
      }
      _own?.dispose();
      _own = null;
    } else if (old != null && given == null) {
      // From the caller's controller to the field's own: keep what showed.
      _own = TextEditingController.fromValue(old.value);
    }
    // From one given controller to another, the caller owns both.
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final text = tt.text.material;
    final hasError = widget.error != null;

    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(TtMetrics.textFieldRadius),
      borderSide: BorderSide(color: color, width: width),
    );
    // proto.css: .tf .box, .tf.focus .box, .tf.err .box
    final rest = hasError
        ? border(scheme.error, TtMetrics.textFieldBorderActive)
        : border(scheme.outline, TtMetrics.textFieldBorder);
    final focused = border(
      hasError ? scheme.error : scheme.primary,
      TtMetrics.textFieldBorderActive,
    );
    // The floating label is drawn at 3/4 of its style's size: bodyLarge
    // (16 sp) gives the prototype's 12 sp body-small label.
    final labelStyle = WidgetStateTextStyle.resolveWith((states) {
      final color = hasError
          ? scheme.error
          : states.contains(WidgetState.focused)
          ? scheme.primary
          : scheme.onSurfaceVariant;
      return text.bodyLarge!.copyWith(color: color);
    });

    final counter = widget.maxLength == null
        ? null
        : ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => Text(
              widget.counterText!(
                _controller.text.characters.length,
                widget.maxLength!,
              ),
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          );
    final helpText = hasError ? widget.error : widget.helper;

    // proto.css: .tf { margin-top: 8px } leaves room for the label, which
    // sits half above the box.
    return Padding(
      padding: EdgeInsets.only(top: tt.spacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The error goes into the field's own semantics as well, so a screen
          // reader reads it with the field (Material does the same for its
          // own errorText).
          Semantics(
            hint: widget.error,
            child: TextField(
              controller: _controller,
              autofocus: widget.autofocus,
              minLines: widget.multiline
                  ? TtMetrics.textFieldMultilineLines.toInt()
                  : null,
              maxLines: widget.multiline
                  ? TtMetrics.textFieldMultilineMaxLines.toInt()
                  : 1,
              keyboardType: widget.multiline ? TextInputType.multiline : null,
              textInputAction: widget.textInputAction,
              maxLength: widget.maxLength,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              cursorColor: scheme.primary,
              style: text.bodyLarge,
              decoration: InputDecoration(
                labelText: widget.label,
                hintText: widget.hint,
                // The counter is drawn in the help row, not by Material.
                counterText: '',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                labelStyle: labelStyle,
                floatingLabelStyle: labelStyle,
                hintStyle: text.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                contentPadding: const EdgeInsets.all(
                  TtMetrics.textFieldPadding,
                ),
                enabledBorder: rest,
                border: rest,
                focusedBorder: focused,
              ),
            ),
          ),
          if (helpText != null || counter != null)
            Padding(
              padding: const EdgeInsets.only(
                top: TtMetrics.textFieldHelpGap,
                left: TtMetrics.textFieldHelpPaddingHorizontal,
                right: TtMetrics.textFieldHelpPaddingHorizontal,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: helpText == null
                        ? const SizedBox.shrink()
                        : _HelpText(text: helpText, isError: hasError),
                  ),
                  if (counter != null) ...[
                    SizedBox(width: tt.spacing.xs),
                    counter,
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The help row's text; an error also shows the error icon and is announced.
class _HelpText extends StatelessWidget {
  const new({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final color = isError ? scheme.error : scheme.onSurfaceVariant;
    final style = context.tt.text.material.bodySmall?.copyWith(color: color);
    return Semantics(
      liveRegion: isError,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isError) ...[
            // body-small's 16 dp line is as tall as the icon, and both grow
            // with the text size.
            Icon(
              Symbols.error_rounded,
              fill: 1,
              size: MediaQuery.textScalerOf(context)
                  .scale(TtMetrics.textFieldHelpIconSize),
              color: color,
            ),
            const SizedBox(width: TtMetrics.textFieldHelpIconGap),
          ],
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}
