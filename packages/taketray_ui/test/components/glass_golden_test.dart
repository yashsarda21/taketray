import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/fixtures.dart';
import '../support/tt_golden.dart';

void main() {
  ttGoldenTest(
    'Glass panel on a photo',
    fileName: 'glass',
    scenarios: [
      const TtScenario(
        'glass panel',
        _OnPhoto(
          children: [
            TtGlass(
              radius: 20,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('A glass panel over a photo'),
              ),
            ),
          ],
        ),
      ),
      TtScenario(
        'tinted, no shadow, tiny blur',
        _OnPhoto(
          children: [
            Builder(
              builder: (context) => TtGlass(
                radius: 12,
                blur: 2,
                shadow: false,
                tint: context.scheme.primary.withValues(alpha: 0.4),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Tinted'),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// [children] stacked on a sample photo.
class _OnPhoto extends StatelessWidget {
  const new({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      image: DecorationImage(image: fixtureThumb(3), fit: BoxFit.cover),
    ),
    child: Padding(
      padding: EdgeInsets.all(context.tt.spacing.m),
      child: Wrap(
        spacing: context.tt.spacing.xs,
        runSpacing: context.tt.spacing.xs,
        children: children,
      ),
    ),
  );
}
