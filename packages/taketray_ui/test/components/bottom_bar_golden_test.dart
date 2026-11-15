import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

TtBottomBar _bar(
  String title,
  String subtitle,
  String action, {
  bool on = true,
}) => TtBottomBar(
  title: title,
  subtitle: subtitle,
  action: TtButton(label: action, onPressed: on ? () {} : null),
);

void main() {
  ttGoldenTest(
    'Bottom bar',
    fileName: 'bottom_bar',
    scenarios: [
      TtScenario(
        'videos picked',
        _bar(
          '3 videos picked',
          '1 min 20 s · added in shooting order',
          'Add 3',
        ),
      ),
      TtScenario(
        'none picked, the button off',
        _bar(
          'No videos picked',
          'Videos already added are marked',
          'Add',
          on: false,
        ),
      ),
      TtScenario(
        'clips to edit',
        _bar(
          '12 clips · 2 min 40 s',
          'Tap the clips you want to edit',
          'Continue',
        ),
      ),
      TtScenario(
        'long text',
        _bar(
          '4 new clips to copy',
          '1.2 GB · copies are added, never renamed',
          'Copy',
        ),
      ),
    ],
  );
}
