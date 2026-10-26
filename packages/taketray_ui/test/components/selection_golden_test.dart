import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

void main() {
  ttGoldenTest(
    'Switch',
    fileName: 'switch',
    scenarios: [
      TtScenario('off', _switch(value: false)),
      TtScenario('on', _switch(value: true)),
      TtScenario('disabled off', _switch(value: false, enabled: false)),
      TtScenario('disabled on', _switch(value: true, enabled: false)),
      TtScenario('inverted off', _switch(value: false, inverted: true)),
      TtScenario('inverted on', _switch(value: true, inverted: true)),
    ],
  );

  ttGoldenTest(
    'Check and radio marks',
    fileName: 'marks',
    scenarios: const [
      TtScenario(
        'check on / off',
        _Row([TtCheckMark(checked: true), TtCheckMark(checked: false)]),
      ),
      TtScenario(
        'radio on / off',
        _Row([TtRadioMark(selected: true), TtRadioMark(selected: false)]),
      ),
    ],
  );
}

Widget _switch({
  required bool value,
  bool enabled = true,
  bool inverted = false,
}) {
  final s = TtSwitch(
    value: value,
    inverted: inverted,
    semanticLabel: 'Keep screen on',
    onChanged: enabled ? (_) {} : null,
  );
  // The inverted switch lives on the black Shooting mode card.
  return inverted ? _Card(child: s) : _Row([s]);
}

class _Row extends StatelessWidget {
  const new(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(context.tt.spacing.m),
    child: Row(spacing: context.tt.spacing.m, children: children),
  );
}

class _Card extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.tt.colors.videoBackground,
    child: _Row([child]),
  );
}
