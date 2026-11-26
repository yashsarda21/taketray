/* Home (Reels tab): the calm grid (owner's pick, 25 Nov 2026, D-187).
   The owner liked Home but wanted it cleaner to use and smoother to feel. Of three options (A calm grid, B shelves,
   C list), the owner chose A and dropped B and C. Compared with the previous Home:
   - the Shooting mode card is compact: on, one row with the switch, then Open camera and two quiet chips
     (References, Earlier videos); off, one row that also says how many clips are still to tag;
   - no "N clips to tag" strip (D-186) and no separate To tag banner: the To tag tab's badge carries the count;
   - New reel is a "+ New" button in the header, not a button floating over the reels;
   - quiet tabs (the chosen one filled) instead of outlined filter chips;
   - each reel: the cover alone, then its name, one status mark and plain details under it (no stacked badges).
   The previous Home is kept as one comparison state on screen 6 (u.p.hv: 'current'). */
(function () {
  const RH = window.RH;
  const { fmt, q, h } = RH;
  const { esc, icon } = h;
  const base = RH.routes.home;

  const LABEL = { rec: 'Collecting', ready: 'Ready to edit', pub: 'Published' };
  const ICON = { rec: 'radio_button_checked', ready: 'content_cut', pub: 'check_circle' };
  const sorted = (s) => s.reels.slice().sort((a, b) => (a.created < b.created ? 1 : a.created > b.created ? -1 : 0));

  /* One reel: the cover, then name, status and details as plain text. */
  function card(s, r) {
    const clips = q.clipsOf(s, r.id);
    const live = clips.filter((c) => !c.missing);
    const missing = clips.length - live.length;
    const refs = (r.refs || []).length;
    const meta = clips.length ? `${fmt.n(clips.length, 'clip')} · ${fmt.dur(q.total(live))}` : 'No clips yet';
    const extra = [r.vn ? `<span class="h2-x vn">${icon('folder_copy', 'fill')}In VN</span>` : '', missing ? `<span class="h2-x er">${icon('error', 'fill')}${missing} missing</span>` : '', refs ? `<span class="h2-x">${icon('link')}${refs}</span>` : ''].filter(Boolean).join('');
    const label = `${r.name}. ${LABEL[r.status]}. ${clips.length} clips${missing ? `, ${missing} missing` : ''}${r.vn ? '. Editing in VN' : ''}${refs ? `. ${fmt.n(refs, 'reference')}` : ''}`;
    const cover = live[0] ? `<span class="h2-cv">${h.img(live[0])}</span>` : `<span class="h2-cv empty">${icon('movie')}</span>`;
    return `<button class="h2-card tap" data-a="openReel" data-id="${r.id}" aria-label="${esc(label)}">${cover}<span class="h2-cap"><b class="clamp2">${esc(r.name)}</b><span class="h2-st ${r.status}">${icon(ICON[r.status], 'fill')}${LABEL[r.status]}</span><span class="h2-meta">${meta}</span>${extra ? `<span class="h2-xs">${extra}</span>` : ''}</span></button>`;
  }

  /* The compact Shooting mode card. */
  function shoot(s) {
    const n = s.toTag.length;
    if (!s.shooting.on) {
      const sub = n ? `Off · ${fmt.n(n, 'clip')} still to tag` : 'Off · turn it on before you film';
      return `<section class="h2-shoot off" aria-label="Shooting mode"><span class="h2-ico">${icon('videocam', 'fill')}</span><div class="h2-txt"><b>Shooting mode</b><span>${sub}</span></div>${h.sw(false, { a: 'toggleShoot', label: 'Shooting mode' })}</section>`;
    }
    const latestId = s.toTag[s.toTag.length - 1];
    const latest = latestId ? s.clips[latestId] : Object.values(s.clips).find((c) => !c.missing);
    const refN = RH.recRefCount ? RH.recRefCount(s) : 0;
    const chips = [
      refN ? `<button class="h2-chip tap" data-a="openRefsSheet" aria-label="References, ${refN}, from your Collecting reels">${icon('link')}<span>References · ${refN}</span></button>` : '',
      s.access === 'full' && !s.earlierUsed ? `<button class="h2-chip tap" data-a="openEarlier" data-from="card" aria-label="Add earlier videos, shot before Shooting mode was on">${icon('history')}<span>Earlier videos</span></button>` : '',
    ].join('');
    return `<section class="h2-shoot on" aria-label="Shooting mode, on">${latest ? `<span class="h2-media" aria-hidden="true">${h.img(latest)}</span>` : ''}
      <div class="h2-row"><span class="h2-ico">${icon('videocam', 'fill')}<span class="recdot live"></span></span><div class="h2-txt"><b>Shooting</b><span>Since ${fmt.time(s.shooting.since)}${s.access !== 'full' ? ' · Manual mode' : ''}</span></div>${h.sw(true, { a: 'toggleShoot', label: 'Shooting mode', inv: true })}</div>
      <div class="h2-row2"><button class="h2-cam tap" data-a="openCamera">${icon('videocam')}<span>Open camera</span></button>${chips}</div></section>`;
  }

  function calm(s, u) {
    const head = h.appbar({ title: 'Reels', big: true, actions: `<button class="h2-new tap" data-a="newReel" aria-label="New reel">${icon('add')}<span>New</span></button>` });
    let body;
    if (!s.reels.length) {
      body = h.empty({ ill: 'noreels', title: 'Plan your first reel', body: "A reel is a video you're planning, like London Food or Day 1 Vlog. Clips you tag go into it.", acts: h.btn({ label: 'New reel', ic: 'add', a: 'newReel' }) });
    } else {
      const counts = q.counts(s);
      const f = u.filter || 'all';
      const tab = (id, label) => `<button class="h2-tab tap ${f === id ? 'on' : ''}" data-a="filter" data-f="${id}" aria-pressed="${f === id}">${label}<span>${counts[id]}</span></button>`;
      const list = sorted(s).filter((r) => f === 'all' || r.status === f);
      body = `<div class="h2-tabs" role="group" aria-label="Show reels">${tab('all', 'All')}${tab('rec', 'Collecting')}${tab('ready', 'Ready')}${tab('pub', 'Published')}</div>
        ${list.length ? `<div class="h2-grid">${list.map((r) => card(s, r)).join('')}</div>` : `<div class="h2-none"><p>No reels marked ${LABEL[f]} yet.</p>${h.btn({ label: 'Show all reels', kind: 'tonal', a: 'filter', d: { f: 'all' } })}</div>`}`;
    }
    const access = RH.accessBanner ? RH.accessBanner(s) : '';
    const tip = u.hint === 'shoot' ? `<div class="tooltip right" style="right:16px;top:${access ? 226 : 154}px" role="note"><b>Going out to shoot?</b>Turn on Shooting mode first. New videos will wait in To tag.<br>${h.btn({ label: 'Got it', kind: 'text', a: 'dismissHint' })}</div>` : '';
    return { nav: 'home', html: `<div class="scr h2 h2-calm">${head}<div class="scroll" data-scroll="home">${access}${shoot(s)}${body}<div class="end-space"></div></div>${tip}${h.navbar('home', s.toTag.length)}</div>` };
  }

  RH.routes.home = (s, u) => ((u.p && u.p.hv === 'current') ? base(s, u) : calm(s, u));

  /* -------------------------------------------- Screen 6, redesigned */
  const s6 = RH.SCREENS.find((x) => x.id === 'home');
  if (s6) {
    s6.notes = [
      'Redesigned 25 Nov 2026 (owner\'s pick of three, D-187): cleaner to use and smoother to feel. The last state below shows the previous Home for comparison.',
      'The Shooting mode card is compact. On: one row (REC dot, "Shooting", "Since 9:12 am", the switch), then Open camera and two quiet chips, References · 4 and Earlier videos (each only when it applies). Off: one row whose line says how many clips are still to tag ("Off · 23 clips still to tag").',
      'No "N clips to tag" strip and no separate To tag banner (D-186): the To tag tab\'s badge carries the count.',
      'New reel is "+ New" in the header (tonal pill), so nothing floats over the reels.',
      'Quiet tabs: All · Collecting · Ready · Published with counts; the chosen one filled (secondaryContainer), the others plain text. They scroll sideways if they don\'t fit.',
      'Reel cards in two columns: the 3:4 cover alone (no overlays), then the name (2 lines), one status mark (icon + word, never colour alone), "14 clips · 5:30", and a line only when it applies: In VN, N missing, references.',
      'Smooth: the big "Reels" title shrinks into the bar as the page scrolls; cards press to 98 %; opening a reel grows it from its cover (container transform, 400 ms); covers have a fixed size so nothing jumps while they load.',
    ];
    s6.spec = { 'Tap a reel': 'Opens the reel (container transform).', 'Switch': 'Shooting mode on or off; on stamps "Since" the time.', 'Open camera': 'The phone\'s camera.', 'References · 4': 'The References sheet.', 'Earlier videos': 'Add earlier videos.', '+ New': 'New reel form.', Tabs: 'Show one status; an empty one offers "Show all reels".' };
    const go = (u, p) => { u.route = 'home'; u.p = p; };
    s6.states.push(
      { id: 'big', label: '2× text', setup: (s, u) => { u.fs2 = true; } },
      { id: 'previous', label: 'Previous Home, for comparison', setup: (s, u) => go(u, { hv: 'current' }) },
    );
  }
})();
