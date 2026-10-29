# Add earlier videos: handoff

Design change of 29 Oct 2026 (owner-approved). Screens 38–40 in the hub (`design/prototype/index.html#screen-38`), every state in light and dark at 360 dp, plus 2× text. In the live prototype, pick the "Add earlier videos" flow.

## What changes from the current build (D-78)

1. **The stock picker goes.** `showDateRangePicker` and the `DatePickerThemeData` in `TakeTrayTheme` (and its golden) are replaced by TakeTray's own picker, because the stock day cells are under 48 dp.
2. **The card row gets its own slot.** References and Add earlier videos can both show: References first, then Add earlier videos, then the "N clips to tag" strip.
3. **The picker reopens on the last dates chosen** in the same sheet (the build passes `initialDateRange: null` every time). After "No new videos", widening the range is one tap.
4. **Off rows keep AA contrast.** A disabled row uses onSurfaceVariant text and an outlined count, not 38 % opacity.
5. **Quick ranges** in the picker (Yesterday, Last week, This month, Last month). They are optional and only fill the calendar; nothing is counted or added until Find videos and Add.

The rules stay as they are: when the row shows, Today adds at once, the dates are counted and confirmed, Cancel and OK go back to the sheet, and Undo is only for clips nobody has touched since.

## New components (taketray_ui)

**`TtDateRangeCalendar`**: one month of days, with:
- the month header: a month-name button and the previous and next month buttons;
- the year and month grid;
- selection.

It takes `firstDate`, `lastDate`, `today`, `initialRange` and `onChanged(DateTimeRange?)`. The week starts on `MaterialLocalizations.firstDayOfWeekIndex`.

**`showTtDateRangePicker(context, {firstDate, lastDate, currentDate, initialDateRange})`** returns `Future<DateTimeRange?>`. It is a full-screen dialog route on `surface`:
- an app bar with Close (✕), the title "Choose dates", and Clear (only while days are chosen);
- the summary;
- the quick-range chips;
- the calendar;
- a fixed bottom bar with "Find videos" (a large filled button, off until a day is chosen).

It returns `end == start` for one day, as the stock picker does.

### Tapping days

- The first tap picks the first day. The second tap picks the last day (the same day again means one day).
- A tap before the first day moves the first day.
- A tap after a full range starts again.
- Find videos with only the first day chosen counts that one day.

### Moving between months

- The ‹ › buttons, or a horizontal swipe on the grid.
- The month-name button opens the year and month grid: years from this year back 10 years, newest first, then the 12 months of the chosen year. A month goes back to its days.
- The › button stops at this month. The ‹ button stops at the month 10 years back (`firstDate`, as in the build).

## Variants of existing components

- **`TtShootingModeCard`**: `referencesRow` becomes `rows: List<TtCardRow>` (0–2 rows).
  - The Add earlier videos row: icon `history`, title "Add earlier videos", subtitle "Shot before Shooting mode was on", and a chevron.
  - It shows only while Shooting mode is on, access is full, and `earlierAdded` is false.
- **`TtListRow`, count trailing**:
  - "N new" sits in a secondaryContainer pill (min height 28 dp, 12 dp sides, `full` radius, labelLarge).
  - "none" is plain onSurfaceVariant labelLarge text.
- **`TtListRow`, off state**: the title is onSurfaceVariant at weight 400, and the count pill turns outlined (1 dp outlineVariant). There is no opacity change, so the text stays AA.
- **Large text**:
  - Today uses `stackTrailingAtLargeText: true`, so its count moves under the title.
  - Choose dates… keeps its chevron at the end.
- **The error** is `TtBanner(kind: TtBannerKind.warning, icon: error, title: "Couldn't check your videos.", action: Try again)`, the same kind as the lost-access banner. It sits under the sheet's subtitle.
- **Busy rows**:
  - While counting, the Choose dates… row shows "{range} · Checking…" with a 20 dp progress spinner (2 dp stroke, primary) in place of the chevron.
  - While adding, the busy row says "Adding…".
  - Both rows are off while counting, loading or adding.
- **Loading**: Today's count is a skeleton bar (48 × 16 dp, 8 dp radius).

## Tokens

There are **no new tokens**. The tables below map each part to an existing token.

### Colours

| Part | Token |
|---|---|
| Picker background, bottom bar | `surface` |
| Day | `onSurface`, weight 600 |
| Day of another month | `onSurfaceVariant`, weight 500 |
| First and last day | `primary` circle, `onPrimary` text, weight 700 |
| Days between | `primaryContainer` band (half-cells under the first and last day), `onPrimaryContainer` text |
| Today | 1 dp `primary` ring, `primary` text |
| Off day | `onSurfaceVariant`, weight 400, a line through |
| Month and year pill | `surfaceContainerHigh`; chosen: `primary` / `onPrimary`; contains chosen days: 1 dp `primary` ring; off: 1 dp `outlineVariant` ring, `onSurfaceVariant` text with a line through |
| Disabled ‹ › | `TtMetrics.disabledContentOpacity` (0.38); WCAG exempts inactive controls |
| Hairline above the bottom bar | `onSurface` at `TtMetrics.hairlineOpacity` (0.09) |

Measured in the hub (graphite, light and dark), the lowest text contrast in the flow is 6.1:1 (today, light). Off days are 8.9:1 (light) and 11.4:1 (dark).

### Sizes that matter

| Part | Size |
|---|---|
| Day cell | 48 × 48 dp (`touchTarget`). The grid has 7 columns of at least 48 dp, so the calendar uses **12 dp sides (`space3`)** at 360 dp. It is the only place that does not use the 16 dp gutter; wider phones share the extra width. |
| Weekday row | 40 dp, labelMedium, onSurfaceVariant |
| Month header | 48 dp; the month name is titleMedium |
| Month and year pills | at least 48 dp tall, 8 dp gaps, columns at least 5 em wide (so fewer columns at large text) |
| Summary | headlineSmall for the range, bodyMedium for the line under it |
| Quick chips | the TakeTray pill tabs (36 dp, 48 dp target); they wrap instead of scrolling at font scale ≥ 1.5 |
| Bottom bar | large button (56 dp); padding 12 / 16 / 16 |
| Sheet rows | `TtListRow` tall (72 dp) |
| Card row | `TtCardRow` (56 dp) |

### Motion

| What | How |
|---|---|
| Picker opens | rises 24 dp and fades in, `medium2`, emphasized decelerate |
| Month changes | slides 24 dp and fades, `medium1`, emphasized decelerate |
| Reduced motion | no travel |

## Copy

All copy from the brief is kept word for word, with one proposed change that needs the owner's yes:

| Old (D-78, no year, as the owner asked) | New (proposed) |
|---|---|
| No new videos between Dec 30 and Jan 2. | No new videos between 30 Dec 2025 and 2 Jan 2026. |

The year is added only when a date is not in this year. The picker reaches 10 years back, so "8 Oct" alone can be the wrong year. If the owner says no, drop the year everywhere except the picker's month header.

**Dates follow the phone's locale:**
- `MMMd` gives "10 Oct" on en-IN and en-GB, and "Oct 10" on en-US, as in the brief.
- `yMMMd` is used when a date is not in this year.
- A date never breaks across lines (non-breaking space).

**New strings (additions):**

| Where | Text |
|---|---|
| Card row subtitle | Shot before Shooting mode was on |
| Today row subtitle | the date, `MMMEd` (Mon 12 Oct) |
| Choose dates… subtitle | Up to 10 years back |
| Counting | {range} · Checking… |
| Adding | {range} · Adding…, and "Adding…" on Today |
| Picker title (was the help text) | Choose dates |
| Picker action | Clear |
| Summary, nothing chosen | Tap the first day / Then tap the last day. |
| Summary, first day chosen | {day} – … / Tap the last day, or Find videos for {day} only. |
| Summary, range | {from} – {to} / {n} days (one day: {day} / 1 day) |
| Quick ranges | Yesterday · Last week · This month · Last month |
| Year and month grid labels | Year · Month |

## Screen reader labels

**Sheet rows:**
- "Today, 3 new videos. Adds them to To tag", "Today, no new videos", "Today, checking for new videos", "Today, not checked"
- "Choose dates, up to 10 years back"; while busy: "Choose dates. 8 Oct – 10 Oct · Checking…"

**Card row:** "Add earlier videos, shot before Shooting mode was on".

**Days:** the full date, then the state, then extras.
- Examples: "Thursday 8 October 2026, first day", "…, last day", "…, in the range", "…, the only day", "…, today", "…, not available".
- The grid is a `grid` of `gridcell`s; chosen days are marked selected.

**Month header:**
- "Choose month and year. Now October 2026", which becomes "Back to the days" when the grid is open.
- "Previous month" and "Next month".

**Pills:**
- Years are radio buttons.
- Months read "September 2026, has chosen days" or "November 2026, not available".

**Live regions:** the summary is a polite live region, and the spinners are labelled ("Checking your videos from 8 Oct – 10 Oct").

**Focus:** it moves to the picker's title on open and back to Choose dates… on close.
