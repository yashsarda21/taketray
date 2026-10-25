import 'package:taketray_widgetbook/components/badges.dart';
import 'package:taketray_widgetbook/components/buttons.dart';
import 'package:taketray_widgetbook/components/glass.dart';
import 'package:taketray_widgetbook/components/pill_tabs.dart';
import 'package:taketray_widgetbook/components/rec_dot.dart';
import 'package:taketray_widgetbook/components/selection.dart';
import 'package:taketray_widgetbook/components/text_field.dart';
import 'package:taketray_widgetbook/components/theme.dart';
import 'package:widgetbook/widgetbook.dart';

export 'package:taketray_widgetbook/fixtures.dart';

/// The catalogue's folder tree. Each component file in `lib/components/`
/// contributes one `WidgetbookComponent`; add it here and import its file at
/// the top (the coverage test checks both, D-42).
final List<WidgetbookNode> ttCatalog = [
  WidgetbookFolder(name: 'Foundations', children: [themeComponent]),
  WidgetbookFolder(
    name: 'Controls',
    children: [
      ttButtonComponent,
      ttIconButtonComponent,
      ttFabComponent,
      ttCountBadgeComponent,
      ttRecDotComponent,
      ttSwitchComponent,
      ttMarksComponent,
      ttSuggestionChipComponent,
    ],
  ),
  WidgetbookFolder(name: 'Navigation', children: [ttPillTabsComponent]),
  WidgetbookFolder(name: 'Inputs', children: [ttTextFieldComponent]),
  WidgetbookFolder(
    name: 'Overlays',
    children: [ttGlassComponent, ttGlassPillComponent],
  ),
];
