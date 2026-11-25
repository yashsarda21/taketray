import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

void main() {
  ttGoldenTest(
    'Selection dock',
    fileName: 'selection_dock',
    scenarios: [
      TtScenario('some chosen', _dock()),
      TtScenario(
        'none chosen',
        _dock(
          off: true,
          edit: const TtSelectionDockEdit(
            label: 'Tap the clips you want to edit',
            semanticLabel: 'Edit: choose clips first',
          ),
        ),
      ),
      TtScenario(
        'editing session',
        _dock(
          note:
              'This reel is being edited in VN. Tap Done editing at the top '
              'before sending clips again.',
        ),
      ),
    ],
  );
}

TtSelectionDock _dock({
  bool off = false,
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
        semanticLabel: '$label 3 clips',
        onPressed: off ? null : () {},
      ),
  ],
  edit:
      edit ??
      (note == null
          ? TtSelectionDockEdit(
              label: 'Edit 3 clips',
              detail: '1:38',
              semanticLabel: 'Edit 3 clips, 1:38',
              onPressed: () {},
            )
          : null),
  note: note,
);
