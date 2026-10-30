import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

Widget _rows(List<TtListRow> rows) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [TtGroupedRows(children: rows)],
);

TtListRow _today({
  required Widget? count,
  bool off = false,
  bool loading = false,
  VoidCallback? onTap,
}) => TtListRow(
  title: 'Today',
  subtitle: 'Wed, Oct 28',
  tall: true,
  leading: const TtRowIcon(icon: Symbols.today_rounded, boxed: false),
  trailing: loading ? const TtSkeletonCount() : count,
  stackTrailingAtLargeText: true,
  off: off,
  onTap: off ? null : onTap,
);

TtListRow _choose({
  String subtitle = 'Up to 10 years back',
  bool busy = false,
  bool off = false,
}) => TtListRow(
  title: 'Choose dates…',
  subtitle: subtitle,
  tall: true,
  leading: const TtRowIcon(icon: Symbols.edit_calendar_rounded, boxed: false),
  trailing: busy
      ? const TtRowSpinner(semanticLabel: 'Checking your videos')
      : const Icon(Symbols.chevron_right_rounded),
  off: off,
  onTap: off ? null : () {},
);

void main() {
  ttGoldenTest(
    'Add earlier videos rows',
    fileName: 'earlier_rows',
    // The spinners never settle: decode, then show them 0.3 s into a turn.
    pumpBeforeTest: (tester) async {
      await ttDecodeImages(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    },
    scenarios: [
      TtScenario(
        'Today has new videos',
        _rows([
          _today(count: const TtRowCount('3 new'), onTap: () {}),
          _choose(),
        ]),
      ),
      TtScenario(
        'Today: none (off)',
        _rows([
          _today(count: const TtRowCount('none', pill: false), off: true),
          _choose(),
        ]),
      ),
      TtScenario(
        'Today off with a count (outlined)',
        _rows([
          _today(count: const TtRowCount('3 new'), off: true),
          _choose(off: true),
        ]),
      ),
      TtScenario(
        'loading the counts',
        _rows([
          _today(count: null, loading: true, off: true),
          _choose(off: true),
        ]),
      ),
      TtScenario(
        'counting the chosen dates',
        _rows([
          _today(count: const TtRowCount('3 new'), off: true),
          _choose(
            subtitle: 'Oct 8 – Oct 10 · Checking…',
            busy: true,
            off: true,
          ),
        ]),
      ),
      TtScenario(
        'adding Today',
        _rows([
          _today(
            count: const Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                TtRowCount('Adding…', pill: false),
                TtRowSpinner(semanticLabel: 'Adding'),
              ],
            ),
            off: true,
          ),
          _choose(off: true),
        ]),
      ),
    ],
  );
}
