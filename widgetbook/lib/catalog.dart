import 'package:taketray_widgetbook/components/app_bar.dart';
import 'package:taketray_widgetbook/components/badges.dart';
import 'package:taketray_widgetbook/components/banners.dart';
import 'package:taketray_widgetbook/components/buttons.dart';
import 'package:taketray_widgetbook/components/clip_tile.dart';
import 'package:taketray_widgetbook/components/date_range_calendar.dart';
import 'package:taketray_widgetbook/components/date_range_picker.dart';
import 'package:taketray_widgetbook/components/dialog.dart';
import 'package:taketray_widgetbook/components/empty_state.dart';
import 'package:taketray_widgetbook/components/expand_card.dart';
import 'package:taketray_widgetbook/components/glass.dart';
import 'package:taketray_widgetbook/components/grouped_rows.dart';
import 'package:taketray_widgetbook/components/headers.dart';
import 'package:taketray_widgetbook/components/menu.dart';
import 'package:taketray_widgetbook/components/nav_pill.dart';
import 'package:taketray_widgetbook/components/pill_tabs.dart';
import 'package:taketray_widgetbook/components/player_chrome.dart';
import 'package:taketray_widgetbook/components/progress.dart';
import 'package:taketray_widgetbook/components/rec_dot.dart';
import 'package:taketray_widgetbook/components/reel_card.dart';
import 'package:taketray_widgetbook/components/reel_chip.dart';
import 'package:taketray_widgetbook/components/reel_header.dart';
import 'package:taketray_widgetbook/components/reel_pick_row.dart';
import 'package:taketray_widgetbook/components/reference_card.dart';
import 'package:taketray_widgetbook/components/selection.dart';
import 'package:taketray_widgetbook/components/sheet.dart';
import 'package:taketray_widgetbook/components/shooting_mode_card.dart';
import 'package:taketray_widgetbook/components/skeleton.dart';
import 'package:taketray_widgetbook/components/snack.dart';
import 'package:taketray_widgetbook/components/stat_strip.dart';
import 'package:taketray_widgetbook/components/status_pill.dart';
import 'package:taketray_widgetbook/components/step_list.dart';
import 'package:taketray_widgetbook/components/tag_done.dart';
import 'package:taketray_widgetbook/components/tag_panel.dart';
import 'package:taketray_widgetbook/components/text_field.dart';
import 'package:taketray_widgetbook/components/theme.dart';
import 'package:taketray_widgetbook/components/video_surface.dart';
import 'package:taketray_widgetbook/components/viewer_chrome.dart';
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
      ttButtonRowComponent,
      ttIconButtonComponent,
      ttFabComponent,
      ttCountBadgeComponent,
      ttRecDotComponent,
      ttSwitchComponent,
      ttMarksComponent,
      ttSuggestionChipComponent,
    ],
  ),
  WidgetbookFolder(
    name: 'Navigation',
    children: [ttAppBarComponent, ttNavPillComponent, ttPillTabsComponent],
  ),
  WidgetbookFolder(
    name: 'Clips',
    children: [
      ttClipTileComponent,
      ttMissingClipTileComponent,
      ttClipTileSkeletonComponent,
      ttSkeletonLineComponent,
      ttSkeletonCountComponent,
      ttSceneHeaderComponent,
      ttDayHeaderComponent,
    ],
  ),
  WidgetbookFolder(
    name: 'Status',
    children: [ttStatusPillComponent, ttStatStripComponent],
  ),
  WidgetbookFolder(
    name: 'Cards',
    children: [
      ttReelCardComponent,
      ttReferenceCardComponent,
      ttAddReferenceTileComponent,
      ttShootingModeCardComponent,
      ttCardRowComponent,
      ttReelHeaderComponent,
    ],
  ),
  WidgetbookFolder(
    name: 'Player',
    children: [
      ttVideoSurfaceComponent,
      ttSegmentBarComponent,
      ttPlayerHeaderComponent,
      ttStageArrowComponent,
      ttScrubBarComponent,
      ttReelChipComponent,
      ttNewReelChipComponent,
      ttTagPanelComponent,
      ttOtherReelsToggleComponent,
      ttTagDoneComponent,
      ttSameAsPreviousButtonComponent,
      ttReelTagComponent,
      ttViewerActionsComponent,
    ],
  ),
  WidgetbookFolder(
    name: 'Inputs',
    children: [
      ttTextFieldComponent,
      ttDateRangeCalendarComponent,
      ttDateRangePickerComponent,
    ],
  ),
  WidgetbookFolder(
    name: 'Lists',
    children: [
      ttGroupedRowsComponent,
      ttListRowComponent,
      ttRowCountComponent,
      ttRowSpinnerComponent,
      ttBannerComponent,
      ttCalloutComponent,
      ttExpandCardComponent,
      ttStepListComponent,
      ttInfoBarComponent,
      ttProgressBarComponent,
      ttIllustrationComponent,
      ttEmptyStateComponent,
    ],
  ),
  WidgetbookFolder(
    name: 'Overlays',
    children: [
      ttGlassComponent,
      ttGlassPillComponent,
      ttSheetComponent,
      ttDialogComponent,
      ttSnackComponent,
      ttMenuButtonComponent,
      ttReelPickRowComponent,
      ttReelPickNewRowComponent,
    ],
  ),
];
