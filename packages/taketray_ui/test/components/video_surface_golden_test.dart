import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/fixtures.dart';
import '../support/tt_golden.dart';

void main() {
  // The video theme is always dark, so the light shot shows the same dark
  // chrome as the dark one ("always dark, on black").
  ttGoldenTest(
    'Video surface',
    fileName: 'video_surface',
    scenarios: [
      const TtScenario(
        'black, no scrims',
        TtVideoSurface(child: SizedBox(height: 64, child: _Label('On black'))),
      ),
      TtScenario(
        'scrims over a bright photo',
        TtVideoSurface(
          scrims: true,
          child: SizedBox(
            height: 400,
            child: Image(image: fixtureThumb(2), fit: BoxFit.cover),
          ),
        ),
      ),
    ],
  );
}

class _Label extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(
      text,
      style: context.tt.text.material.bodyMedium!.copyWith(
        color: context.tt.colors.onVideo,
      ),
    ),
  );
}
