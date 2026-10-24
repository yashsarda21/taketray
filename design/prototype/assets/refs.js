/* Reference reels (add-on 1): links to reels a creator wants to recreate,
   saved inside one of their own reels. Data helpers, components, sheets,
   the share-from-Instagram entry point, and their prototype actions. */
(function () {
  const RH = window.RH;
  const { fmt, q, h } = RH;
  const { esc, icon } = h;

  /* ------------------------------------------------------------------ */
  /* Links and sources                                                   */
  /* ------------------------------------------------------------------ */
  /** First link in shared text ("Look at this https://…"), or null. */
  RH.findUrl = function (text) {
    const t = String(text || '');
    const m = t.match(/https?:\/\/[^\s<>"']+/i) || t.match(/\b(?:www\.)?[a-z0-9-]+(?:\.[a-z0-9-]+)+\/[^\s<>"']*/i);
    if (!m) return null;
    let u = m[0].replace(/[).,!]+$/, '');
    if (!/^https?:/i.test(u)) u = 'https://' + u;
    try { new URL(u); return u; } catch (e) { return null; }
  };
  /** Comparable form: no protocol, www, tracking query or trailing slash. */
  RH.normLink = (url) => String(url).replace(/^https?:\/\/(www\.|m\.)?/i, '').replace(/[?#].*$/, '').replace(/\/$/, '').toLowerCase();
  RH.shortLink = (url) => String(url).replace(/^https?:\/\/(www\.|m\.)?/i, '').replace(/[?#].*$/, '').replace(/\/$/, '');
  RH.src = function (url) {
    let u;
    try { u = new URL(url); } catch (e) { return { key: 'link', name: 'Link', label: 'Link' }; }
    const host = u.hostname.replace(/^(www|m)\./, '');
    const path = u.pathname;
    if (/(^|\.)instagram\.com$/.test(host)) {
      const kind = /^\/reels?\//.test(path) ? 'reel' : /^\/p\//.test(path) ? 'post' : /^\/tv\//.test(path) ? 'video' : 'profile';
      return { key: 'instagram', name: 'Instagram', label: `Instagram ${kind}`, letter: 'I' };
    }
    if (/(^|\.)(youtube\.com|youtu\.be)$/.test(host)) return { key: 'youtube', name: 'YouTube', label: path.startsWith('/shorts') ? 'YouTube Short' : 'YouTube video', letter: 'Y' };
    if (/(^|\.)tiktok\.com$/.test(host)) return { key: 'tiktok', name: 'TikTok', label: 'TikTok video', letter: 'T' };
    return { key: 'link', name: 'Link', label: host };
  };
  RH.refsOf = (reel) => (reel ? reel.refs || (reel.refs = []) : []);
  RH.recRefs = (s) => s.reels.filter((r) => r.status === 'rec' && RH.refsOf(r).length);
  RH.recRefCount = (s) => RH.recRefs(s).reduce((t, r) => t + r.refs.length, 0);

  /* Sample shared content for the share-from-Instagram flow. */
  RH.SHARES = {
    reel: { label: 'An Instagram reel', text: 'https://www.instagram.com/reel/DBf2kQ9sLmA/?igsh=MTZ4bWQ1' },
    dup: { label: 'A reel already in London Food', text: 'https://www.instagram.com/reel/C9xL2pQhR4a/?igsh=NDg3' },
    post: { label: 'An Instagram post', text: 'https://www.instagram.com/p/DAq81LxsT2c/' },
    yt: { label: 'A YouTube Short', text: 'https://youtube.com/shorts/q8Yb2LmT0sE?si=4kd' },
    text: { label: 'Caption text (not a link)', text: 'Best breakfast in London 🔥 bacon naan at Dishoom, worth the queue' },
  };

  /* Fixture: four references across the Recording reels, one on Day 1 Vlog. */
  const baseFixture = RH.fixture;
  RH.fixture = function () {
    const s = baseFixture();
    let n = 0;
    const add = (rid, url, label, added) => RH.refsOf(q.reel(s, rid)).push({ id: 'ref' + ++n, url, label, added });
    s.reels.forEach((r) => { r.refs = []; });
    add('r1', 'https://www.instagram.com/reel/C9xL2pQhR4a/', 'Fast cuts, food close-ups', '2026-10-08');
    add('r1', 'https://www.instagram.com/reel/DAb7Tq1sK0e/', '', '2026-10-09');
    add('r2', 'https://youtube.com/shorts/q8Yb2LmT0sE', 'Golden hour slow pans', '2026-10-07');
    add('r4', 'https://www.instagram.com/reel/C_r4ngLiTm0/', 'Rangoli time-lapse from above', '2026-10-11');
    add('r3', 'https://www.instagram.com/p/C8vL0gT7xYz/', 'Talk-to-camera framing', '2026-10-05');
    s.clipboard = 'https://www.instagram.com/reel/DA3kP0sxYz1/?igsh=MWQ1ZGUx';
    s.apps = { instagram: true, youtube: true, tiktok: false };
    return s;
  };

  /* ------------------------------------------------------------------ */
  /* Components                                                          */
  /* ------------------------------------------------------------------ */
  /** Source icon: the phone supplies the real app icon; the prototype shows a lettered placeholder. */
  h.srcIcon = function (src, size = 40) {
    if (!src.letter) return `<span class="srcic link" style="width:${size}px;height:${size}px" aria-hidden="true">${icon('link', size < 30 ? 's16' : '')}</span>`;
    return `<span class="srcic" style="width:${size}px;height:${size}px;font-size:${Math.round(size * 0.42)}px" aria-hidden="true" title="${esc(src.name)} app icon from the phone">${src.letter}</span>`;
  };

  /** A reference is a designed card, not a thumbnail: TakeTray never fetches the video or its preview. */
  h.refCard = function (ref, reel, { menu = true } = {}) {
    const src = RH.src(ref.url);
    const link = RH.shortLink(ref.url);
    const title = ref.label || link;
    const sub = ref.label ? `${src.label} · ${link}` : src.label;
    return `<div class="refcard" id="ref-${ref.id}"><button class="ref-main tap" data-a="openRef" data-rid="${reel.id}" data-ref="${ref.id}" aria-label="Open reference: ${esc(title)}, ${esc(src.label)}">
      <span class="ref-art" aria-hidden="true">${icon('play_arrow', 'fill')}<span class="ref-src">${h.srcIcon(src, 18)}</span></span>
      <span class="ref-t"><b>${esc(title)}</b><span>${esc(sub)}</span></span><span class="ref-open">${icon('open_in_new')}Open</span></button>
      ${menu ? h.ib('more_vert', { a: 'refMenu', d: { rid: reel.id, ref: ref.id }, label: `More options for ${title}` }) : ''}</div>`;
  };

  /** The References section on reel detail. */
  h.refsSection = function (reel, s, u) {
    const refs = RH.refsOf(reel);
    if (!refs.length) {
      return `<button class="ref-add tap" id="refs-sec" data-a="addRef" data-rid="${reel.id}">${icon('add_link')}<span class="grow"><b>Add reference</b><span>Save a reel you want to recreate</span></span>${icon('add')}</button>`;
    }
    const prompt = !reel.desc ? `<div class="callout ref-prompt">${icon('edit_note', 'fill')}<div class="grow"><b>Write the shots you need</b>Watch your references, then list the shots to get while you're out.<div>${h.btn({ label: 'Write shot ideas', kind: 'text', a: 'editShots', d: { id: reel.id } })}</div></div></div>` : '';
    return `<section class="refs ${u.p.focus === 'refs' ? 'flash' : ''}" id="refs-sec" aria-labelledby="refs-h"><div class="refs-h"><h2 id="refs-h" class="t-ts" style="margin:0">References · ${refs.length}</h2><span class="grow"></span>${h.btn({ label: 'Add', ic: 'add', kind: 'text', size: 'sm', a: 'addRef', d: { rid: reel.id } })}</div>
      ${refs.map((r) => h.refCard(r, reel)).join('')}${prompt}</section>`;
  };

  /* ------------------------------------------------------------------ */
  /* Routes: the app you share from, and Android's share menu            */
  /* ------------------------------------------------------------------ */
  RH.routes['ext-app'] = () => ({
    video: true,
    html: `<div class="scr" style="background:#000"><div class="extapp"><img class="ext-vid" src="${RH.thumb('food', 412, 'v')}" alt="A food reel playing in another app">
      <span class="ext-tag">${icon('info', 's16')}Instagram, shown as a plain video app</span>
      <div class="ext-hint"><b>You're in Instagram</b>Tap Share on a reel you like, then choose TakeTray.</div>
      <button class="ext-share tap" data-a="extShare">${icon('share')}<span>Share</span></button></div></div>`,
  });

  const sheets = RH.sheets;

  sheets.sysShare = (s, u) => {
    const link = RH.findUrl(u.sheet.text);
    const apps = [['tt', 'TakeTray'], ['share', 'Quick Share'], ['sms', 'Messages'], ['mail', 'Gmail'], ['add_to_drive', 'Drive'], ['bluetooth', 'Bluetooth'], ['folder', 'Files'], ['more_horiz', 'More']];
    return `<div class="sheet ${u.sheet.fresh ? 'fresh' : ''}" role="dialog" aria-modal="true" aria-label="Android share menu"><div class="handle"></div>
      <div class="sh-head"><h2>Share</h2><p>Android's share menu, drawn by the system</p></div>
      <div class="sys-link">${icon(link ? 'link' : 'notes')}<span class="grow clamp1">${esc(link ? RH.shortLink(link) : u.sheet.text)}</span><span class="pill" style="background:var(--md-surface-container-highest)">Copy</span></div>
      <div class="share-grid">${apps.map(([ic, n]) => ic === 'tt'
        ? `<button class="tap" data-a="shareToTT" style="display:flex;flex-direction:column;align-items:center;gap:6px;border-radius:12px;padding:4px 0">${h.brandIcon(48, 'tray', 'circle')}<b class="t-bs">TakeTray</b></button>`
        : `<div><span class="appic-g own" style="background:var(--md-surface-container-highest);color:var(--md-on-surface)">${icon(ic)}</span>${n}</div>`).join('')}</div></div>`;
  };

  sheets.saveRef = (s, u) => {
    const f = u.sheet;
    const fresh = f.fresh ? 'fresh' : '';
    if (f.step === 'notlink') {
      return `<div class="sheet ${fresh}" role="dialog" aria-modal="true" aria-labelledby="sr-t"><div class="handle"></div><div class="sh-body pad24" style="display:flex;flex-direction:column;gap:12px;padding-bottom:8px">
        <span class="ms s40" style="color:var(--md-tertiary)" aria-hidden="true">link_off</span><h2 id="sr-t" class="t-tl" style="margin:0">This isn't a link</h2>
        <p class="t-bm v" style="margin:0">TakeTray saves links to reels and videos. This looks like a caption:</p>
        <blockquote class="quote">${esc(f.text)}</blockquote>
        <p class="t-bm v" style="margin:0">In Instagram, tap <b>Share</b> on the reel itself, then choose TakeTray. Nothing was saved.</p></div>
        <div class="sh-foot">${h.btn({ label: 'Close', kind: 'filled', a: 'saveDone' })}</div></div>`;
    }
    if (f.step === 'done') {
      const reel = q.reel(s, f.saved);
      const first = !s.onboarded;
      return `<div class="sheet ${fresh}" role="dialog" aria-modal="true" aria-labelledby="sr-t"><div class="handle"></div><div class="sh-body pad24" style="display:flex;flex-direction:column;align-items:center;text-align:center;gap:8px;padding-bottom:12px">
        <span class="okc">${icon('check', 's32')}</span><h2 id="sr-t" class="t-hs" style="margin:6px 0 0">Saved to ${esc(reel.name)}</h2>
        <p class="t-bm v" style="margin:0">${esc(f.savedLabel || RH.src(f.url).label)}</p>
        ${first ? '<div class="callout" style="text-align:left;margin-top:8px"><span class="ms" aria-hidden="true">waving_hand</span><div><b>Welcome to TakeTray</b>Next time you open the app, it takes about a minute to set up the rest.</div></div>' : ''}</div>
        <div class="sh-foot">${h.btn({ label: 'Open reel', kind: 'tonal', a: 'saveOpenReel' })}${h.btn({ label: 'Done', kind: 'filled', a: 'saveDone' })}</div></div>`;
    }
    const src = RH.src(f.url);
    const hasReels = s.reels.length > 0;
    const mode = hasReels ? f.mode : 'new';
    const already = (r) => RH.refsOf(r).some((x) => RH.normLink(x.url) === RH.normLink(f.url));
    const rows = (list) => list.map((r) => { const c = q.cover(s, r.id); const on = f.pick === r.id; const n = RH.refsOf(r).length; return `<button class="li tap" data-a="savePick" data-id="${r.id}" role="radio" aria-checked="${on}"><span class="thumb" style="width:36px;height:48px">${c ? h.img(c) : icon('movie')}</span><span class="txt"><b class="clamp1">${esc(r.name)}</b><span>${already(r) ? 'Already saved here' : n ? fmt.n(n, 'reference') : fmt.n(q.clipsOf(s, r.id).length, 'clip')}</span></span><span class="radio ${on ? 'on' : ''}"></span></button>`; }).join('');
    const ordered = q.orderedReels(s);
    const rec = ordered.filter((r) => r.status === 'rec');
    const other = ordered.filter((r) => r.status !== 'rec');
    const pickReel = f.pick && q.reel(s, f.pick);
    const dup = mode === 'existing' && pickReel && already(pickReel);
    const seg = hasReels ? `<div class="segbtn" role="tablist" aria-label="Where to save"><button class="tap ${mode === 'existing' ? 'on' : ''}" role="tab" aria-selected="${mode === 'existing'}" data-a="saveMode" data-m="existing">${mode === 'existing' ? icon('check', 's18') : ''}Existing reel</button><button class="tap ${mode === 'new' ? 'on' : ''}" role="tab" aria-selected="${mode === 'new'}" data-a="saveMode" data-m="new">${mode === 'new' ? icon('check', 's18') : ''}New reel</button></div>` : '<p class="t-bm v" style="margin:0 24px 4px">You don\'t have any reels yet. Name one for this reference.</p>';
    const body = mode === 'existing'
      ? `${rec.length ? `<div class="li-h" style="padding-top:4px">Recording</div>${rows(rec)}` : ''}${other.length ? `<div class="li-h">Other reels</div>${rows(other)}` : ''}`
      : `<div class="pad24">${h.tf({ id: 'srname', label: 'New reel name', value: f.name || '', ph: 'For example: London Food', focus: u.kbd && f.focus !== 'label', err: f.err, counter: 40, a: 'saveName' })}</div>`;
    const canSave = mode === 'new' ? true : !!f.pick && !dup;
    return `<div class="sheet ${fresh}" role="dialog" aria-modal="true" aria-labelledby="sr-t" style="max-height:${u.kbd ? '97%' : '90%'}"><div class="handle"></div>
      <div class="sh-head" style="padding-bottom:8px"><h2 id="sr-t">Save reference</h2></div>
      <div class="srcrow">${h.srcIcon(src, 40)}<span class="grow" style="min-width:0"><b>${esc(src.label)}</b><span class="clamp1">${esc(RH.shortLink(f.url))}</span></span></div>
      <div class="pad24" style="padding-bottom:4px">${h.tf({ id: 'srlabel', label: 'Label (optional)', value: f.label || '', ph: 'Fast cuts, food close-ups', counter: 60, focus: u.kbd && f.focus === 'label', a: 'saveLabel' })}</div>
      <div class="t-ts" style="padding:4px 24px 8px">Save to</div>${seg}<div class="sh-body">${body}</div>
      ${dup ? `<div class="banner warn" role="alert" style="margin:0 16px 8px">${icon('info', 'fill')}<div class="grow"><b>Already saved in ${esc(pickReel.name)}</b><span>Pick another reel, or open this one.</span></div>${h.btn({ label: 'Open reel', kind: 'text', a: 'saveOpenDup' })}</div>` : ''}
      <div class="sh-foot">${h.btn({ label: 'Cancel', kind: 'text', a: 'saveDone' })}${h.btn({ label: 'Save', kind: 'filled', a: 'saveRefSave', dis: !canSave })}</div>${u.kbd ? h.keyboard() : ''}</div>`;
  };

  sheets.addRef = (s, u) => {
    const f = u.sheet;
    const reel = q.reel(s, f.rid);
    const edit = !!f.refId;
    const ref = edit ? RH.refsOf(reel).find((x) => x.id === f.refId) : null;
    const clipLink = !edit && !f.link && !f.noOffer && s.clipboard && RH.findUrl(s.clipboard);
    const offer = clipLink ? `<div class="clipoffer">${icon('content_paste')}<div class="grow" style="min-width:0"><b>Paste link from clipboard?</b><span class="clamp1">${esc(RH.shortLink(clipLink))}</span></div>${h.btn({ label: 'Paste', kind: 'tonal', size: 'sm', a: 'pasteClip' })}</div>` : '';
    const top = edit
      ? `<div class="srcrow" style="margin:0">${h.srcIcon(RH.src(ref.url), 40)}<span class="grow" style="min-width:0"><b>${esc(RH.src(ref.url).label)}</b><span class="clamp1">${esc(RH.shortLink(ref.url))}</span></span></div>`
      : `${offer}${h.tf({ id: 'rflink', label: 'Link', value: f.link || '', ph: 'https://www.instagram.com/reel/…', focus: u.kbd && f.focus !== 'label', err: f.err, help: 'Instagram, YouTube or any other link', a: 'refLink' })}`;
    return `<div class="sheet ${f.fresh ? 'fresh' : ''}" role="dialog" aria-modal="true" aria-labelledby="ar-t" style="max-height:${u.kbd ? '97%' : '90%'}"><div class="handle"></div>
      <div class="sh-head"><h2 id="ar-t">${edit ? 'Edit label' : 'Add reference'}</h2><p>${edit ? esc(reel.name) : `to ${esc(reel.name)}`}</p></div>
      <div class="sh-body pad24" style="display:flex;flex-direction:column;gap:8px;padding-bottom:12px">${top}
      ${h.tf({ id: 'rflabel', label: 'Label (optional)', value: f.label != null ? f.label : ref ? ref.label : '', ph: 'Fast cuts, food close-ups', counter: 60, focus: u.kbd && (edit || f.focus === 'label'), a: 'refLabel' })}</div>
      <div class="sh-foot">${h.btn({ label: 'Cancel', kind: 'text', a: 'closeSheet' })}${h.btn({ label: 'Save', kind: 'filled', a: 'addRefSave' })}</div>${u.kbd ? h.keyboard() : ''}</div>`;
  };

  sheets.refsList = (s, u) => {
    const reels = RH.recRefs(s);
    const closed = u.sheet.closed || [];
    const groups = reels.map((r) => {
      const open = !closed.includes(r.id);
      const c = q.cover(s, r.id);
      const shots = r.desc
        ? `<div class="rg-shots"><span class="lbl">${icon('lightbulb', 's16')}Shot ideas</span><p>${esc(r.desc)}</p></div>`
        : `<div class="rg-shots none"><span>No shot ideas yet.</span>${h.btn({ label: 'Write the shots you need', kind: 'text', size: 'sm', a: 'editShotsFor', d: { id: r.id } })}</div>`;
      return `<section class="rgroup" aria-label="${esc(r.name)}"><div class="rg-h"><button class="rg-name tap" data-a="refsGoReel" data-id="${r.id}"><span class="thumb">${c ? h.img(c) : icon('movie')}</span><span class="grow" style="min-width:0"><b class="clamp1">${esc(r.name)}</b><span>${fmt.n(r.refs.length, 'reference')}</span></span>${icon('chevron_right')}</button>${h.ib(open ? 'expand_less' : 'expand_more', { a: 'refsToggle', d: { id: r.id }, label: open ? `Hide ${r.name} details` : `Show ${r.name} details` })}</div>
        ${open ? `${shots}<div class="rg-refs">${r.refs.map((x) => h.refCard(x, r, { menu: false })).join('')}</div>` : ''}</section>`;
    }).join('');
    return `<div class="sheet ${u.sheet.fresh ? 'fresh' : ''}" role="dialog" aria-modal="true" aria-labelledby="rl-t" style="max-height:92%"><div class="handle"></div>
      <div class="sh-head"><h2 id="rl-t">References</h2><p>From your Recording reels, with their shot ideas</p></div>
      <div class="sh-body" style="padding:0 16px 16px;display:flex;flex-direction:column;gap:12px">${groups || '<p class="t-bm v">No references in your Recording reels.</p>'}</div></div>`;
  };

  RH.menus.refMenu = (s, u) => `<div class="menu" role="menu" style="right:16px;top:${u.menu.top || 300}px"><button class="mi tap" role="menuitem" data-a="refEdit">${icon('edit')}Edit label</button><button class="mi tap" role="menuitem" data-a="refCopy">${icon('content_copy')}Copy link</button><button class="mi tap" role="menuitem" data-a="refRemove">${icon('delete')}Remove</button></div>`;

  /* ------------------------------------------------------------------ */
  /* Prototype actions                                                   */
  /* ------------------------------------------------------------------ */
  const A = RH.ACTIONS;
  const findRef = (s, rid, id) => RH.refsOf(q.reel(s, rid)).find((x) => x.id === id);
  let refSeq = 100;

  Object.assign(A, {
    extShare() { this.u.sheet = { type: 'sysShare', text: RH.SHARES[this.shareKey || 'reel'].text, fresh: true }; this.render(); },
    shareToTT() {
      const text = this.u.sheet.text;
      const url = RH.findUrl(text);
      if (!url) { this.u.sheet = { type: 'saveRef', step: 'notlink', text, fresh: true }; return this.render(); }
      const hasReels = this.s.reels.length > 0;
      this.u.sheet = { type: 'saveRef', step: 'form', text, url, mode: hasReels ? 'existing' : 'new', pick: null, name: '', label: '', fresh: true };
      if (!hasReels) { this.u.kbd = true; this.u.focus = 'srname'; }
      this.render();
    },
    saveMode(d) { const f = this.u.sheet; f.mode = d.m; f.err = null; this.u.kbd = d.m === 'new'; if (d.m === 'new') this.u.focus = 'srname'; this.render(); },
    savePick(d) { this.u.sheet.pick = d.id; this.render(); },
    saveRefSave() {
      const f = this.u.sheet;
      const s = this.s;
      const mode = s.reels.length ? f.mode : 'new';
      let rid;
      if (mode === 'new') {
        const err = this.validName(f.name);
        if (err) { f.err = err; this.u.focus = 'srname'; return this.render(); }
        rid = this.newReel(f.name.trim());
        if (!s.onboarded) q.reel(s, rid).pre = true;
      } else {
        rid = f.pick;
        if (!rid) return;
      }
      const reel = q.reel(s, rid);
      if (RH.refsOf(reel).some((x) => RH.normLink(x.url) === RH.normLink(f.url))) return this.render();
      RH.refsOf(reel).push({ id: 'ref' + ++refSeq, url: f.url, label: (f.label || '').trim().slice(0, 60), added: RH.TODAY });
      Object.assign(f, { step: 'done', saved: rid, savedLabel: (f.label || '').trim(), fresh: false });
      this.u.kbd = false;
      this.render();
    },
    saveDone() { this.u.sheet = null; this.u.kbd = false; this.log(this.u.route === 'ext-app' ? 'Back in Instagram.' : ''); this.render(); },
    saveOpenDup() { const rid = this.u.sheet.pick; this.u.sheet = null; this.u.kbd = false; this.openReelFromShare(rid); },
    saveOpenReel() { const rid = this.u.sheet.saved; this.u.sheet = null; this.u.kbd = false; this.openReelFromShare(rid); },

    openRef(d) {
      const ref = findRef(this.s, d.rid, d.ref);
      const src = RH.src(ref.url);
      const inApp = src.letter && this.s.apps[src.key];
      this.snack(inApp ? `Opens in ${src.name}` : 'Opens in your browser', { ic: 'open_in_new' });
      this.log(inApp ? `${src.name} would open at ${RH.shortLink(ref.url)}.` : `${src.name === 'Link' ? 'The link' : src.name + " isn't installed, so it"} opens in the browser. No error.`);
      this.render();
    },
    refMenu(d, el) {
      let top = 300;
      if (el) { const vp = this.phone.querySelector('.vp'); const z = parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--pz')) || 1; top = (el.getBoundingClientRect().bottom - vp.getBoundingClientRect().top) / z - 4; if (top > 560) top -= 200; }
      this.u.menu = { type: 'refMenu', rid: d.rid, ref: d.ref, top };
      this.render();
    },
    refEdit() { const m = this.u.menu; const ref = findRef(this.s, m.rid, m.ref); this.u.menu = null; this.u.sheet = { type: 'addRef', rid: m.rid, refId: ref.id, label: ref.label, fresh: true }; this.u.kbd = true; this.u.focus = 'rflabel'; this.render(); },
    refCopy() { const m = this.u.menu; this.s.clipboard = findRef(this.s, m.rid, m.ref).url; this.u.menu = null; this.snack('Link copied', { ic: 'content_copy' }); this.render(); },
    refRemove() {
      const m = this.u.menu;
      this.snapshot();
      const reel = q.reel(this.s, m.rid);
      reel.refs = reel.refs.filter((x) => x.id !== m.ref);
      this.u.menu = null;
      this.snack('Reference removed', { undo: true }); this.render();
    },
    addRef(d) { this.u.sheet = { type: 'addRef', rid: d.rid, link: '', label: '', fresh: true }; this.render(); },
    pasteClip() { const f = this.u.sheet; f.link = RH.findUrl(this.s.clipboard); f.err = null; f.focus = 'label'; this.u.kbd = true; this.u.focus = 'rflabel'; this.render(); },
    addRefSave() {
      const f = this.u.sheet;
      const reel = q.reel(this.s, f.rid);
      if (f.refId) {
        findRef(this.s, f.rid, f.refId).label = (f.label || '').trim().slice(0, 60);
        this.u.sheet = null; this.u.kbd = false; this.snack('Label saved'); return this.render();
      }
      const url = RH.findUrl(f.link);
      if (!url) { f.err = "That isn't a link. In Instagram: Share › Copy link, then paste it here."; this.u.focus = 'rflink'; return this.render(); }
      if (RH.refsOf(reel).some((x) => RH.normLink(x.url) === RH.normLink(url))) { f.err = `Already saved in ${reel.name}`; return this.render(); }
      this.snapshot();
      RH.refsOf(reel).push({ id: 'ref' + ++refSeq, url, label: (f.label || '').trim().slice(0, 60), added: RH.TODAY });
      this.u.sheet = null; this.u.kbd = false;
      this.snack('Reference saved', { undo: true, ic: 'check_circle' }); this.render();
    },
    openRefs(d) { this.nav('reel', { id: d.id, focus: 'refs' }); },
    openRefsSheet() { this.u.sheet = { type: 'refsList', closed: [], fresh: true }; this.render(); },
    refsToggle(d) { const c = this.u.sheet.closed; const i = c.indexOf(d.id); if (i >= 0) c.splice(i, 1); else c.push(d.id); this.render(); },
    refsGoReel(d) { this.u.sheet = null; this.nav('reel', { id: d.id, focus: 'refs' }); },
    editShots(d) { const r = q.reel(this.s, d.id); this.u.sheet = { type: 'reelForm', mode: 'edit', id: r.id, name: r.name, desc: r.desc, status: r.status, focus: 'desc', fresh: true }; this.u.kbd = true; this.u.focus = 'rdesc'; this.render(); },
    editShotsFor(d) { this.u.sheet = null; this.nav('reel', { id: d.id }); A.editShots.call(this, d); },
  });

  RH.INPUTS = Object.assign(RH.INPUTS || {}, {
    saveName(app, v) { app.u.sheet.name = v; },
    saveLabel(app, v) { app.u.sheet.label = v; },
    refLink(app, v) { app.u.sheet.link = v; },
    refLabel(app, v) { app.u.sheet.label = v; },
    formRef(app, v) { app.u.sheet.ref = v; },
  });
  RH.ENTER = Object.assign(RH.ENTER || {}, { saveName: 'saveRefSave', saveLabel: 'saveRefSave', refLink: 'addRefSave', refLabel: 'addRefSave' });
})();
