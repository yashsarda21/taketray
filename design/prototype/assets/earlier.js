/* Add earlier videos (owner change, 2026-10-29): videos shot before Shooting
   mode was turned on. A row on the Shooting mode card and an item in To tag's
   ⋮ menu open a sheet with Today and Choose dates…. Dates come from a TakeTray
   calendar (tap the first day, then the last; 48 dp days), are counted, and
   are added only after a confirm. Data, components, the sheet, the picker,
   dialogs, prototype actions and the gallery screens (38–40). */
(function () {
  const RH = window.RH;
  const { fmt, q, h } = RH;
  const { esc, icon } = h;

  /* ------------------------------------------------------------------ */
  /* Calendar days: local dates as 'YYYY-MM-DD', compared as strings.    */
  /* ------------------------------------------------------------------ */
  const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  const MON = MONTHS.map((m) => m.slice(0, 3));
  const WEEKDAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  const pad = (n) => String(n).padStart(2, '0');
  const D = (RH.days = {
    parse(iso) { const [y, m, d] = iso.split('-').map(Number); return { y, m, d }; },
    iso(y, m, d) { const t = new Date(Date.UTC(y, m - 1, d)); return `${t.getUTCFullYear()}-${pad(t.getUTCMonth() + 1)}-${pad(t.getUTCDate())}`; },
    add(iso, n) { const p = D.parse(iso); return D.iso(p.y, p.m, p.d + n); },
    /** 0 = Monday … 6 = Sunday. The prototype starts weeks on Monday (en-GB); the app uses the locale's first day. */
    wd(iso) { const p = D.parse(iso); return (new Date(Date.UTC(p.y, p.m - 1, p.d)).getUTCDay() + 6) % 7; },
    ym(iso) { return iso.slice(0, 7); },
    ymAdd(ym, n) { const [y, m] = ym.split('-').map(Number); return D.iso(y, m + n, 1).slice(0, 7); },
    span(a, b) { return Math.round((Date.parse(b) - Date.parse(a)) / 864e5) + 1; },
  });
  const TODAY = RH.TODAY;
  const T = D.parse(TODAY);
  /** Ten years back, as the build: DateTime(today.year - 10, today.month, today.day). */
  const FIRST = D.iso(T.y - 10, T.m, T.d);

  /** "8 Oct", with the year when it isn't this year. The app formats by locale (MMMd / yMMMd). */
  const dd = (iso, withYear) => { const p = D.parse(iso); return `${p.d}\u00a0${MON[p.m - 1]}${withYear || p.y !== T.y ? `\u00a0${p.y}` : ''}`; }; // a date never breaks inside
  const rangeText = (a, b) => (a === b ? dd(a) : `${dd(a)} – ${dd(b)}`);
  const longDay = (iso) => { const p = D.parse(iso); return `${WEEKDAYS[D.wd(iso)]} ${p.d} ${MONTHS[p.m - 1]} ${p.y}`; };
  RH.evRangeText = rangeText;

  /* ------------------------------------------------------------------ */
  /* Fixture: videos on the phone that TakeTray doesn't have yet.        */
  /* ------------------------------------------------------------------ */
  const baseFixture = RH.fixture;
  RH.fixture = function () {
    const s = baseFixture();
    const phone = { clips: {} };
    const mk = (start, themes, count, spanMin, seed, tz = 'BST') => RH.run(phone, { start, themes, count, spanMin, seed, tz });
    mk(TODAY + 'T08:31:00', ['cafe', 'street', 'selfie'], 3, 21, 41); // this morning, before Shooting mode at 9:12
    mk('2026-10-09T05:52:00', ['street', 'selfie'], 2, 6, 42, 'IST'); // leaving for the airport
    mk('2026-10-09T14:10:00', ['river', 'street', 'selfie'], 3, 35, 43); // landed in London
    mk('2026-10-08T19:30:00', ['night', 'food'], 2, 9, 44, 'IST');
    mk('2026-10-02T13:05:00', ['market', 'food', 'market'], 3, 12, 45, 'IST');
    mk('2026-09-30T09:40:00', ['cafe', 'food', 'cafe', 'food'], 4, 40, 46, 'IST');
    mk('2026-09-14T11:00:00', ['cafe'], 5, 180, 47, 'IST');
    s.phone = phone;
    s.earlierUsed = false;
    return s;
  };

  /** Videos on the phone, shot from `a` to `b` (both included), that aren't in TakeTray. */
  RH.evFind = (s, a, b) => Object.values(s.phone ? s.phone.clips : {}).filter((c) => { const day = c.at.slice(0, 10); return day >= a && day <= b; });
  /** Moves them into To tag, in shooting order. Returns the new clip ids. */
  RH.evAdd = function (s, a, b) {
    const found = RH.evFind(s, a, b);
    found.forEach((c) => { s.clips[c.id] = c; delete s.phone.clips[c.id]; s.toTag.push(c.id); });
    s.toTag.sort((x, y) => (s.clips[x].at < s.clips[y].at ? -1 : 1));
    if (s.shooting.on) s.earlierUsed = true;
    return found.map((c) => c.id);
  };

  /* ------------------------------------------------------------------ */
  /* The sheet                                                           */
  /* ------------------------------------------------------------------ */
  const spinner = (label) => `<span class="spin ev-spin" role="progressbar" aria-label="${esc(label)}"></span>`;

  RH.sheets.earlier = (s, u) => {
    const e = u.sheet;
    if (e.picker) return picker(s, u, e.picker);
    const phase = e.phase || 'ready';
    const busy = phase !== 'ready';
    const todayN = RH.evFind(s, TODAY, TODAY).length;
    const todayOff = busy || e.err === 'today' || todayN === 0;
    const countText = todayN === 0 ? 'none' : `${todayN} new`;
    let todayTrail;
    if (phase === 'loading') todayTrail = '<span class="skel-line" style="width:48px;height:16px;border-radius:8px" aria-hidden="true"></span>';
    else if (phase === 'adding' && e.adding === 'today') todayTrail = `<span>Adding…</span>${spinner('Adding today’s videos')}`;
    else if (e.err === 'today') todayTrail = '';
    else todayTrail = `<span class="${todayN ? 'n' : 'none'}">${countText}</span>`;
    const todayLabel = phase === 'loading' ? 'Today, checking for new videos' : e.err === 'today' ? 'Today, not checked' : todayN ? `Today, ${fmt.n(todayN, 'new video')}. Adds them to To tag` : 'Today, no new videos';
    const today = `<button class="li tall tap ev-row stack" ${todayOff ? 'aria-disabled="true"' : 'data-a="evToday"'} aria-label="${esc(todayLabel)}"><span class="lead">${icon('today')}</span><span class="txt"><b>Today</b><span>${fmt.day(TODAY)}</span></span><span class="ev-trail">${todayTrail}</span></button>`;

    const counting = phase === 'counting' || (phase === 'adding' && e.adding === 'dates');
    const r = e.range;
    const chooseSub = counting && r ? `${rangeText(r.from, r.to)} · ${phase === 'counting' ? 'Checking…' : 'Adding…'}` : 'Up to 10 years back';
    const chooseTrail = counting ? spinner(phase === 'counting' ? `Checking your videos from ${rangeText(r.from, r.to)}` : 'Adding the videos') : icon('chevron_right');
    const choose = `<button class="li tall tap ev-row" ${busy ? 'aria-disabled="true"' : 'data-a="evChoose"'} aria-label="${esc(counting ? `Choose dates. ${chooseSub}` : 'Choose dates, up to 10 years back')}"><span class="lead">${icon('edit_calendar')}</span><span class="txt"><b>Choose dates…</b><span>${esc(chooseSub)}</span></span><span class="ev-trail">${chooseTrail}</span></button>`;

    const err = e.err ? `<div class="banner warn ev-err" role="alert">${icon('error')}<div class="grow"><b>Couldn't check your videos.</b></div>${h.btn({ label: 'Try again', kind: 'text', a: 'evRetry' })}</div>` : '';
    return `<div class="sheet ${e.fresh ? 'fresh' : ''}" role="dialog" aria-modal="true" aria-labelledby="ev-t"${busy ? ' aria-busy="true"' : ''}><div class="handle"></div>
      <div class="sh-head"><h2 id="ev-t">Add earlier videos</h2><p>From your camera folders. Clips you already tagged or skipped stay where they are.</p></div>
      <div class="sh-body ev-body">${err}${today}${choose}</div></div>`;
  };

  /* ------------------------------------------------------------------ */
  /* The date range picker: a full-screen dialog over the sheet          */
  /* ------------------------------------------------------------------ */
  const QUICK = [
    ['yesterday', 'Yesterday', () => { const y = D.add(TODAY, -1); return [y, y]; }],
    ['lastweek', 'Last week', () => { const mon = D.add(TODAY, -D.wd(TODAY) - 7); return [mon, D.add(mon, 6)]; }],
    ['thismonth', 'This month', () => [D.iso(T.y, T.m, 1), TODAY]],
    ['lastmonth', 'Last month', () => [D.iso(T.y, T.m - 1, 1), D.iso(T.y, T.m, 0)]],
  ];
  RH.evQuick = (k) => QUICK.find((x) => x[0] === k)[2]();

  function summary(pk) {
    if (!pk.from) return ['Tap the first day', 'Then tap the last day.'];
    if (!pk.to) return [`${dd(pk.from)} – …`, `Tap the last day, or Find videos for ${dd(pk.from)} only.`];
    if (pk.from === pk.to) return [dd(pk.from), '1 day'];
    return [rangeText(pk.from, pk.to), `${D.span(pk.from, pk.to)} days`];
  }

  function dayCell(iso, pk, viewYm) {
    const p = D.parse(iso);
    const off = iso > TODAY || iso < FIRST;
    const { from, to } = pk;
    const start = iso === from, end = iso === to;
    const span = from && to && to > from;
    const inside = span && iso > from && iso < to;
    const cls = ['evd-c'];
    if (D.ym(iso) !== viewYm) cls.push('out');
    if (inside) cls.push('band');
    if (span && start) cls.push('band-s');
    if (span && end) cls.push('band-e');
    if (start || end) cls.push('sel');
    if (iso === TODAY) cls.push('today');
    const state = start && (end || !to) ? (to ? ', the only day' : ', first day') : start ? ', first day' : end ? ', last day' : inside ? ', in the range' : '';
    const label = `${longDay(iso)}${state}${iso === TODAY ? ', today' : ''}${off ? ', not available' : ''}`;
    return `<div class="${cls.join(' ')}" role="gridcell"${start || end || inside ? ' aria-selected="true"' : ''}><button class="evd tap" ${off ? 'disabled' : `data-a="evDay" data-day="${iso}"`} aria-label="${esc(label)}">${p.d}</button></div>`;
  }

  function monthView(pk) {
    const [y, m] = pk.view.split('-').map(Number);
    const first = D.iso(y, m, 1), last = D.iso(y, m + 1, 0);
    const gridStart = D.add(first, -D.wd(first));
    const gridEnd = D.add(last, 6 - D.wd(last));
    const rows = [];
    for (let d = gridStart; d <= gridEnd; d = D.add(d, 7)) {
      const cells = [];
      for (let i = 0; i < 7; i++) cells.push(dayCell(D.add(d, i), pk, pk.view));
      rows.push(`<div class="evp-row" role="row">${cells.join('')}</div>`);
    }
    return `<div class="evp-wd" aria-hidden="true">${WEEKDAYS.map((w) => `<span>${w[0]}</span>`).join('')}</div>
      <div class="evp-grid ${pk.slide ? 'slide-' + pk.slide : ''}" role="grid" aria-label="${MONTHS[m - 1]} ${y}">${rows.join('')}</div>`;
  }

  function jumpView(pk) {
    const years = [];
    for (let yy = T.y; yy >= T.y - 10; yy--) years.push(yy);
    const jy = pk.jumpYear;
    const yearBtns = years.map((yy) => `<button class="evp-pill tap ${yy === jy ? 'on' : ''}" role="radio" aria-checked="${yy === jy}" data-a="evYear" data-y="${yy}">${yy}</button>`).join('');
    const selYms = new Set();
    if (pk.from) { const end = pk.to || pk.from; for (let ym = D.ym(pk.from); ym <= D.ym(end); ym = D.ymAdd(ym, 1)) selYms.add(ym); }
    const monthBtns = MON.map((mn, i) => {
      const ym = `${jy}-${pad(i + 1)}`;
      const off = ym > D.ym(TODAY) || ym < D.ym(FIRST);
      const on = ym === pk.view;
      const has = selYms.has(ym);
      return `<button class="evp-pill tap ${on ? 'on' : ''} ${has ? 'has' : ''}" ${off ? 'disabled' : `data-a="evPickMonth" data-ym="${ym}"`} aria-label="${MONTHS[i]} ${jy}${has ? ', has chosen days' : ''}${off ? ', not available' : ''}"${on ? ' aria-current="true"' : ''}>${mn}</button>`;
    }).join('');
    return `<div class="evp-jump"><div class="evp-jl" id="evp-yl">Year</div><div class="evp-pills" role="radiogroup" aria-labelledby="evp-yl">${yearBtns}</div>
      <div class="evp-jl">Month</div><div class="evp-pills">${monthBtns}</div></div>`;
  }

  function picker(s, u, pk) {
    const [title, sub] = summary(pk);
    const [y, m] = pk.view.split('-').map(Number);
    const atFirst = pk.view <= D.ym(FIRST), atLast = pk.view >= D.ym(TODAY);
    const chips = QUICK.map(([k, label, fn]) => {
      const [a, b] = fn();
      const on = pk.from === a && (pk.to || pk.from) === b && !!pk.to;
      return `<button class="fchip tap ${on ? 'on' : ''}" data-a="evQuick" data-k="${k}" aria-pressed="${on}">${on ? icon('check') : ''}${label}</button>`;
    }).join('');
    const mh = `<div class="evp-mh"><button class="evp-mbtn tap" data-a="evJump" aria-expanded="${!!pk.jump}" aria-label="${pk.jump ? 'Back to the days' : `Choose month and year. Now ${MONTHS[m - 1]} ${y}`}"><span>${MONTHS[m - 1]} ${y}</span>${icon(pk.jump ? 'arrow_drop_up' : 'arrow_drop_down')}</button>
      ${pk.jump ? '' : `<button class="ib tap" ${atFirst ? 'disabled' : 'data-a="evMonth" data-dir="-1"'} aria-label="Previous month">${icon('chevron_left')}</button><button class="ib tap" ${atLast ? 'disabled' : 'data-a="evMonth" data-dir="1"'} aria-label="Next month">${icon('chevron_right')}</button>`}</div>`;
    const bar = h.appbar({ title: 'Choose dates', nav: 'close', navA: 'evClose', actions: pk.from ? h.btn({ label: 'Clear', kind: 'text', a: 'evClear' }) : '' });
    return `<div class="evp ${pk.fresh ? 'fresh' : ''}" role="dialog" aria-modal="true" aria-label="Choose dates">${bar}
      <div class="evp-scroll"><div class="evp-sum" aria-live="polite"><b>${esc(title)}</b><span>${esc(sub)}</span></div>
      <div class="chips evp-quick" role="group" aria-label="Quick ranges">${chips}</div>
      <div class="evp-cal">${mh}${pk.jump ? jumpView(pk) : monthView(pk)}</div></div>
      <div class="evp-foot">${h.btn({ label: 'Find videos', kind: 'filled', size: 'lg block', a: 'evFind', dis: !pk.from })}</div></div>`;
  }

  /* ------------------------------------------------------------------ */
  /* Dialogs                                                             */
  /* ------------------------------------------------------------------ */
  RH.dialogs.earlierFound = (s, u) => {
    const n = u.dialog.n;
    return RH.dlg(null, n === 1 ? '1 video found' : `${n} videos found`, `<p>${n === 1 ? 'Add it to To tag?' : 'Add them to To tag?'}</p>`, h.btn({ label: 'Cancel', kind: 'text', a: 'evCancel' }) + h.btn({ label: 'Add', kind: 'text', a: 'evAdd' }));
  };
  RH.dialogs.earlierNone = (s, u) => {
    const { from, to } = u.dialog;
    return RH.dlg(null, 'No new videos', `<p>${from === to ? `No new videos on ${dd(from)}.` : `No new videos between ${dd(from)} and ${dd(to)}.`}</p>`, h.btn({ label: 'OK', kind: 'text', a: 'evNoneOk' }));
  };

  /* ------------------------------------------------------------------ */
  /* Prototype actions                                                   */
  /* ------------------------------------------------------------------ */
  const A = RH.ACTIONS;
  const later = (app, key, ms, fn) => { clearTimeout(app.timers[key]); app.timers[key] = setTimeout(fn, app.rm ? Math.min(ms, 300) : ms); };
  const ev = (app) => (app.u.sheet && app.u.sheet.type === 'earlier' ? app.u.sheet : null);

  function finishAdd(app, a, b) {
    app.snapshot();
    const ids = RH.evAdd(app.s, a, b);
    app.u.sheet = null;
    app.snack(`${fmt.n(ids.length, 'clip')} added to To tag`, { undo: true, ic: 'check_circle' });
    app.log(`${fmt.n(ids.length, 'clip')} from ${rangeText(a, b)} joined To tag in shooting order.${app.s.shooting.on ? ' The card row is gone for this session.' : ''}`);
    app.render();
  }

  /** Counts the new videos in the chosen dates, then asks (or says there are none). */
  function countDates(app, range) {
    Object.assign(ev(app), { phase: 'counting', range, err: null });
    app.render();
    later(app, 'ev', 900, () => {
      const x = ev(app);
      if (!x) return;
      x.phase = 'ready';
      const n = RH.evFind(app.s, range.from, range.to).length;
      app.u.dialog = n ? { type: 'earlierFound', n, ...range } : { type: 'earlierNone', ...range };
      app.render();
    });
  }

  Object.assign(A, {
    openEarlier(d) {
      this.u.menu = null;
      this.u.sheet = { type: 'earlier', from: d.from, phase: 'loading', fresh: true };
      this.render();
      later(this, 'ev', 700, () => { const e = ev(this); if (e && e.phase === 'loading') { e.phase = 'ready'; this.render(); } });
    },
    evRetry() {
      const e = ev(this);
      const dates = e.err === 'dates' && e.range;
      e.err = null;
      if (dates) return countDates(this, e.range);
      e.phase = 'loading'; this.render();
      later(this, 'ev', 700, () => { const x = ev(this); if (x) { x.phase = 'ready'; this.render(); } });
    },
    evToday() {
      const e = ev(this);
      e.phase = 'adding'; e.adding = 'today'; this.render();
      later(this, 'ev', 500, () => finishAdd(this, TODAY, TODAY));
    },
    evChoose() {
      const e = ev(this);
      const last = e.last;
      e.picker = { from: last ? last.from : null, to: last ? last.to : null, view: D.ym(last ? last.to : TODAY), fresh: true };
      this.render();
      e.picker.fresh = false;
      this.log(last ? 'The picker opens on the dates you chose last, so a near miss is one tap to fix.' : 'Tap the first day, then the last day. Tap the same day twice, or Find videos after one tap, for a single day.');
    },
    evClose() { ev(this).picker = null; this.render(); },
    evClear() { Object.assign(ev(this).picker, { from: null, to: null }); this.render(); },
    evDay(d) {
      const pk = ev(this).picker;
      const day = d.day;
      if (!pk.from || pk.to) Object.assign(pk, { from: day, to: null });
      else if (day < pk.from) pk.from = day;
      else pk.to = day;
      this.render();
    },
    evMonth(d) {
      const pk = ev(this).picker;
      const next = D.ymAdd(pk.view, +d.dir);
      if (next > D.ym(TODAY) || next < D.ym(FIRST)) return;
      pk.view = next; pk.slide = +d.dir > 0 ? 'next' : 'prev';
      this.render(); pk.slide = null;
    },
    evJump() { const pk = ev(this).picker; pk.jump = !pk.jump; pk.jumpYear = +pk.view.slice(0, 4); this.render(); },
    evYear(d) { ev(this).picker.jumpYear = +d.y; this.render(); },
    evPickMonth(d) { const pk = ev(this).picker; pk.view = d.ym; pk.jump = false; this.render(); },
    evQuick(d) { const pk = ev(this).picker; const [a, b] = RH.evQuick(d.k); Object.assign(pk, { from: a, to: b, view: D.ym(b), jump: false }); this.render(); },
    evFind() {
      const e = ev(this);
      const pk = e.picker;
      if (!pk || !pk.from) return;
      const range = { from: pk.from, to: pk.to || pk.from };
      e.last = range; e.picker = null;
      countDates(this, range);
    },
    evCancel() { this.u.dialog = null; this.render(); },
    evNoneOk() { this.u.dialog = null; this.render(); },
    evAdd() {
      const { from, to } = this.u.dialog;
      const e = ev(this);
      this.u.dialog = null;
      Object.assign(e, { phase: 'adding', adding: 'dates', range: { from, to } });
      this.render();
      later(this, 'ev', 500, () => finishAdd(this, from, to));
    },
  });

  /* Back closes the picker first, then the sheet. */
  const baseBack = RH.App.back;
  RH.App.back = function () {
    const e = ev(this);
    if (e && e.picker && !this.u.dialog) { e.picker = null; return this.render(); }
    return baseBack.call(this);
  };

  /* ------------------------------------------------------------------ */
  /* Gallery: screens 38–40                                              */
  /* ------------------------------------------------------------------ */
  const go = (u, route, p = {}) => { u.route = route; u.p = p; };
  const sheet = (u, extra = {}) => { u.sheet = { type: 'earlier', from: 'totag', phase: 'ready', ...extra }; };
  const pick = (u, pk) => { go(u, 'totag'); sheet(u, { picker: { from: null, to: null, view: D.ym(TODAY), ...pk } }); };
  const keepToday = (s, n) => { RH.evFind(s, TODAY, TODAY).slice(n).forEach((c) => { delete s.phone.clips[c.id]; }); };

  RH.SCREENS.push(
    {
      n: 38, id: 'earlier', title: 'Add earlier videos', group: 'Tagging',
      notes: [
        'For videos shot before Shooting mode was on (or before a new SD card was seen). Two ways in: a row on the Shooting mode card, and Add earlier videos in To tag\'s ⋮ menu (unchanged, full access only).',
        'The card row shows only while Shooting mode is on, access is full, and nothing was added this way in this Shooting session. It is the same row as References (TtCardRow: icon, title, one line, chevron) and sits under it, above the marigold strip. The line says why it is there: "Shot before Shooting mode was on".',
        'The sheet has two rows. Today adds at once and shows its count: none, 1 new, or N new. "none" turns the row off, but its text keeps AA contrast (on-surface-variant, not 38 % opacity) so it still reads. Choose dates… opens the calendar.',
        'While the Today count loads, its number is a skeleton and both rows are off. While dates are counted, the Choose dates… row shows them with "Checking…" and a spinner, and both rows are off.',
        'Clips already in To tag, Skipped or a reel never come back or move: the subtitle says so up front.',
        'At large text (font scale ≥ 1.5) a row\'s trailing count moves under its title (TtListRow stackTrailingAtLargeText), so nothing is cut at 2×.',
      ],
      spec: { 'Card row': 'Opens the sheet.', Today: 'Adds today\'s new videos at once, then the snack.', 'Choose dates…': 'Opens the date range picker (screen 39).', 'Try again': 'Counts again (for dates, the same dates).', 'Scrim, Back': 'Closes the sheet. Nothing is added.' },
      states: [
        { id: 'card', label: 'Card row on Reels', desc: 'Under References, above the "clips to tag" strip.', setup: () => {} },
        { id: 'card-norefs', label: 'Card row, no references', setup: (s) => { s.reels.forEach((r) => { r.refs = []; }); } },
        { id: 'card-used', label: 'After adding (row gone this session)', setup: (s) => { RH.evAdd(s, TODAY, TODAY); } },
        { id: 'menu', label: 'To tag ⋮ menu (unchanged)', setup: (s, u) => { go(u, 'totag'); u.menu = { type: 'totagMore' }; } },
        { id: 'sheet', label: 'Sheet: Today has new videos', setup: (s, u) => { go(u, 'totag'); sheet(u); } },
        { id: 'one', label: 'Today: 1 new', setup: (s, u) => { keepToday(s, 1); go(u, 'totag'); sheet(u); } },
        { id: 'none', label: 'Today: none (row off)', setup: (s, u) => { keepToday(s, 0); go(u, 'totag'); sheet(u); } },
        { id: 'loading', label: 'Loading the counts', setup: (s, u) => { go(u, 'totag'); sheet(u, { phase: 'loading' }); } },
        { id: 'error', label: "Error: couldn't check", setup: (s, u) => { go(u, 'totag'); sheet(u, { err: 'today' }); } },
        { id: 'counting', label: 'Counting the chosen dates', desc: 'Shown after Find videos; the dialog follows.', setup: (s, u) => { go(u, 'totag'); sheet(u, { phase: 'counting', range: { from: '2026-10-08', to: '2026-10-10' } }); } },
        { id: 'adding', label: 'Adding', setup: (s, u) => { go(u, 'totag'); sheet(u, { phase: 'adding', adding: 'dates', range: { from: '2026-10-08', to: '2026-10-10' } }); } },
        { id: 'big', label: '2× text: sheet', setup: (s, u) => { go(u, 'totag'); sheet(u); u.fs2 = true; } },
        { id: 'big-card', label: '2× text: card row', desc: 'The page scrolls; New reel and the navigation pill float over it.', setup: (s, u) => { u.fs2 = true; } },
      ],
    },
    {
      n: 39, id: 'date-range', title: 'Date range picker', group: 'Tagging',
      notes: [
        'TakeTray\'s own calendar instead of the stock picker, so every day is a 48 × 48 dp target: 7 × 48 = 336 dp fits 360 dp with 12 dp sides (the one place that uses space-3 instead of the 16 dp gutter). Wider phones share the extra width between the columns.',
        'Tap the first day, then the last. A tap before the first day moves the first day; a tap after a full range starts again. One day: tap it twice, or tap it once and Find videos. The line under the title always says what the next tap does.',
        'Future days, and days more than 10 years back, are off: on-surface-variant with a line through, at AA contrast in both themes. Days of the next and previous months fill the first and last rows, so a range across two months reads in one view.',
        'Months: the arrows (or a swipe on the grid). Years: tap the month name for a year and month grid. The next arrow stops at this month and the previous arrow at October 2016.',
        'Quick ranges (Yesterday, Last week, This month, Last month) only fill the calendar; nothing is counted until Find videos. Weeks start on the locale\'s first day.',
        'It opens on the last dates chosen in this sheet, so after "No new videos" a near miss is one tap to fix.',
      ],
      spec: { 'Day': 'First tap: the first day. Second: the last day.', 'Month name': 'Year and month grid; a month goes back to its days.', Clear: 'Removes the chosen days.', 'Find videos': 'Closes the picker and counts (screen 38, Counting). Off until a day is chosen.', 'Close, Back': 'Back to the sheet; nothing is counted.' },
      states: [
        { id: 'empty', label: 'Nothing picked', setup: (s, u) => pick(u, {}) },
        { id: 'start', label: 'First day picked', setup: (s, u) => pick(u, { from: '2026-10-08' }) },
        { id: 'range', label: 'A full range', setup: (s, u) => pick(u, { from: '2026-10-08', to: '2026-10-10' }) },
        { id: 'single', label: 'One day', setup: (s, u) => pick(u, { from: '2026-10-09', to: '2026-10-09' }) },
        { id: 'cross', label: 'A range across two months', desc: 'September\'s last days fill the first row.', setup: (s, u) => pick(u, { from: '2026-09-28', to: '2026-10-03' }) },
        { id: 'prev', label: 'Previous month', desc: 'After the ‹ arrow (or a swipe right). October\'s first days end the last row.', setup: (s, u) => pick(u, { from: '2026-09-28', to: '2026-10-03', view: '2026-09' }) },
        { id: 'jump', label: 'Month and year', desc: 'After tapping "October 2026".', setup: (s, u) => pick(u, { from: '2026-09-28', to: '2026-10-03', jump: true, jumpYear: 2026 }) },
        { id: 'jump-old', label: 'Ten years back', desc: 'Months before October 2016 are off.', setup: (s, u) => pick(u, { jump: true, jumpYear: 2016, view: '2016-10' }) },
        { id: 'first', label: 'The earliest month', desc: 'Days before 12 Oct 2016 are off; the ‹ arrow stops.', setup: (s, u) => pick(u, { view: '2016-10' }) },
        { id: 'quick', label: 'Quick range: Last week', setup: (s, u) => { const [a, b] = RH.evQuick('lastweek'); pick(u, { from: a, to: b }); } },
        { id: 'big', label: '2× text', setup: (s, u) => { pick(u, { from: '2026-10-08', to: '2026-10-10' }); u.fs2 = true; } },
        { id: 'big-jump', label: '2× text: month and year', setup: (s, u) => { pick(u, { jump: true, jumpYear: 2026 }); u.fs2 = true; } },
      ],
    },
    {
      n: 40, id: 'earlier-result', title: 'Add earlier videos: confirm and result', group: 'Tagging',
      notes: [
        'Chosen dates are always confirmed with a count before anything is added. Today skips the dialog: its count is already on the row.',
        'Cancel and OK go back to the sheet. Add closes the dialog, the row shows "Adding…", then the sheet closes.',
        'The snack stays 6 s (a bulk action). Undo takes back only the clips nobody has tagged or skipped since.',
        'The added clips join To tag in shooting order, so older days come first, under their own day headings.',
      ],
      spec: { Add: 'Adds the videos, closes the sheet, then the snack with Undo.', Cancel: 'Back to the sheet. Nothing is added.', OK: 'Back to the sheet.' },
      states: [
        { id: 'found', label: 'N videos found', setup: (s, u) => { go(u, 'totag'); sheet(u); u.dialog = { type: 'earlierFound', n: 7, from: '2026-10-08', to: '2026-10-10' }; } },
        { id: 'found-one', label: '1 video found', setup: (s, u) => { go(u, 'totag'); sheet(u); u.dialog = { type: 'earlierFound', n: 1, from: '2026-10-11', to: '2026-10-11' }; } },
        { id: 'none', label: 'No new videos (dates)', setup: (s, u) => { go(u, 'totag'); sheet(u); u.dialog = { type: 'earlierNone', from: '2026-10-10', to: '2026-10-11' }; } },
        { id: 'none-day', label: 'No new videos (one day)', setup: (s, u) => { go(u, 'totag'); sheet(u); u.dialog = { type: 'earlierNone', from: '2026-10-11', to: '2026-10-11' }; } },
        { id: 'added', label: 'Added, from To tag', setup: (s, u) => { RH.evAdd(s, '2026-10-08', '2026-10-10'); go(u, 'totag'); u.snack = { text: '7 clips added to To tag', undo: true, ic: 'check_circle' }; } },
        { id: 'added-card', label: 'Added, from the card', desc: 'The card row is gone and the strip counts the new clips.', setup: (s, u) => { RH.evAdd(s, TODAY, TODAY); u.snack = { text: '3 clips added to To tag', undo: true, ic: 'check_circle' }; } },
        { id: 'add-fail', label: "Error: couldn't add", setup: (s, u) => { go(u, 'totag'); u.snack = { text: "Couldn't add videos. Try again." }; } },
        { id: 'undo-fail', label: "Error: couldn't undo", setup: (s, u) => { RH.evAdd(s, '2026-10-08', '2026-10-10'); go(u, 'totag'); u.snack = { text: "Couldn't undo. Try again." }; } },
        { id: 'big', label: '2× text: dialog', setup: (s, u) => { go(u, 'totag'); sheet(u); u.dialog = { type: 'earlierFound', n: 7, from: '2026-10-08', to: '2026-10-10' }; u.fs2 = true; } },
        { id: 'big-none', label: '2× text: no new videos', setup: (s, u) => { go(u, 'totag'); sheet(u); u.dialog = { type: 'earlierNone', from: '2026-10-10', to: '2026-10-11' }; u.fs2 = true; } },
        { id: 'big-snack', label: '2× text: snack', setup: (s, u) => { RH.evAdd(s, '2026-10-08', '2026-10-10'); go(u, 'totag'); u.snack = { text: '7 clips added to To tag', undo: true, ic: 'check_circle' }; u.fs2 = true; } },
      ],
    },
  );
})();
