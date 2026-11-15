import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

/// A status screen's area: a phone's height (a Galaxy S24 is 780 dp).
const _height = 780.0;

Widget _layout(
  TtStatusTone tone,
  IconData icon,
  String title,
  Widget? body,
  List<Widget> actions,
) => SizedBox(
  height: _height,
  child: TtStatusLayout(
    icon: icon,
    tone: tone,
    title: title,
    body: body,
    actions: actions,
  ),
);

void main() {
  ttGoldenTest(
    'Status layout',
    fileName: 'status_layout',
    scenarios: [
      TtScenario(
        'error: storage full',
        _layout(
          TtStatusTone.error,
          Symbols.sd_card_alert_rounded,
          'Phone storage is full',
          const Text(
            '7 of 12 clips were copied before space ran out. Free up some '
            'space, then try again.',
          ),
          [
            TtButton(label: 'Try again', expand: true, onPressed: () {}),
            TtButton(
              label: 'Delete copies and stop',
              kind: TtButtonKind.text,
              expand: true,
              onPressed: () {},
            ),
          ],
        ),
      ),
      TtScenario(
        'warning: a clip failed',
        _layout(
          TtStatusTone.warning,
          Symbols.warning_rounded,
          "1 clip couldn't be copied",
          const Text(
            'The clip from 9:41 AM may have been deleted or moved. The other '
            '11 clips were copied.',
          ),
          [
            TtButton(
              label: 'Continue with 11 clips',
              expand: true,
              onPressed: () {},
            ),
            TtButton(
              label: 'Cancel',
              kind: TtButtonKind.text,
              expand: true,
              onPressed: () {},
            ),
          ],
        ),
      ),
      TtScenario(
        'primary: copying, no body',
        _layout(
          TtStatusTone.primary,
          Symbols.folder_copy_rounded,
          'Copying clips for VN',
          null,
          [
            TtButton(
              label: 'Cancel',
              kind: TtButtonKind.outlined,
              expand: true,
              onPressed: () {},
            ),
          ],
        ),
      ),
      TtScenario(
        'success: ready',
        _layout(
          TtStatusTone.success,
          Symbols.check_circle_rounded,
          'Ready for VN',
          const Text('In VN, tap New project and open the folder.'),
          [
            TtButton(label: 'Open VN', expand: true, onPressed: () {}),
            TtButton(
              label: 'Done',
              kind: TtButtonKind.text,
              expand: true,
              onPressed: () {},
            ),
          ],
        ),
      ),
    ],
  );
}
