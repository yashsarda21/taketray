import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_symbols_icons/symbols.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_text_styles.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// What the calendar says to a screen reader, and the words on its year and
/// month grid. The app gives its own translations; [english] is for tests and
/// the catalogue.
///
/// A day is read as its full date (in the phone's language), then its state,
/// then the extras, joined by commas: "Thursday, October 8, 2026, first day",
/// "…, last day, today", "…, not available".
class TtDateRangeCalendarLabels {
  /// Labels with every word given.
  const new({
    required this.previousMonth,
    required this.nextMonth,
    required this.backToDays,
    required this.chooseMonthAndYear,
    required this.yearHeading,
    required this.monthHeading,
    required this.firstDay,
    required this.lastDay,
    required this.onlyDay,
    required this.inRange,
    required this.today,
    required this.notAvailable,
    required this.hasChosenDays,
  });

  /// The labels in English, as the handoff words them.
  static final TtDateRangeCalendarLabels english = TtDateRangeCalendarLabels(
    previousMonth: 'Previous month',
    nextMonth: 'Next month',
    backToDays: 'Back to the days',
    chooseMonthAndYear: (monthYear) => 'Choose month and year. Now $monthYear',
    yearHeading: 'Year',
    monthHeading: 'Month',
    firstDay: 'first day',
    lastDay: 'last day',
    onlyDay: 'the only day',
    inRange: 'in the range',
    today: 'today',
    notAvailable: 'not available',
    hasChosenDays: 'has chosen days',
  );

  /// The ‹ button.
  final String previousMonth;

  /// The › button.
  final String nextMonth;

  /// The month button while the year and month grid is open.
  final String backToDays;

  /// The month button over the days, given the month on show ("October 2026").
  final String Function(String monthYear) chooseMonthAndYear;

  /// The heading over the years.
  final String yearHeading;

  /// The heading over the months.
  final String monthHeading;

  /// The first chosen day (also while the last day is still to be chosen).
  final String firstDay;

  /// The last chosen day.
  final String lastDay;

  /// A day that is both the first and the last day.
  final String onlyDay;

  /// A day between the first and the last day.
  final String inRange;

  /// The extra said for today.
  final String today;

  /// The extra said for a day (or month) that cannot be chosen.
  final String notAvailable;

  /// The extra said for a month that holds chosen days.
  final String hasChosenDays;
}

/// The days chosen in a [TtDateRangeCalendar], and the month it shows.
///
/// It holds the tap rules (D-79), so a screen around the calendar (the date
/// range picker) can read, fill and clear the choice:
/// - the first tap picks the first day, the second the last day (the same
///   day again is one day);
/// - a tap before the first day, while the last day is still to be chosen,
///   moves the first day;
/// - a tap after a full range starts again.
///
/// [end] is null while only the first day is chosen. Every date is a day
/// (the time of day is dropped).
class TtDateRangeCalendarController extends ChangeNotifier {
  /// A controller that starts with [range] chosen, or nothing.
  new({DateTimeRange? range})
    : _start = range == null ? null : DateUtils.dateOnly(range.start),
      _end = range == null ? null : DateUtils.dateOnly(range.end),
      _month = range == null ? null : _monthOf(range.end);

  DateTime? _start;
  DateTime? _end;
  DateTime? _month;

  /// The first chosen day, or null when nothing is chosen.
  DateTime? get start => _start;

  /// The last chosen day, or null while it is still to be chosen.
  DateTime? get end => _end;

  /// The first day of the month on show, or null before the calendar has
  /// been built (it then shows today's month).
  DateTime? get month => _month;

  /// What is chosen: null for nothing, a range of one day while only the
  /// first day is chosen, else the first to the last day.
  DateTimeRange? get range {
    final start = _start;
    if (start == null) return null;
    return DateTimeRange(start: start, end: _end ?? start);
  }

  /// A tap on [day]: the tap rules in the class comment.
  void tapDay(DateTime day) {
    final tapped = DateUtils.dateOnly(day);
    final start = _start;
    if (start == null || _end != null) {
      _start = tapped;
      _end = null;
    } else if (tapped.isBefore(start)) {
      _start = tapped;
    } else {
      _end = tapped;
    }
    notifyListeners();
  }

  /// Chooses [range] (for example a quick range) and shows its last month.
  void setRange(DateTimeRange range) {
    _start = DateUtils.dateOnly(range.start);
    _end = DateUtils.dateOnly(range.end);
    _month = _monthOf(range.end);
    notifyListeners();
  }

  /// Chooses nothing. The month on show stays.
  void clear() {
    if (_start == null && _end == null) return;
    _start = null;
    _end = null;
    notifyListeners();
  }

  /// Shows [month] (any day of it).
  void showMonth(DateTime month) {
    final first = _monthOf(month);
    if (first == _month) return;
    _month = first;
    notifyListeners();
  }
}

DateTime _monthOf(DateTime day) => DateTime(day.year, day.month);

/// One month of days to choose a range from, with a month header, the year
/// and month grid, and the selection.
///
/// - **Days** are 48 x 48 dp targets in 7 equal columns (at least 48 dp
///   each), under a row of weekday letters. The week starts on
///   `MaterialLocalizations.firstDayOfWeekIndex`. Days of the previous and
///   next month fill the first and last row and can be chosen too. Days
///   after [lastDate] or before [firstDate] are off.
/// - **The header** has the month name (a button that opens the year and
///   month grid) and the ‹ › buttons, which stop at the months of
///   [firstDate] and [lastDate]. A horizontal swipe on the days does the
///   same.
/// - **The year and month grid** lists the years from [lastDate]'s back to
///   [firstDate]'s, newest first, then the 12 months of the chosen year.
///   Months with no available day are off. A month goes back to its days.
///
/// Give it a [controller] to read and change the choice from outside (the
/// date range picker does), or [initialRange] to start with days chosen.
/// [onChanged] hears every change of the choice: null for none, a range of
/// one day while only the first day is chosen, else the range.
///
/// It draws no side padding: the picker gives it 12 dp sides (`space3`), the
/// only place with less than the 16 dp gutter, because 7 x 48 dp = 336 dp
/// fits 360 dp. A wider phone shares the extra width between the columns.
class TtDateRangeCalendar extends StatefulWidget {
  /// A calendar between [firstDate] and [lastDate], with [today] marked.
  const new({
    required this.firstDate,
    required this.lastDate,
    required this.today,
    required this.labels,
    this.initialRange,
    this.onChanged,
    this.controller,
    this.startOnYearGrid = false,
    super.key,
  }) : assert(
         controller == null || initialRange == null,
         'Give the controller its range, or give initialRange, not both',
       );

  /// The earliest day that can be chosen.
  final DateTime firstDate;

  /// The latest day that can be chosen (usually today).
  final DateTime lastDate;

  /// The day marked with a ring.
  final DateTime today;

  /// The words a screen reader hears, and the grid's headings.
  final TtDateRangeCalendarLabels labels;

  /// The days chosen at first, or null for none. Ignored with a
  /// [controller].
  final DateTimeRange? initialRange;

  /// Called when the choice changes.
  final ValueChanged<DateTimeRange?>? onChanged;

  /// Whether the year and month grid is open at first (for the catalogue and
  /// the goldens; a person opens it with the month button).
  final bool startOnYearGrid;

  /// Holds the choice and the month on show, or null for the calendar's own.
  final TtDateRangeCalendarController? controller;

  @override
  State<TtDateRangeCalendar> createState() => _TtDateRangeCalendarState();
}

class _TtDateRangeCalendarState extends State<TtDateRangeCalendar> {
  late TtDateRangeCalendarController _controller;
  bool _ownsController = false;
  DateTimeRange? _reported;

  /// The year and month grid is open, on [_jumpYear].
  late bool _jump = widget.startOnYearGrid;
  late int _jumpYear;

  /// Which way the month on show moved (1 next, -1 previous, 0 neither); set
  /// by the buttons and the swipe, read by the grid that slides in.
  int _pendingSlide = 0;
  int _slide = 0;
  double _drag = 0;

  DateTime get _firstDay => DateUtils.dateOnly(widget.firstDate);
  DateTime get _lastDay => DateUtils.dateOnly(widget.lastDate);

  @override
  void initState() {
    super.initState();
    _attach(widget.controller);
  }

  void _attach(TtDateRangeCalendarController? given) {
    _ownsController = given == null;
    _controller =
        given ?? TtDateRangeCalendarController(range: widget.initialRange);
    _controller._month ??= _clampMonth(_monthOf(widget.today));
    _reported = _controller.range;
    _jumpYear = _controller._month!.year;
    _controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(TtDateRangeCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller.removeListener(_changed);
      if (_ownsController) _controller.dispose();
      _attach(widget.controller);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  DateTime _clampMonth(DateTime month) {
    final first = _monthOf(_firstDay);
    final last = _monthOf(_lastDay);
    if (month.isBefore(first)) return first;
    if (month.isAfter(last)) return last;
    return month;
  }

  void _changed() {
    final range = _controller.range;
    final changed = range != _reported;
    _reported = range;
    final slide = _pendingSlide;
    _pendingSlide = 0;
    setState(() {
      _slide = slide;
      // A choice made from outside (a quick range) shows its days.
      if (_jump && changed) _jump = false;
    });
    if (changed) widget.onChanged?.call(range);
  }

  DateTime get _month => _controller._month!;

  bool get _canGoBack => _month.isAfter(_monthOf(_firstDay));
  bool get _canGoForward => _month.isBefore(_monthOf(_lastDay));

  void _step(int direction) {
    if (direction < 0 ? !_canGoBack : !_canGoForward) return;
    _pendingSlide = direction;
    _controller.showMonth(DateTime(_month.year, _month.month + direction));
  }

  void _toggleJump() => setState(() {
    _jump = !_jump;
    _jumpYear = _month.year;
  });

  void _pickMonth(int year, int month) {
    setState(() => _jump = false);
    _controller.showMonth(DateTime(year, month));
  }

  /// The day tapped; a day that is off never gets here.
  void _tap(DateTime day) => _controller.tapDay(day);

  void _dragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final drag = _drag;
    _drag = 0;
    // A fling counts at any length; a slow drag must have gone a day's width.
    final double travelled;
    if (velocity.abs() >= kMinFlingVelocity) {
      travelled = velocity;
    } else if (drag.abs() >= TtMetrics.calendarSwipeDistance) {
      travelled = drag;
    } else {
      return;
    }
    // Swiping left brings the next month, as turning a page does; it is the
    // other way round when the text runs right to left.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final forward = (travelled < 0) != rtl;
    _step(forward ? 1 : -1);
  }

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final dates = MaterialLocalizations.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final monthYear = dates.formatMonthYear(_month);
    final labels = widget.labels;

    final header = ConstrainedBox(
      constraints: BoxConstraints(minHeight: tt.sizes.touchTarget),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: _MonthButton(
                text: monthYear,
                semanticLabel: _jump
                    ? labels.backToDays
                    : labels.chooseMonthAndYear(monthYear),
                open: _jump,
                onPressed: _toggleJump,
              ),
            ),
          ),
          if (!_jump) ...[
            _ArrowButton(
              icon: rtl
                  ? Symbols.chevron_right_rounded
                  : Symbols.chevron_left_rounded,
              label: labels.previousMonth,
              onPressed: _canGoBack ? () => _step(-1) : null,
            ),
            _ArrowButton(
              icon: rtl
                  ? Symbols.chevron_left_rounded
                  : Symbols.chevron_right_rounded,
              label: labels.nextMonth,
              onPressed: _canGoForward ? () => _step(1) : null,
            ),
          ],
        ],
      ),
    );

    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          if (_jump)
            _YearMonthGrid(
              firstDate: _firstDay,
              lastDate: _lastDay,
              month: _month,
              year: _jumpYear,
              chosen: _controller.range,
              labels: labels,
              onYear: (year) => setState(() => _jumpYear = year),
              onMonth: _pickMonth,
            )
          else ...[
            _WeekdayRow(firstDayOfWeek: dates.firstDayOfWeekIndex),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (_) => _drag = 0,
              onHorizontalDragUpdate: (d) => _drag += d.delta.dx,
              onHorizontalDragEnd: _dragEnd,
              child: _SlideIn(
                key: ValueKey<(int, int)>((_month.year, _month.month)),
                direction: _slide,
                child: _DaysGrid(
                  month: _month,
                  monthYear: monthYear,
                  firstDay: _firstDay,
                  lastDay: _lastDay,
                  today: DateUtils.dateOnly(widget.today),
                  start: _controller.start,
                  end: _controller.end,
                  labels: labels,
                  scheme: scheme,
                  onTap: _tap,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The month name with an arrow: opens and closes the year and month grid.
class _MonthButton extends StatelessWidget {
  const new({
    required this.text,
    required this.semanticLabel,
    required this.open,
    required this.onPressed,
  });

  final String text;
  final String semanticLabel;
  final bool open;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    // proto.css: .evp-mbtn
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: true,
      expanded: open,
      label: semanticLabel,
      onTap: onPressed,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: tt.sizes.touchTarget),
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: tt.spacing.s,
              end: tt.spacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: TtMetrics.calendarMonthButtonGap,
              children: [
                Flexible(
                  child: Text(
                    text,
                    style: tt.text.material.titleMedium!.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  open
                      ? Symbols.arrow_drop_up_rounded
                      : Symbols.arrow_drop_down_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The ‹ or › button: an icon button in `onSurface` that fades to 38 % when
/// it cannot go further (WCAG exempts inactive controls).
class _ArrowButton extends StatelessWidget {
  const new({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final target = tt.sizes.touchTarget;
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: onPressed != null,
      label: label,
      onTap: onPressed,
      child: SizedBox.square(
        dimension: target,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            foregroundColor: scheme.onSurface,
            disabledForegroundColor: scheme.onSurface.withValues(
              alpha: TtMetrics.disabledContentOpacity,
            ),
            fixedSize: Size.square(target),
            minimumSize: Size.square(target),
            padding: EdgeInsets.zero,
            iconSize: tt.sizes.icon,
            shape: const CircleBorder(),
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
        ),
      ),
    );
  }
}

/// The row of weekday letters, starting on the locale's first day.
class _WeekdayRow extends StatelessWidget {
  const new({required this.firstDayOfWeek});

  final int firstDayOfWeek;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final letters = MaterialLocalizations.of(context).narrowWeekdays;
    // proto.css: .evp-wd (hidden from a screen reader: each day says its name)
    return ExcludeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: TtMetrics.calendarWeekdayHeight,
        ),
        child: Row(
          children: [
            for (var i = 0; i < DateTime.daysPerWeek; i++)
              Expanded(
                child: Center(
                  child: Text(
                    letters[(firstDayOfWeek + i) % DateTime.daysPerWeek],
                    style: tt.text.material.labelMedium!.copyWith(
                      color: context.scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A month that slides in 24 dp from the side it comes from and fades in
/// (`medium1`, emphasized decelerate). Without animations, or when the month
/// did not move by a button or swipe, it is simply there.
class _SlideIn extends StatefulWidget {
  const new({required this.direction, required this.child, super.key});

  final int direction;
  final Widget child;

  @override
  State<_SlideIn> createState() => _SlideInState();
}

class _SlideInState extends State<_SlideIn> {
  // Read once: the slide belongs to the month that was put in, and a later
  // rebuild of the same month (a tap) must not change it halfway.
  late final int _direction = widget.direction;

  @override
  Widget build(BuildContext context) {
    final motion = context.tt.motion;
    if (_direction == 0 || motion.isReduced) return widget.child;
    final sign = Directionality.of(context) == TextDirection.rtl ? -1 : 1;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motion.medium1,
      curve: motion.emphasizedDecelerate,
      child: widget.child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(
            sign * _direction * (1 - t) * TtMetrics.calendarSlideTravel,
            0,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// The weeks of one month as a table of rows of day cells.
class _DaysGrid extends StatelessWidget {
  const new({
    required this.month,
    required this.monthYear,
    required this.firstDay,
    required this.lastDay,
    required this.today,
    required this.start,
    required this.end,
    required this.labels,
    required this.scheme,
    required this.onTap,
  });

  final DateTime month;
  final String monthYear;
  final DateTime firstDay;
  final DateTime lastDay;
  final DateTime today;
  final DateTime? start;
  final DateTime? end;
  final TtDateRangeCalendarLabels labels;
  final ColorScheme scheme;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final dates = MaterialLocalizations.of(context);
    // DateTime.weekday is 1 (Monday) to 7 (Sunday); `% 7` makes Sunday 0, as
    // the localizations count.
    final lead =
        (DateTime(month.year, month.month).weekday % DateTime.daysPerWeek -
            dates.firstDayOfWeekIndex +
            DateTime.daysPerWeek) %
        DateTime.daysPerWeek;
    final weeks =
        ((lead + DateUtils.getDaysInMonth(month.year, month.month)) /
                DateTime.daysPerWeek)
            .ceil();
    final range = start != null && end != null && end!.isAfter(start!);

    Widget cell(DateTime day) {
      final isStart = start != null && day == start;
      final isEnd = end != null && day == end;
      final inside = range && day.isAfter(start!) && day.isBefore(end!);
      return _DayCell(
        key: ValueKey<DateTime>(day),
        day: day,
        otherMonth: day.month != month.month,
        off: day.isAfter(lastDay) || day.isBefore(firstDay),
        today: day == today,
        isStart: isStart,
        isEnd: isEnd,
        inside: inside,
        band: range,
        onlyDay: isStart && isEnd,
        labels: labels,
        scheme: scheme,
        onTap: () => onTap(day),
      );
    }

    return Semantics(
      container: true,
      role: SemanticsRole.table,
      label: monthYear,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var week = 0; week < weeks; week++)
            Semantics(
              container: true,
              role: SemanticsRole.row,
              child: Row(
                children: [
                  for (var i = 0; i < DateTime.daysPerWeek; i++)
                    Expanded(
                      child: cell(
                        DateTime(
                          month.year,
                          month.month,
                          1 - lead + week * DateTime.daysPerWeek + i,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One day: a 48 dp target in a cell as wide as its column, with the band of
/// a range behind it (half a cell under the first and last day).
class _DayCell extends StatelessWidget {
  const new({
    required this.day,
    required this.otherMonth,
    required this.off,
    required this.today,
    required this.isStart,
    required this.isEnd,
    required this.inside,
    required this.band,
    required this.onlyDay,
    required this.labels,
    required this.scheme,
    required this.onTap,
    super.key,
  });

  final DateTime day;
  final bool otherMonth;
  final bool off;
  final bool today;
  final bool isStart;
  final bool isEnd;
  final bool inside;

  /// Whether the range spans more than one day (so its ends have a band).
  final bool band;
  final bool onlyDay;
  final TtDateRangeCalendarLabels labels;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final dates = MaterialLocalizations.of(context);
    final chosen = isStart || isEnd;

    // proto.css: .evd, .evd-c.out / .band / .today / .sel, .evd[disabled]
    final Color textColor;
    final FontWeight weight;
    if (chosen) {
      textColor = scheme.onPrimary;
      weight = TtMetrics.calendarDaySelectedWeight;
    } else if (off) {
      textColor = scheme.onSurfaceVariant;
      weight = TtMetrics.calendarDayOffWeight;
    } else if (today) {
      textColor = scheme.primary;
      weight = otherMonth
          ? TtMetrics.calendarDayOutWeight
          : TtMetrics.calendarDayWeight;
    } else if (inside) {
      textColor = scheme.onPrimaryContainer;
      weight = otherMonth
          ? TtMetrics.calendarDayOutWeight
          : TtMetrics.calendarDayWeight;
    } else if (otherMonth) {
      textColor = scheme.onSurfaceVariant;
      weight = TtMetrics.calendarDayOutWeight;
    } else {
      textColor = scheme.onSurface;
      weight = TtMetrics.calendarDayWeight;
    }
    final style = tt.text.material.bodyLarge!
        .merge(TtTextStyles.weight(weight))
        .copyWith(
          color: textColor,
          letterSpacing: 0,
          decoration: off && !chosen ? TextDecoration.lineThrough : null,
          decorationColor: textColor,
        );

    final BoxDecoration? circle;
    if (chosen) {
      circle = BoxDecoration(shape: BoxShape.circle, color: scheme.primary);
    } else if (today) {
      circle = BoxDecoration(
        shape: BoxShape.circle,
        // 1 dp: a border's default width.
        border: Border.all(color: scheme.primary),
      );
    } else {
      circle = null;
    }

    final Widget? bandBox;
    if (inside) {
      bandBox = ColoredBox(color: scheme.primaryContainer);
    } else if (band && (isStart || isEnd)) {
      bandBox = Align(
        alignment: isStart
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: 0.5,
          heightFactor: 1,
          child: ColoredBox(color: scheme.primaryContainer),
        ),
      );
    } else {
      bandBox = null;
    }

    final state = onlyDay
        ? labels.onlyDay
        : isStart
        ? labels.firstDay
        : isEnd
        ? labels.lastDay
        : inside
        ? labels.inRange
        : null;
    final label = [
      dates.formatFullDate(day),
      ?state,
      if (today) labels.today,
      if (off) labels.notAvailable,
    ].join(', ');

    final target = tt.sizes.touchTarget;
    return Semantics(
      container: true,
      excludeSemantics: true,
      role: SemanticsRole.cell,
      button: true,
      enabled: !off,
      selected: chosen || inside,
      label: label,
      onTap: off ? null : onTap,
      child: SizedBox(
        height: target,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (bandBox != null) Positioned.fill(child: bandBox),
            SizedBox.square(
              dimension: target,
              child: Stack(
                children: [
                  if (circle != null)
                    Positioned.fill(child: DecoratedBox(decoration: circle)),
                  Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: off ? null : onTap,
                      child: Center(child: Text('${day.day}', style: style)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The year and month grid: the years newest first, then the 12 months of
/// the chosen year, in columns at least 5 em wide.
class _YearMonthGrid extends StatelessWidget {
  const new({
    required this.firstDate,
    required this.lastDate,
    required this.month,
    required this.year,
    required this.chosen,
    required this.labels,
    required this.onYear,
    required this.onMonth,
  });

  final DateTime firstDate;
  final DateTime lastDate;

  /// The month on show.
  final DateTime month;

  /// The year whose months are listed.
  final int year;
  final DateTimeRange? chosen;
  final TtDateRangeCalendarLabels labels;
  final ValueChanged<int> onYear;
  final void Function(int year, int month) onMonth;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final dates = MaterialLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final shortMonth = DateFormat.MMM(locale);
    final heading = tt.text.material.titleSmall!.copyWith(
      color: scheme.onSurfaceVariant,
    );

    bool hasChosenDays(int y, int m) {
      final range = chosen;
      if (range == null) return false;
      final first = DateTime(y, m);
      final last = DateTime(y, m + 1, 0);
      return !range.start.isAfter(last) && !range.end.isBefore(first);
    }

    bool monthOff(int y, int m) =>
        DateTime(y, m).isAfter(lastDate) ||
        DateTime(y, m + 1, 0).isBefore(firstDate);

    final years = [for (var y = lastDate.year; y >= firstDate.year; y--) y];

    Widget title(String text) => Padding(
      padding: EdgeInsetsDirectional.only(start: tt.spacing.s),
      child: ExcludeSemantics(child: Text(text, style: heading)),
    );

    // proto.css: .evp-jump { padding: 8px 0 4px; gap: 8px }
    return Padding(
      padding: EdgeInsets.only(top: tt.spacing.xs, bottom: tt.spacing.xxs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: tt.spacing.xs,
        children: [
          title(labels.yearHeading),
          Semantics(
            container: true,
            role: SemanticsRole.radioGroup,
            label: labels.yearHeading,
            child: _PillGrid(
              pills: [
                for (final y in years)
                  _Pill(
                    text: '$y',
                    semanticLabel: '$y',
                    kind: y == year ? _PillKind.chosen : _PillKind.plain,
                    radio: true,
                    onPressed: () => onYear(y),
                  ),
              ],
            ),
          ),
          title(labels.monthHeading),
          _PillGrid(
            pills: [
              for (var m = DateTime.january; m <= DateTime.december; m++)
                _Pill(
                  text: shortMonth.format(DateTime(year, m)),
                  semanticLabel: [
                    dates.formatMonthYear(DateTime(year, m)),
                    if (hasChosenDays(year, m)) labels.hasChosenDays,
                    if (monthOff(year, m)) labels.notAvailable,
                  ].join(', '),
                  kind: monthOff(year, m)
                      ? _PillKind.off
                      : (year == month.year && m == month.month)
                      ? _PillKind.chosen
                      : hasChosenDays(year, m)
                      ? _PillKind.hasChosenDays
                      : _PillKind.plain,
                  onPressed: monthOff(year, m) ? null : () => onMonth(year, m),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _PillKind { plain, chosen, hasChosenDays, off }

/// Lays pills out in rows of equal columns, each at least 5 em wide, 8 dp
/// apart (`repeat(auto-fill, minmax(5em, 1fr))`), each row 48 dp high.
///
/// It is a custom layout rather than a `LayoutBuilder`, because the golden
/// tests (and any parent that asks for intrinsic sizes) cannot measure a
/// `LayoutBuilder`.
class _PillGrid extends StatelessWidget {
  const new({required this.pills});

  final List<_Pill> pills;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final label = tt.text.material.labelLarge!;
    final em = MediaQuery.textScalerOf(context).scale(label.fontSize!);
    return CustomMultiChildLayout(
      delegate: _PillGridDelegate(
        count: pills.length,
        minWidth: TtMetrics.calendarPillMinWidthEms * em,
        gap: tt.spacing.xs,
        rowHeight: tt.sizes.touchTarget,
        textDirection: Directionality.of(context),
      ),
      children: [
        for (var i = 0; i < pills.length; i++) LayoutId(id: i, child: pills[i]),
      ],
    );
  }
}

class _PillGridDelegate extends MultiChildLayoutDelegate {
  new({
    required this.count,
    required this.minWidth,
    required this.gap,
    required this.rowHeight,
    required this.textDirection,
  });

  final int count;
  final double minWidth;
  final double gap;
  final double rowHeight;
  final TextDirection textDirection;

  int _columns(double width) =>
      ((width + gap) / (minWidth + gap)).floor().clamp(1, count);

  @override
  Size getSize(BoxConstraints constraints) {
    // Asked for an intrinsic size (no width to lay out in): one row.
    if (!constraints.hasBoundedWidth) {
      return constraints.constrain(Size(constraints.minWidth, rowHeight));
    }
    final rows = (count / _columns(constraints.maxWidth)).ceil();
    return constraints.constrain(
      Size(constraints.maxWidth, rows * rowHeight + (rows - 1) * gap),
    );
  }

  @override
  void performLayout(Size size) {
    final columns = _columns(size.width);
    final width = (size.width - (columns - 1) * gap) / columns;
    for (var i = 0; i < count; i++) {
      layoutChild(i, BoxConstraints.tight(Size(width, rowHeight)));
      final column = i % columns;
      final x = textDirection == TextDirection.ltr
          ? column * (width + gap)
          : size.width - width - column * (width + gap);
      positionChild(i, Offset(x, (i ~/ columns) * (rowHeight + gap)));
    }
  }

  @override
  bool shouldRelayout(_PillGridDelegate oldDelegate) =>
      count != oldDelegate.count ||
      minWidth != oldDelegate.minWidth ||
      gap != oldDelegate.gap ||
      rowHeight != oldDelegate.rowHeight ||
      textDirection != oldDelegate.textDirection;
}

/// A year or a month in the year and month grid.
class _Pill extends StatelessWidget {
  const new({
    required this.text,
    required this.semanticLabel,
    required this.kind,
    required this.onPressed,
    this.radio = false,
  });

  final String text;
  final String semanticLabel;
  final _PillKind kind;
  final VoidCallback? onPressed;

  /// Whether this is one of the years (a radio button).
  final bool radio;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;

    // proto.css: .evp-pill, .on, .has:not(.on), [disabled]
    final (fill, content, ring) = switch (kind) {
      _PillKind.plain => (scheme.surfaceContainerHigh, scheme.onSurface, null),
      _PillKind.chosen => (scheme.primary, scheme.onPrimary, null),
      _PillKind.hasChosenDays => (
        scheme.surfaceContainerHigh,
        scheme.onSurface,
        scheme.primary,
      ),
      _PillKind.off => (null, scheme.onSurfaceVariant, scheme.outlineVariant),
    };
    final shape = ring == null
        ? const StadiumBorder()
        : StadiumBorder(
            // 1 dp (calendarRingWidth) is a BorderSide's default width.
            side: BorderSide(color: ring),
          );
    final off = kind == _PillKind.off;

    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: !off,
      checked: radio ? kind == _PillKind.chosen : null,
      inMutuallyExclusiveGroup: radio ? true : null,
      selected: !radio && kind == _PillKind.chosen,
      label: semanticLabel,
      onTap: onPressed,
      child: Material(
        color: fill,
        type: fill == null ? MaterialType.transparency : MaterialType.canvas,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: tt.sizes.touchTarget),
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: tt.spacing.xs),
                child: Text(
                  text,
                  maxLines: 1,
                  style: tt.text.material.labelLarge!.copyWith(
                    color: content,
                    decoration: off ? TextDecoration.lineThrough : null,
                    decorationColor: content,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
