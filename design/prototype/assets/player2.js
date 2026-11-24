/* Tag player: the full-screen design (owner's pick, 24 Nov 2026, D-171).
   The owner found the first design (screen 12 v1) awkward: a vertical clip showed at 203 × 360 of a 360 × 800 screen,
   between blurred copies of itself, over four stacked bands of controls. Of three layouts tried (A full screen,
   B clip card, C trays), the owner chose A and dropped B and C.
   - The clip fills the screen, edge to edge, under the status bar; no blur, ever.
   - Top, on a scrim: progress, Close, "3 of 23" with ‹ › on either side, the scene line, Mute.
   - Bottom, on a scrim: the reel dock (up to three Collecting reels + New reel; All reels opens the rest), with the
     scrub line above it and Skip / Same as previous on the right, under the thumb.
   - Next / previous: swipe up / down (as in Reels), or ‹ ›.
   It uses the prototype's own tagging actions (chip, pickChip, skipClip, sameAsPrev, undo…). The v1 layout is kept
   as one comparison state on screen 12 (pv: 'current'). */
(function () {
  const RH = window.RH;
  const { fmt, q, h } = RH;
  const { esc, icon } = h;
  const base = RH.routes.player;

  /* ---------------------------------------------------------- Model */
  function model(s, u) {
    const P = u.player;
    const id = P.session[P.i];
    const clip = s.clips[id];
    const scenes = q.scenes(s, P.session);
    const scIdx = scenes.findIndex((sc) => sc.ids.includes(id));
    const total = P.session.length;
    const waitingAt = (dir) => { for (let j = P.i + dir; j >= 0 && j < total; j += dir) if (s.toTag.includes(P.session[j])) return P.session[j]; return null; };
    const segs = total <= 40 ? P.session.map((cid, k) => `<i class="${k === P.i ? 'cur' : !s.toTag.includes(cid) ? 'done' : ''}"></i>`).join('') : `<i class="done" style="flex:${P.i}"></i><i class="cur" style="flex:1"></i><i style="flex:${total - P.i - 1}"></i>`;
    const reels = q.orderedReels(s);
    const prev = s.lastTags.filter((rid) => q.reel(s, rid));
    return {
      P, id, clip, scenes, sc: scenes[scIdx], scIdx, total, segs, prevId: waitingAt(-1), nextId: waitingAt(1),
      rec: reels.filter((r) => r.status === 'rec'), others: reels.filter((r) => r.status !== 'rec'),
      prev, sameNames: prev.map((rid) => q.reel(s, rid).name).join(', '),
      multi: P.multi, loading: P.loading, paused: P.paused, long: clip.dur > 120, horiz: clip.orient === 'h',
    };
  }
  const stateOf = (m, r) => (m.P.confirm === r.id ? 'done' : m.multi && m.P.picked.includes(r.id) ? 'pick' : '');
  const chip = (s, m, r, cls = '') => h.reelChip(r, s, { state: stateOf(m, r), multi: m.multi, a: m.multi ? 'pickChip' : 'chip' }).replace('class="rchip tap', `class="rchip tap ${cls}`);
  const thumb = (c) => RH.thumb(c.theme, c.seed, c.orient);
  /** An icon button that is off at the ends of the session: dimmed, announced as unavailable, not tappable. */
  const ibOff = (ic, o, off) => { const b = h.ib(ic, o); return off ? b.replace('class="ib tap', 'aria-disabled="true" class="ib tap off') : b; };
  const where = (m) => `Scene ${m.scIdx + 1} of ${m.scenes.length} · ${fmt.range(m.sc.start, m.sc.end)}`;

  /* The clip: a vertical clip covers the screen; a horizontal one is shown whole, on black. */
  const vid = (m) => `<button class="p2-vid cover ${m.horiz ? 'h' : ''} ${m.paused ? 'paused' : ''}" data-a="togglePlay" aria-label="${m.paused ? 'Play' : 'Pause'} clip, ${fmt.time(m.clip.at)}, ${fmt.dur(m.clip.dur)}" style="--clipdur:${m.clip.dur}s"><img class="${m.loading || m.paused ? '' : 'play'}" src="${thumb(m.clip)}" alt="">${m.paused ? `<span class="ctr">${icon('play_arrow', 'fill')}</span>` : ''}${m.loading ? '<span class="ld"><span class="spin"></span></span>' : ''}</button>`;
  const scrub = (m) => `<div class="scrub p2-scrub ${m.long ? 'big' : ''}" style="--clipdur:${m.clip.dur}s"><span>${m.loading ? '0:00' : m.long ? '1:12' : '0:00'}</span><span class="trk">${m.long ? '<i style="width:26%"></i><b style="left:26%"></b><span class="hint">Drag to skim · 4:32 clip</span>' : `<i class="${m.loading || m.paused ? '' : 'play'}"></i>`}</span><span>${fmt.dur(m.clip.dur)}</span></div>`;
  const snack = (u) => (u.snack ? `<div class="p2-snack">${h.snack({ ...u.snack })}</div>` : '');

  const top = (m) => `<div class="p2-top"><div class="pbar" aria-hidden="true">${m.segs}</div><div class="p2-bar">
      ${h.ib('close', { a: 'closePlayer', label: 'Close tagging' })}
      <div class="p2-mid">${ibOff('chevron_left', { a: 'prevClip', label: 'Previous clip' }, !m.prevId)}<div class="p2-where" aria-live="polite"><b>${m.P.i + 1} of ${m.total}</b><span>${where(m)}</span></div>${ibOff('chevron_right', { a: 'nextClip', label: 'Next clip' }, !m.nextId)}</div>
      ${h.ib(m.P.muted ? 'volume_off' : 'volume_up', { a: 'toggleMute', label: m.P.muted ? 'Unmute' : 'Mute', pressed: !m.P.muted })}</div></div>`;

  const rail = (m) => `<div class="p2-rail">
      <button class="p2-rb tap" data-a="skipClip" aria-label="Skip this clip">${icon('redo')}<span>Skip</span></button>
      <button class="p2-rb tap ${m.prev.length ? '' : 'dis'}" data-a="sameAsPrev"${m.prev.length ? ` aria-label="Same as previous: ${esc(m.sameNames)}"` : ' aria-disabled="true" aria-label="Same as previous: nothing tagged yet"'}>${icon('repeat')}<span>Same</span>${m.prev.length ? `<small>${esc(m.sameNames)}</small>` : ''}</button></div>`;

  const allBtn = (m) => (m.rec.length > 3 || m.others.length ? `<button class="btn text sm tap p2-all" data-a="p2All">${icon('apps')}<span>All reels</span></button>` : '');
  const severalBtn = (s) => (s.reels.length > 1 ? `<button class="btn text sm tap" data-a="multiOn" aria-pressed="false">${icon('library_add_check')}<span>Pick several</span></button>` : '');
  const newCell = (cls = '') => `<button class="rchip new tap ${cls}" data-a="newReelPlayer" aria-label="New reel"><span class="cv">${icon('add')}</span><span class="t"><b>New reel</b><span>Add this clip to it</span></span></button>`;
  const noReels = `<div class="p2-none t-bm">You don't have any reels yet. Create one and this clip goes into it.</div><button class="rchip new tap dk p2-wide" data-a="newReelPlayer"><span class="cv">${icon('add')}</span><span class="t" style="flex:none"><b>New reel</b></span></button>`;

  function full(s, u, m) {
    // Dock: up to three Collecting reels (newest first) + New reel. Picking several also shows any picked reel from All reels.
    const cells = m.multi ? m.rec.slice(0, 3).concat(m.others.concat(m.rec.slice(3)).filter((r) => m.P.picked.includes(r.id))) : m.rec.slice(0, 3);
    const grid = !s.reels.length ? noReels : cells.map((r) => chip(s, m, r, 'dk')).join('') + (m.multi ? '' : newCell('dk'));
    const head = m.multi
      ? `<b>Pick reels</b>${allBtn(m)}${h.btn({ label: 'Cancel', kind: 'text', a: 'multiOff' })}`
      : `<b>Add to reel</b>${severalBtn(s)}${allBtn(m)}`;
    const foot = m.multi ? `<div class="p2-foot">${h.btn({ label: m.P.picked.length ? `Add to ${fmt.n(m.P.picked.length, 'reel')} & next` : 'Pick one or more reels', kind: 'filled', size: 'block', a: 'multiConfirm', dis: !m.P.picked.length })}</div>` : '';
    return `<div class="scr rh-dark p2 p2-full ${u.anim ? 'anim-' + u.anim : ''}" style="background:#000">
      <div class="p2-stage">${vid(m)}</div>
      ${top(m)}
      <div class="p2-dock" role="group" aria-label="Reels">${m.multi ? '' : rail(m)}${snack(u)}${scrub(m)}<div class="p2-dh">${head}</div><div class="p2-grid">${grid}</div>${foot}</div></div>`;
  }

  RH.routes.player = (s, u) => {
    const P = u.player;
    if (!P || P.done || P.pv === 'current') return base(s, u);
    return { video: true, html: full(s, u, model(s, u)) };
  };

  /* All reels: every reel, New reel, and Pick several's Done. */
  RH.sheets.p2All = (s, u) => {
    const m = model(s, u);
    const sec = (title, list) => (list.length ? `<div class="lbl">${title}</div>${list.map((r) => chip(s, m, r)).join('')}` : '');
    return `<div class="sheet rh-dark ${u.sheet.fresh ? 'fresh' : ''}" role="dialog" aria-modal="true" aria-labelledby="p2a-t"><div class="handle"></div>
      <div class="sh-head"><h2 id="p2a-t">${m.multi ? 'Pick reels for this clip' : 'Add to reel'}</h2></div>
      <div class="sh-body"><div class="chipgrid p2-sheetgrid">${sec('Collecting', m.rec)}${newCell()}${sec('Other reels', m.others)}</div>
      ${m.multi ? `<div style="padding:8px 4px 0">${h.btn({ label: 'Done', kind: 'filled', size: 'block', a: 'closeSheet' })}</div>` : ''}</div></div>`;
  };

  const A = RH.ACTIONS;
  const baseChip = A.chip;
  A.p2All = function () { this.u.sheet = { type: 'p2All', fresh: true }; this.render(); this.u.sheet.fresh = false; };
  /* A reel tapped in All reels closes the sheet first, then tags as usual. */
  A.chip = function (d, el) {
    if (this.u.sheet && this.u.sheet.type === 'p2All') { this.u.sheet = null; this.render(); }
    return baseChip.call(this, d, el);
  };

  /* ------------------------------------------- Screen 12, redesigned */
  const sc = RH.SCREENS.find((x) => x.id === 'tag-player');
  if (sc) {
    const go = (u, route, p = {}) => { u.route = route; u.p = p; };
    const player = (s, u, i, extra = {}) => { go(u, 'player'); u.player = { session: s.toTag.slice(), i, multi: false, picked: [], muted: true, paused: false, tagged: {}, skippedN: 0, ...extra }; };
    const tagFirst = (s, n, rid) => { s.toTag.slice(0, n).forEach((id) => { s.clips[id].reels.push(rid); }); s.toTag = s.toTag.slice(n); };
    sc.notes = [
      'Redesigned 24 Nov 2026 (owner\'s pick, D-171). The first design showed a vertical clip at 203 × 360 of a 360 × 800 screen, between blurred copies of itself, over four stacked bands of controls; it felt cramped. The last state below shows it for comparison.',
      'Always dark, on black. The clip fills the screen edge to edge, under the status bar, like Instagram Reels: a vertical clip covers it (on a 20:9 phone about 9–10 % of each side is trimmed, as in Reels). A clip that would lose more than 20 % that way (horizontal, square, 3:4) is shown whole on black. Never blurred.',
      'Top, on a scrim: the progress segments, Close, "3 of 23" with ‹ › on either side, the scene line (it wraps rather than being cut), Mute.',
      'Bottom, on a scrim: the scrub line, then the reel dock: "Add to reel", Pick several and All reels, then up to three Collecting reels (newest first) and New reel, two per row. All reels opens a sheet with every reel.',
      'Skip and Same as previous are on the right, just above the dock, under the thumb, on dark glass so they read on any clip. The snack ("Added to London Food · Undo") sits above the dock and stops short of them.',
      'Next / previous without tagging: swipe up / down, as in Reels (horizontal swipes are left to Android\'s back gesture), or ‹ ›.',
      'Tapping a reel: a tick for 400 ms, then the next clip slides up. Text on the scrims and the glass stays ≥ 4.5:1 even over a white frame.',
    ];
    sc.spec = { 'Tap a reel': 'Tag, a tick for 400 ms, then the next clip slides up. Snack "Added to London Food · Undo".', 'Long-press a reel': 'Pick several, with that reel ticked.', 'Swipe up / down': 'Next / previous clip without tagging.', '‹ ›': 'Previous / next clip.', 'Tap the clip': 'Play / pause.', 'All reels': 'A sheet with every reel and New reel.', Skip: 'Skip, then the snack with Undo.', 'Same as previous': 'Tag into the reels the previous clip went to.' };
    const at = sc.states.findIndex((x) => x.id === 'done');
    sc.states.splice(at < 0 ? sc.states.length : at, 0,
      { id: 'all', label: 'All reels', desc: 'From "All reels" in the dock: every reel, by status, and New reel.', setup: (s, u) => { player(s, u, 0); u.sheet = { type: 'p2All' }; } },
      { id: 'paused', label: 'Paused', setup: (s, u) => { const sess = s.toTag.slice(); tagFirst(s, 1, 'r1'); s.lastTags = ['r1']; player(s, u, 1, { session: sess, paused: true }); } },
      { id: 'big', label: '2× text', desc: 'The dock grows; what doesn\'t fit is in All reels.', setup: (s, u) => { const sess = s.toTag.slice(); tagFirst(s, 1, 'r1'); s.lastTags = ['r1']; player(s, u, 1, { session: sess }); u.fs2 = true; } },
    );
    sc.states.push({ id: 'v1', label: 'Previous design (v1), for comparison', setup: (s, u) => { const sess = s.toTag.slice(); tagFirst(s, 1, 'r1'); s.lastTags = ['r1']; player(s, u, 1, { session: sess, pv: 'current' }); } });
  }
})();
