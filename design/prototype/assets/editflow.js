/* Sending clips to an editor, simplified (owner request, 25 Nov 2026, D-172).
   Before: "Edit video" opened a separate "Pick clips to edit" screen with nothing ticked (pick, then Continue);
   holding a clip started selection with Edit hidden in the ⋮ menu, which opened that same picking screen again.
   Now:
   - Edit video opens the editor sheet at once with ALL the reel's clips ("Edit all 14 clips in…"), the usual case.
     "Choose clips instead" in the sheet starts choosing on the reel page itself.
   - Holding a clip starts choosing on the reel page; a bottom bar shows a big "Edit 3 clips" button (straight to the
     editor sheet) and Share, Add to, Move, Remove with labels. The ⋮ menu is gone.
   - The editor sheet puts the editor used last at the top, marked "Last used".
   - The separate picking screen stays only for adding clips to a running VN edit (screen 18). */
(function () {
  const RH = window.RH;
  const { fmt, q, h } = RH;
  const { esc, icon } = h;
  const order = (s, ids) => ids.slice().sort((a, b) => (s.clips[a].at < s.clips[b].at ? -1 : 1));

  /* --------------------------------------- Reel page while choosing */
  const baseReel = RH.routes.reel;
  RH.routes.reel = (s, u) => {
    const r = baseReel(s, u);
    if (!(u.sel && u.sel.ctx === 'reel') || !r || !r.html) return r;
    const reel = q.reel(s, u.p.id);
    if (!reel) return r;
    const ids = u.sel.ids;
    const live = q.liveClipsOf(s, reel.id).map((c) => c.id);
    const allOn = ids.length > 0 && ids.length === live.length;
    const none = !ids.length;
    // Top: Close, the count, Select all (Clear when every clip is chosen). The actions move to the bottom bar.
    const bar = h.appbar({ title: none ? 'Choose clips' : `${ids.length} selected`, nav: 'close', navA: 'clearSel', sel: true, actions: h.btn({ label: allOn ? 'Clear' : 'Select all', ic: allOn ? 'deselect' : 'select_all', kind: 'text', cls: 'sd-all', a: allOn ? 'selNone' : 'selAll', aria: allOn ? 'Clear' : 'Select all' }) });
    let html = r.html.replace(/<header class="appbar[\s\S]*?<\/header>/, bar);
    const clips = ids.map((id) => s.clips[id]);
    const act = (ic, label, a) => `<button class="sd-act tap" ${none ? 'aria-disabled="true"' : `data-a="${a}"`}>${icon(ic)}<span>${label}</span></button>`;
    const edit = reel.vn
      ? `<p class="sd-note">${icon('info')}<span>This reel is being edited in VN. Tap Done editing at the top before sending clips again.</span></p>`
      : `<button class="btn filled lg block tap sd-edit" ${none ? 'aria-disabled="true"' : 'data-a="selEditGo"'} aria-label="${none ? 'Edit: choose clips first' : `Edit ${fmt.n(ids.length, 'clip')}, ${fmt.dur(q.total(clips))}`}">${icon('movie_edit')}<span>${none ? 'Tap the clips you want to edit' : `Edit ${fmt.n(ids.length, 'clip')}`}</span>${none ? '' : `<span class="sd-len">${fmt.dur(q.total(clips))}</span>`}</button>`;
    const dock = `<div class="sel-dock" role="toolbar" aria-label="Chosen clips"><div class="sd-acts">${act('share', 'Share', 'share')}${act('library_add', 'Add to', 'selAddTo')}${act('drive_file_move', 'Move', 'selMove')}${act('playlist_remove', 'Remove', 'selRemove')}</div>${edit}</div>`;
    const hint = none && u.sel.from === 'editor' ? `<div class="banner info sd-hint" role="status">${icon('touch_app')}<div class="grow"><b>Tap the clips you want to edit</b><span>Next time, hold a clip to start choosing straight away.</span></div></div>` : '';
    html = html.replace(`data-scroll="reel-${reel.id}">`, `data-scroll="reel-${reel.id}">${hint}`);
    html = html.replace('<div class="end-space"></div>', '<div class="end-space" style="height:190px"></div>');
    html = html.replace(/<\/div>\s*$/, `${dock}</div>`);
    return { ...r, html };
  };

  /* ------------------------------------------------- Editor sheet */
  const ROWS = [
    ['capcut', 'CapCut', () => 'Gets your original clips'],
    ['edits', 'Instagram Edits', () => 'Gets your original clips'],
    ['vn', 'VN', (clips) => `Makes temporary copies · ${fmt.size(q.sizeOf(clips))}`],
    ['other', 'Other app…', () => "Opens Android's share menu"],
  ];
  RH.sheets.editor = (s, u) => {
    const e = u.sheet;
    const clips = e.ids.map((id) => s.clips[id]);
    const inst = s.editorsInstalled;
    const last = s.lastEditor && (s.lastEditor === 'other' || inst[s.lastEditor]) ? s.lastEditor : null;
    const rows = last ? [ROWS.find((x) => x[0] === last), ...ROWS.filter((x) => x[0] !== last)] : ROWS;
    const row = ([key, name, sub]) => {
      const ok = key === 'other' || inst[key];
      return `<button class="li tall tap ${ok ? '' : 'dis'}" ${ok ? `data-a="pickEditor" data-ed="${key}"` : 'aria-disabled="true"'} aria-label="${esc(name)}${key === last ? ', last used' : ''}${ok ? '' : ', not installed'}">${h.editorIcon(key)}<span class="txt"><b>${name}${key === last ? '<span class="ed-last">Last used</span>' : ''}</b><span>${ok ? sub(clips) : 'Not installed'}</span></span>${ok ? icon('chevron_right') : ''}</button>`;
    };
    const n = clips.length;
    const title = e.all && n > 1 ? `Edit all ${fmt.n(n, 'clip')} in…` : `Edit ${fmt.n(n, 'clip')} in…`;
    const choose = e.all && n > 1 ? `<button class="btn text sm tap ed-choose" data-a="edChoose">${icon('checklist')}<span>Choose clips instead</span></button>` : '';
    return `<div class="sheet ${e.fresh ? 'fresh' : ''}" role="dialog" aria-modal="true" aria-labelledby="ed-t"><div class="handle"></div><div class="sh-head"><h2 id="ed-t">${title}</h2><p>${fmt.dur(q.total(clips))} · in shooting order</p>${choose}</div>
      <div class="sh-body" style="padding-bottom:12px">${rows.map(row).join('')}
      ${!inst.capcut || !inst.edits || !inst.vn ? '<p class="t-bs v" style="margin:8px 24px 0">Editors you don\'t have are greyed out.</p>' : ''}</div></div>`;
  };

  /* ------------------------------------------------------- Actions */
  const A = RH.ACTIONS;
  const open = (app, sheet) => { app.u.menu = null; app.u.sheet = { type: 'editor', fresh: true, ...sheet }; app.render(); app.u.sheet.fresh = false; };
  A.editVideo = function () {
    const id = this.u.p.id;
    open(this, { id, ids: order(this.s, q.liveClipsOf(this.s, id).map((c) => c.id)), all: true });
    this.log('Every clip of the reel, in shooting order. "Choose clips instead" to send only some.');
  };
  A.selEditGo = function () {
    const ids = order(this.s, (this.u.sel && this.u.sel.ids) || []);
    if (ids.length) open(this, { id: this.u.p.id, ids });
  };
  A.selEdit = A.selEditGo; // the old ⋮ item, if anything still calls it
  A.edChoose = function () {
    this.u.sheet = null;
    this.u.sel = { ctx: 'reel', ids: [], from: 'editor' };
    this.render();
    this.log('Tap the clips you want, then Edit.');
  };
  A.selNone = function () { this.u.sel.ids = []; this.render(); };
  /* Choosing that started from the sheet stays on, even with nothing chosen, until Close. */
  const baseToggle = A.toggleSel;
  A.toggleSel = function (d, el) {
    const sel = this.u.sel;
    if (sel && sel.from === 'editor' && sel.ids.length === 1 && sel.ids[0] === d.id) { sel.ids = []; return this.render(); }
    return baseToggle.call(this, d, el);
  };
  /* Remember the editor, and send from the reel page without the old picking screen in the history. */
  const basePick = A.pickEditor;
  A.pickEditor = function (d, el) {
    this.s.lastEditor = d.ed;
    if (this.u.route === 'edit-select') return basePick.call(this, d, el);
    const e = this.u.sheet;
    if (d.ed === 'other') return basePick.call(this, d, el);
    if (d.ed === 'vn') { this.u.sel = null; return basePick.call(this, d, el); }
    const name = d.ed === 'capcut' ? 'CapCut' : 'Instagram Edits';
    this.u.sheet = null; this.u.sel = null;
    this.snack(`Sent ${fmt.n(e.ids.length, 'clip')} to ${name}`, { ic: 'open_in_new' });
    this.log(`${name} would open now with the original clips, in shooting order.`);
    this.render();
    const r = q.reel(this.s, e.id);
    if (r && r.status === 'rec') this.timers.mark = setTimeout(() => { this.u.dialog = { type: 'markStatus', id: e.id, status: 'ready' }; this.render(); }, 1300);
  };

  /* ------------------------------------------------ Gallery updates */
  const go = (u, route, p = {}) => { u.route = route; u.p = p; };
  const ids = (s, rid) => q.liveClipsOf(s, rid).map((c) => c.id);
  const find = (id) => RH.SCREENS.find((x) => x.id === id);

  const s8 = find('reel-detail');
  if (s8) {
    s8.notes = s8.notes.concat([
      'Choosing clips (D-172): hold a clip, or "Choose clips instead" in the editor sheet. The top bar shows Close, "{n} selected" and Select all (Clear when every clip is chosen). A bar slides up at the bottom: Share, Add to, Move and Remove with labels, and a big "Edit {n} clips" with their length, which opens the editor sheet straight away. No ⋮ menu, no second picking screen.',
      'While the reel is being edited in VN, the bar keeps the four actions and says to tap Done editing first instead of offering Edit (R1).',
    ]);
    s8.spec = Object.assign({}, s8.spec, { 'Edit video': 'Opens the editor sheet with every clip of the reel.', 'Long-press tile': 'Starts choosing, with that clip; the bottom bar offers Edit {n} clips.' });
    const at = s8.states.findIndex((x) => x.id === 'select');
    s8.states[at] = { id: 'select', label: 'Choosing clips (after holding one)', setup: (s, u) => { go(u, 'reel', { id: 'r1' }); const x = ids(s, 'r1'); u.sel = { ctx: 'reel', ids: [x[1], x[2], x[5]] }; } };
    s8.states.splice(at + 1, 0,
      { id: 'select-none', label: 'Choose clips (from the editor sheet)', setup: (s, u) => { go(u, 'reel', { id: 'r1' }); u.sel = { ctx: 'reel', ids: [], from: 'editor' }; } },
      { id: 'select-all', label: 'Every clip chosen', setup: (s, u) => { go(u, 'reel', { id: 'r1' }); u.sel = { ctx: 'reel', ids: ids(s, 'r1') }; } },
      { id: 'select-vn', label: 'Choosing while editing in VN', setup: (s, u) => { go(u, 'reel', { id: 'r3' }); const x = ids(s, 'r3'); u.sel = { ctx: 'reel', ids: [x[0], x[1]] }; } },
      { id: 'select-big', label: '2× text: choosing', setup: (s, u) => { go(u, 'reel', { id: 'r1' }); const x = ids(s, 'r1'); u.sel = { ctx: 'reel', ids: [x[1], x[2], x[5]] }; u.fs2 = true; } },
    );
  }

  const s18 = find('edit-select');
  if (s18) {
    s18.title = 'Add clips to a VN edit';
    s18.notes = ['Since D-172 this screen is only for adding clips to a reel that is being edited in VN ("Add more clips" on the editing banner). Choosing clips to send to an editor happens on the reel page itself.', 'Clips already copied are marked "In VN folder" and stay ticked; only new clips are copied, and nothing is renamed.'];
    s18.states = s18.states.filter((x) => x.id === 'vnadd');
  }

  const s19 = find('choose-editor');
  if (s19) {
    s19.notes = [
      'Opens straight from Edit video with every clip of the reel ("Edit all 14 clips in…"), or from the choosing bar with the clips chosen ("Edit 3 clips in…"). Clips go in shooting order.',
      '"Choose clips instead" (only with every clip) closes the sheet and starts choosing on the reel page.',
      'The editor used last comes first, marked "Last used", so the usual send is two taps: Edit video, then the editor.',
      'Only CapCut, Instagram Edits and VN, plus "Other app…" for the Android share menu. Editors that aren\'t installed are greyed out with "Not installed", so the list never changes shape. Real app icons come from the system.',
    ];
    s19.states = [
      { id: 'all', label: 'Edit video: every clip', setup: (s, u) => { go(u, 'reel', { id: 'r1' }); u.sheet = { type: 'editor', id: 'r1', ids: ids(s, 'r1'), all: true }; } },
      { id: 'some', label: 'From chosen clips', setup: (s, u) => { go(u, 'reel', { id: 'r1' }); const x = ids(s, 'r1'); u.sel = { ctx: 'reel', ids: [x[1], x[2], x[5]] }; u.sheet = { type: 'editor', id: 'r1', ids: [x[1], x[2], x[5]] }; } },
      { id: 'last', label: 'Last used first', desc: 'After sending to Instagram Edits once.', setup: (s, u) => { s.lastEditor = 'edits'; go(u, 'reel', { id: 'r1' }); u.sheet = { type: 'editor', id: 'r1', ids: ids(s, 'r1'), all: true }; } },
      { id: 'missing', label: 'CapCut not installed', setup: (s, u) => { s.editorsInstalled.capcut = false; go(u, 'reel', { id: 'r1' }); u.sheet = { type: 'editor', id: 'r1', ids: ids(s, 'r1'), all: true }; } },
      { id: 'share', label: 'Other app: share menu', setup: (s, u) => { go(u, 'reel', { id: 'r1' }); u.sheet = { type: 'share', n: ids(s, 'r1').length }; } },
      { id: 'big', label: '2× text', setup: (s, u) => { s.lastEditor = 'capcut'; go(u, 'reel', { id: 'r1' }); u.sheet = { type: 'editor', id: 'r1', ids: ids(s, 'r1'), all: true }; u.fs2 = true; } },
    ];
  }
})();
