import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

String _counter(int length, int max) => '$length/$max';

void main() {
  final filled = TextEditingController(text: 'London Food');
  final full = TextEditingController(text: 'a' * 40);
  final long = TextEditingController(text: 'London street food and markets');

  ttGoldenTest(
    'Text field',
    fileName: 'text_field',
    scenarios: [
      const TtScenario(
        'empty with a hint',
        _Pad(TtTextField(label: 'Reel name', hint: 'Name your reel')),
      ),
      TtScenario(
        'filled with helper',
        _Pad(
          TtTextField(
            label: 'Reel name',
            controller: filled,
            helper: 'Press Enter to add the next one',
          ),
        ),
      ),
      const TtScenario(
        'focused',
        _Pad(
          TtTextField(
            label: 'Reel name',
            hint: 'Name your reel',
            autofocus: true,
          ),
        ),
      ),
      TtScenario(
        'counter at 40/40',
        _Pad(
          TtTextField(
            label: 'Reel name',
            controller: full,
            maxLength: 40,
            counterText: _counter,
            helper: 'Up to 40 characters',
          ),
        ),
      ),
      TtScenario(
        'error',
        _Pad(
          TtTextField(
            label: 'Reel name',
            controller: filled,
            error: 'A reel with this name already exists',
            maxLength: 40,
            counterText: _counter,
          ),
        ),
      ),
      const TtScenario(
        'multiline',
        _Pad(
          TtTextField(
            label: 'Notes',
            hint: 'Shot list, ideas',
            multiline: true,
            helper: 'Only you see this',
          ),
        ),
      ),
      TtScenario(
        'long label and text',
        _Pad(
          TtTextField(
            label: 'Name of the reel you are filming this week',
            controller: long,
            error: 'This name is already used by another reel in this tray',
            maxLength: 40,
            counterText: _counter,
          ),
        ),
      ),
    ],
  );
}

class _Pad extends StatelessWidget {
  const new(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: EdgeInsets.all(context.tt.spacing.m), child: child);
}
