import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

Widget _chevron() => const Icon(Symbols.chevron_right_rounded);

Widget _switch(bool on, String label) =>
    TtSwitch(value: on, onChanged: (_) {}, semanticLabel: label);

TtListRow _reminder() => TtListRow(
  title: 'Evening reminder',
  subtitle: '9:00 PM, only if clips are waiting',
  leading: const TtRowIcon(icon: Symbols.bedtime_rounded, boxed: false),
  trailing: _switch(true, 'Evening reminder'),
);

TtListRow _folders() => TtListRow(
  title: 'Watched folders',
  subtitle: 'Camera, Download',
  leading: const TtRowIcon(icon: Symbols.folder_open_rounded, boxed: false),
  trailing: _chevron(),
  onTap: () {},
);

void main() {
  ttGoldenTest(
    'Grouped rows',
    fileName: 'grouped_rows',
    scenarios: [
      TtScenario(
        '1 row, switch, with label',
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TtGroupLabel('Shooting mode'),
            TtGroupedRows(
              children: [
                TtListRow(
                  title: 'Remind me to turn it off',
                  subtitle: 'If Shooting mode stays on for 14 days',
                  leading: const TtRowIcon(
                    icon: Symbols.timer_rounded,
                    boxed: false,
                  ),
                  trailing: _switch(false, 'Remind me to turn it off'),
                ),
              ],
            ),
          ],
        ),
      ),
      TtScenario(
        '2 rows, switch and chevron',
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TtGroupLabel('Reminders'),
            TtGroupedRows(
              children: [
                _reminder(),
                TtListRow(
                  title: 'Reminder time',
                  subtitle: '9:00 PM',
                  leading: const TtRowIcon(
                    icon: Symbols.schedule_rounded,
                    boxed: false,
                  ),
                  trailing: _chevron(),
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
      TtScenario(
        '4 rows, switch, chevron, value',
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TtGroupLabel('Permissions'),
            TtGroupedRows(
              children: [
                const TtListRow(
                  title: 'Video access',
                  subtitle: 'All videos',
                  leading: TtRowIcon(
                    icon: Symbols.photo_library_rounded,
                    boxed: false,
                  ),
                  trailing: Icon(Symbols.check_circle_rounded, fill: 1),
                ),
                _folders(),
                _reminder(),
                const TtListRow(
                  title: 'Notifications',
                  leading: TtRowIcon(
                    icon: Symbols.notifications_rounded,
                    boxed: false,
                  ),
                  trailing: Text('Allowed'),
                ),
              ],
            ),
          ],
        ),
      ),
      TtScenario(
        'boxed icons',
        TtGroupedRows(
          children: [
            TtListRow(
              title: 'Camera',
              subtitle: 'DCIM/Camera · 128 videos',
              leading: const TtRowIcon(icon: Symbols.photo_camera_rounded),
              trailing: _switch(true, 'Watch Camera'),
            ),
            TtListRow(
              title: 'Download',
              subtitle: 'Download · 12 videos',
              leading: const TtRowIcon(icon: Symbols.folder_rounded),
              trailing: _switch(false, 'Watch Download'),
            ),
          ],
        ),
      ),
      TtScenario(
        'long text',
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TtGroupLabel('Help'),
            TtGroupedRows(
              children: [
                TtListRow(
                  title: 'Notifications not arriving on this phone at all?',
                  subtitle:
                      'Steps for Samsung, Xiaomi, Realme and other phones '
                      'that stop apps in the background',
                  leading: const TtRowIcon(
                    icon: Symbols.notifications_off_rounded,
                    boxed: false,
                  ),
                  trailing: _chevron(),
                  onTap: () {},
                ),
                TtListRow(
                  title: 'Storage used by VN copies',
                  subtitle: '1.2 GB in 3 reels',
                  leading: const TtRowIcon(
                    icon: Symbols.sd_storage_rounded,
                    boxed: false,
                  ),
                  trailing: _chevron(),
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}
