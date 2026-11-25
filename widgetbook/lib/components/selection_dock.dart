import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtSelectionDock`: the bar at the bottom of a reel page while clips are
/// chosen (D-190). Four actions, then Edit with the length or a note. It
/// slides up when it is first shown; reload the use case to see it again.
final WidgetbookComponent ttSelectionDockComponent = WidgetbookComponent(
  name: 'TtSelectionDock / TtSelectionDockAction / TtSelectionDockEdit',
  useCases: [
    WidgetbookUseCase(
      name: 'Some chosen',
      builder: (context) => _onPage(
        _dock(
          off: false,
          edit: TtSelectionDockEdit(
            label: 'Edit 3 clips',
            detail: '1:38',
            semanticLabel: 'Edit 3 clips, 1:38',
            onPressed: () {},
          ),
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'None chosen',
      builder: (context) => _onPage(
        _dock(
          off: true,
          edit: const TtSelectionDockEdit(
            label: 'Tap the clips you want to edit',
            semanticLabel: 'Edit: choose clips first',
          ),
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Editing session (the note)',
      builder: (context) => _onPage(
        _dock(
          off: false,
          note:
              'This reel is being edited in VN. Tap Done editing at the top '
              'before sending clips again.',
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final chosen = context.knobs.int.slider(
          label: 'chosen clips (0 = none)',
          initialValue: 3,
          max: 12,
        );
        final session = context.knobs.boolean(
          label: 'the reel has an editing session (the note)',
        );
        final waiting = context.knobs.boolean(
          label: 'Edit is off while a session loads',
        );
        return _onPage(
          _dock(
            off: chosen == 0,
            note: session
                ? 'This reel is being edited in VN. Tap Done editing at the '
                      'top before sending clips again.'
                : null,
            edit: session
                ? null
                : TtSelectionDockEdit(
                    label: chosen == 0
                        ? 'Tap the clips you want to edit'
                        : 'Edit $chosen ${chosen == 1 ? 'clip' : 'clips'}',
                    detail: chosen == 0 ? null : '$chosen:38',
                    semanticLabel: chosen == 0
                        ? 'Edit: choose clips first'
                        : 'Edit $chosen clips',
                    onPressed: chosen == 0 || waiting ? null : () {},
                  ),
          ),
        );
      },
    ),
  ],
);

Widget _onPage(Widget dock) =>
    Align(alignment: Alignment.bottomCenter, child: dock);

TtSelectionDock _dock({
  required bool off,
  TtSelectionDockEdit? edit,
  String? note,
}) => TtSelectionDock(
  semanticLabel: 'Chosen clips',
  actions: [
    for (final (icon, label) in [
      (Symbols.share_rounded, 'Share'),
      (Symbols.library_add_rounded, 'Add to'),
      (Symbols.drive_file_move_rounded, 'Move'),
      (Symbols.playlist_remove_rounded, 'Remove'),
    ])
      TtSelectionDockAction(
        icon: icon,
        label: label,
        semanticLabel: label,
        onPressed: off ? null : () {},
      ),
  ],
  edit: edit,
  note: note,
);
