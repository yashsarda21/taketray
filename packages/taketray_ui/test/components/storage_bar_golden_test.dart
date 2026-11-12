import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

/// The width of the bar on a screen with 24 dp margins.
const _bar = 312.0;

void main() {
  ttGoldenTest(
    'Storage bar',
    fileName: 'storage_bar',
    scenarios: [
      const TtScenario(
        'enough, a small share',
        TtStorageBar.enough(
          needFraction: 0.3,
          needLabel: 'Copies: 1.2 GB',
          freeAfterLabel: 'Free after copying: 3.1 GB',
          semanticLabel: 'Free space 4.3 GB, copies need 1.2 GB',
        ),
        width: _bar,
      ),
      const TtScenario(
        'enough, the 4 % minimum',
        TtStorageBar.enough(
          needFraction: 0.002,
          needLabel: 'Copies: 8 MB',
          freeAfterLabel: 'Free after copying: 4.2 GB',
          semanticLabel: 'Free space 4.2 GB, copies need 8 MB',
        ),
        width: _bar,
      ),
      const TtScenario(
        'enough, nearly all of it',
        TtStorageBar.enough(
          needFraction: 0.97,
          needLabel: 'Copies: 4.1 GB',
          freeAfterLabel: 'Free after copying: 120 MB',
          semanticLabel: 'Free space 4.2 GB, copies need 4.1 GB',
        ),
        width: _bar,
      ),
      const TtScenario(
        'short, about half',
        TtStorageBar.short(
          haveFraction: 0.6,
          haveLabel: 'You have 1.8 GB',
          shortLabel: 'Short by 1.2 GB',
          semanticLabel: 'Copies need 3 GB, you have 1.8 GB, short by 1.2 GB',
        ),
        width: _bar,
      ),
      const TtScenario(
        'short, nothing to spare',
        TtStorageBar.short(
          haveFraction: 0,
          haveLabel: 'You have 0 MB',
          shortLabel: 'Short by 3 GB',
          semanticLabel: 'Copies need 3 GB, you have 0 MB, short by 3 GB',
        ),
        width: _bar,
      ),
      const TtScenario(
        'short, just under',
        TtStorageBar.short(
          haveFraction: 0.95,
          haveLabel: 'You have 2.85 GB',
          shortLabel: 'Short by 150 MB',
          semanticLabel: 'Copies need 3 GB, you have 2.85 GB, short by 150 MB',
        ),
        width: _bar,
      ),
    ],
  );
}
