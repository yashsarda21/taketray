import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:taketray_ui/src/components/app_bar.dart';
import 'package:taketray_ui/src/components/buttons.dart';
import 'package:taketray_ui/src/components/date_range_calendar.dart';
import 'package:taketray_ui/src/components/internal/day_text.dart';
import 'package:taketray_ui/src/components/pill_tabs.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// Every word of the date range picker. The app gives its own translations;
/// [english] is for tests and the catalogue.
class TtDateRangePickerLabels {
  /// Labels with every word given.
  const new({
    required this.title,
    required this.close,
    required this.clear,
    required this.findVideos,
    required this.yesterday,
    required this.lastWeek,
    required this.thisMonth,
    required this.lastMonth,
    required this.nothingTitle,
    required this.nothingSubtitle,
    required this.firstTitle,
    required this.firstSubtitle,
    required this.rangeTitle,
    required this.rangeSubtitle,
    required this.oneDaySubtitle,
    required this.calendar,
  });

  /// The labels in English, as the handoff words them.
  static final TtDateRangePickerLabels english = TtDateRangePickerLabels(
    title: 'Choose dates',
    close: 'Close',
    clear: 'Clear',
    findVideos: 'Find videos',
    yesterday: 'Yesterday',
    lastWeek: 'Last week',
    thisMonth: 'This month',
    lastMonth: 'Last month',
    nothingTitle: 'Tap the first day',
    nothingSubtitle: 'Then tap the last day.',
    firstTitle: (day) => '$day – …',
    firstSubtitle: (day) => 'Tap the last day, or Find videos for $day only.',
    rangeTitle: (from, to) => '$from – $to',
    rangeSubtitle: (days) => '$days days',
    oneDaySubtitle: '1 day',
    calendar: TtDateRangeCalendarLabels.english,
  );

  /// The title of the page, which is what a screen reader starts at.
  final String title;

  /// The ✕ button.
  final String close;

  /// The action that removes the chosen days.
  final String clear;

  /// The button that closes the picker with the chosen days.
  final String findVideos;

  /// Quick range: the day before today.
  final String yesterday;

  /// Quick range: the whole week before this one.
  final String lastWeek;

  /// Quick range: the 1st of this month to today.
  final String thisMonth;

  /// Quick range: the whole month before this one.
  final String lastMonth;

  /// The summary when nothing is chosen: its big line.
  final String nothingTitle;

  /// The summary when nothing is chosen: the line under it.
  final String nothingSubtitle;

  /// The big line when only the first day is chosen, given that day.
  final String Function(String day) firstTitle;

  /// The line under it, given that day.
  final String Function(String day) firstSubtitle;

  /// The big line for a range, given its first and last day.
  final String Function(String from, String to) rangeTitle;

  /// The line under a range, given how many days it has (2 or more).
  final String Function(int days) rangeSubtitle;

  /// The line under a single chosen day (its big line is the day).
  final String oneDaySubtitle;

  /// The calendar's labels.
  final TtDateRangeCalendarLabels calendar;
}

/// Opens the date range picker as a full-screen page and returns the days
/// chosen with **Find videos**: `end == start` for one day. It returns null
/// when the user closes it (✕ or back).
///
/// The page rises 24 dp and fades in over `motion.medium2`, with no travel
/// and no fade under "remove animations". Focus moves to the title when it
/// opens; when it closes, focus goes back to where it was (the row that
/// opened it).
///
/// [initialDateRange] opens it on days already chosen (the last dates chosen
/// in the sheet), or null for none. [currentDate] is today: it is ringed, and
/// the "this year" rule of the dates' text and the quick ranges use it.
Future<DateTimeRange?> showTtDateRangePicker(
  BuildContext context, {
  required DateTime firstDate,
  required DateTime lastDate,
  required DateTime currentDate,
  required TtDateRangePickerLabels labels,
  DateTimeRange? initialDateRange,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final motion = context.tt.motion;
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  final opener = FocusManager.instance.primaryFocus;
  final range = await navigator.push<DateTimeRange>(
    PageRouteBuilder<DateTimeRange>(
      fullscreenDialog: true,
      // proto.css: .evp.fresh { animation: evpIn medium2 emphasized-decel }
      transitionDuration: motion.medium2,
      reverseTransitionDuration: motion.short4,
      pageBuilder: (routeContext, animation, secondaryAnimation) => themes.wrap(
        Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: labels.title,
          child: TtDateRangePickerPage(
            firstDate: firstDate,
            lastDate: lastDate,
            today: currentDate,
            labels: labels,
            initialRange: initialDateRange,
            onFind: (range) => Navigator.of(routeContext).pop(range),
            onClose: () => Navigator.of(routeContext).maybePop(),
          ),
        ),
      ),
      transitionsBuilder: (routeContext, animation, secondaryAnimation, child) {
        final t = animation.drive(
          CurveTween(curve: motion.emphasizedDecelerate),
        );
        return AnimatedBuilder(
          animation: t,
          child: child,
          builder: (context, child) => Opacity(
            opacity: t.value,
            child: Transform.translate(
              offset: Offset(0, (1 - t.value) * TtMetrics.calendarSlideTravel),
              child: child,
            ),
          ),
        );
      },
    ),
  );
  if (opener != null && opener.context != null && opener.canRequestFocus) {
    opener.requestFocus();
  }
  return range;
}

/// The content of the date range picker, without its route: an app bar with
/// Close, the title and Clear (only while days are chosen); a summary that is
/// a polite live region; the quick ranges (they only fill the calendar); the
/// calendar; and a fixed bottom bar with **Find videos**, off until a day is
/// chosen.
///
/// Use [showTtDateRangePicker] to open it. [onFind] gets the chosen days
/// (`end == start` for one day, also when only the first day was chosen).
class TtDateRangePickerPage extends StatefulWidget {
  /// A picker for days between [firstDate] and [lastDate].
  const new({
    required this.firstDate,
    required this.lastDate,
    required this.today,
    required this.labels,
    required this.onFind,
    required this.onClose,
    this.initialRange,
    super.key,
  });

  /// The earliest day that can be chosen.
  final DateTime firstDate;

  /// The latest day that can be chosen.
  final DateTime lastDate;

  /// Today.
  final DateTime today;

  /// The words on the page.
  final TtDateRangePickerLabels labels;

  /// The days chosen when it opens, or null.
  final DateTimeRange? initialRange;

  /// Called with the chosen days when Find videos is tapped.
  final ValueChanged<DateTimeRange> onFind;

  /// Called when ✕ is tapped.
  final VoidCallback onClose;

  @override
  State<TtDateRangePickerPage> createState() => _TtDateRangePickerPageState();
}

class _TtDateRangePickerPageState extends State<TtDateRangePickerPage> {
  late final TtDateRangeCalendarController _controller =
      TtDateRangeCalendarController(range: widget.initialRange)
        ..addListener(_changed);
  final FocusNode _titleFocus = FocusNode(debugLabel: 'date picker title');

  @override
  void initState() {
    super.initState();
    // The title takes the focus once the page is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _titleFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_changed)
      ..dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  DateTime get _today => DateUtils.dateOnly(widget.today);

  /// The quick ranges by key, for the locale's first day of the week.
  Map<String, DateTimeRange> _quickRanges(int firstDayOfWeek) {
    final today = _today;
    // Days since this week began (DateTime.weekday: Monday 1 to Sunday 7;
    // `% 7` makes Sunday 0, as the localizations count).
    final sinceWeekStart =
        (today.weekday % DateTime.daysPerWeek -
            firstDayOfWeek +
            DateTime.daysPerWeek) %
        DateTime.daysPerWeek;
    final lastWeekStart = DateTime(
      today.year,
      today.month,
      today.day - sinceWeekStart - DateTime.daysPerWeek,
    );
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    return {
      'yesterday': DateTimeRange(start: yesterday, end: yesterday),
      'lastWeek': DateTimeRange(
        start: lastWeekStart,
        end: DateTime(
          lastWeekStart.year,
          lastWeekStart.month,
          lastWeekStart.day + DateTime.daysPerWeek - 1,
        ),
      ),
      'thisMonth': DateTimeRange(
        start: DateTime(today.year, today.month),
        end: today,
      ),
      'lastMonth': DateTimeRange(
        start: DateTime(today.year, today.month - 1),
        end: DateTime(today.year, today.month, 0),
      ),
    };
  }

  int _days(DateTimeRange range) =>
      DateTime.utc(range.end.year, range.end.month, range.end.day)
          .difference(
            DateTime.utc(range.start.year, range.start.month, range.start.day),
          )
          .inDays +
      1;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final labels = widget.labels;
    final dates = MaterialLocalizations.of(context);
    final range = _controller.range;
    final quick = _quickRanges(dates.firstDayOfWeekIndex);

    String day(DateTime d) => ttDayText(context, d, today: _today);
    final String title;
    final String subtitle;
    if (range == null) {
      title = labels.nothingTitle;
      subtitle = labels.nothingSubtitle;
    } else if (_controller.end == null) {
      title = labels.firstTitle(day(range.start));
      subtitle = labels.firstSubtitle(day(range.start));
    } else if (range.start == range.end) {
      title = day(range.start);
      subtitle = labels.oneDaySubtitle;
    } else {
      title = labels.rangeTitle(day(range.start), day(range.end));
      subtitle = labels.rangeSubtitle(_days(range));
    }

    // A quick range is on while it is exactly what is chosen.
    String? matching;
    if (range != null && _controller.end != null) {
      for (final MapEntry(:key, :value) in quick.entries) {
        if (value == range) matching = key;
      }
    }

    final bar = TtAppBar(
      title: labels.title,
      titleFocusNode: _titleFocus,
      // Nothing is cut at 2x text: the title wraps and the bar grows.
      wrapTitle: true,
      leading: TtIconButton(
        icon: Symbols.close_rounded,
        semanticLabel: labels.close,
        style: TtIconButtonStyle.circle,
        onPressed: widget.onClose,
      ),
      actions: [
        if (range != null)
          TtButton(
            label: labels.clear,
            kind: TtButtonKind.text,
            onPressed: _controller.clear,
          ),
      ],
    );

    final summary = Padding(
      // proto.css: .evp-sum { padding: 4px 16px 12px }
      padding: EdgeInsets.fromLTRB(
        tt.spacing.m,
        tt.spacing.xxs,
        tt.spacing.m,
        tt.spacing.s,
      ),
      child: Semantics(
        container: true,
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: tt.spacing.xxs,
          children: [
            Text(
              title,
              style: tt.text.material.headlineSmall!.copyWith(
                color: scheme.onSurface,
              ),
            ),
            Text(
              subtitle,
              style: tt.text.material.bodyMedium!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );

    final chips = Padding(
      // proto.css: .evp-quick { padding-bottom: 12px }
      padding: EdgeInsets.only(bottom: tt.spacing.s),
      child: TtPillTabs<String?>(
        wrapAtLargeText: true,
        tabs: [
          TtPillTab<String?>('yesterday', labels.yesterday),
          TtPillTab<String?>('lastWeek', labels.lastWeek),
          TtPillTab<String?>('thisMonth', labels.thisMonth),
          TtPillTab<String?>('lastMonth', labels.lastMonth),
        ],
        value: matching,
        onChanged: (key) => _controller.setRange(quick[key]!),
      ),
    );

    final calendar = Padding(
      // proto.css: .evp-cal { padding: 0 12px }: 7 x 48 dp fits 360 dp.
      padding: EdgeInsets.symmetric(horizontal: tt.spacing.s),
      child: TtDateRangeCalendar(
        firstDate: widget.firstDate,
        lastDate: widget.lastDate,
        today: widget.today,
        labels: labels.calendar,
        controller: _controller,
      ),
    );

    final footer = DecoratedBox(
      // proto.css: .evp-foot
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(
            color: scheme.onSurface.withValues(
              alpha: TtMetrics.hairlineOpacity,
            ),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            tt.spacing.m,
            tt.spacing.s,
            tt.spacing.m,
            tt.spacing.m,
          ),
          child: TtButton(
            label: labels.findVideos,
            size: TtButtonSize.large,
            expand: true,
            onPressed: range == null ? null : () => widget.onFind(range),
          ),
        ),
      ),
    );

    return Material(
      color: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bar,
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: tt.spacing.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [summary, chips, calendar],
              ),
            ),
          ),
          footer,
        ],
      ),
    );
  }
}
