import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

/// The dialog as `.dlg-wrap` places it on a 360 dp screen: 24 dp in, so
/// 312 dp wide.
Widget _placed(Widget dialog) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 24),
  child: Center(child: dialog),
);

void main() {
  ttGoldenTest(
    'Dialog',
    fileName: 'dialog',
    scenarios: [
      TtScenario(
        'two actions',
        _placed(
          const TtDialog<String>(
            title: 'Still shooting?',
            body:
                'Shooting mode has been on for 14 days. While it is on, '
                'every new video goes to To tag.',
            actions: [
              TtDialogAction('keep', 'Keep it on'),
              TtDialogAction('off', 'Turn off'),
            ],
          ),
        ),
      ),
      TtScenario(
        'destructive',
        _placed(
          const TtDialog<String>(
            title: 'Stop copying?',
            body:
                'The 12 copies made so far will be deleted. Your original '
                'clips are not affected.',
            actions: [
              TtDialogAction('keep', 'Keep copying'),
              TtDialogAction('stop', 'Stop', destructive: true),
            ],
          ),
        ),
      ),
      TtScenario(
        'one action',
        _placed(
          const TtDialog<String>(
            title: 'This video can not be played',
            body:
                'It may be damaged, or in a format your phone does not '
                'support. The file is still in your gallery.',
            actions: [TtDialogAction('ok', 'OK')],
          ),
        ),
      ),
      TtScenario(
        'long title and body',
        _placed(
          const TtDialog<String>(
            title: 'Mark Autumn recipes from the farmers market as Ready?',
            body:
                'It moves to the Ready to edit filter, where you can find '
                'it with the other reels that have all their clips. You can '
                'change this any time from the reel page.',
            actions: [
              TtDialogAction('no', 'Not now'),
              TtDialogAction('yes', 'Mark as Ready to edit'),
            ],
          ),
        ),
      ),
      TtScenario(
        'icon and note',
        _placed(
          const TtDialog<String>(
            title: 'Delete London Food?',
            icon: Symbols.delete_rounded,
            content: TtDialogNote(
              text:
                  'Your videos stay in your gallery. Only this reel and its '
                  'tags are removed.',
            ),
            actions: [
              TtDialogAction('cancel', 'Cancel'),
              TtDialogAction('delete', 'Delete reel', destructive: true),
            ],
          ),
        ),
      ),
    ],
  );
}
