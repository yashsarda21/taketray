import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

void main() {
  ttGoldenTest(
    'Brand mark',
    fileName: 'brand_mark',
    width: 180,
    scenarios: const [
      TtScenario(
        '28 dp',
        Align(alignment: Alignment.centerLeft, child: TtBrandMark(size: 28)),
      ),
      TtScenario(
        '144 dp',
        Align(alignment: Alignment.centerLeft, child: TtBrandMark(size: 144)),
      ),
    ],
  );
}
