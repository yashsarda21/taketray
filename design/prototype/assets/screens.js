/* TakeTray screens. Each route renders the whole phone content from
   (s = data store, u = UI state). The screen galleries and the interactive
   prototype share these functions, so they can never drift apart. */
(function () {
  const RH = (window.RH = window.RH || {});
  const { fmt, q, h } = RH;
  const { esc, icon } = h;

  RH.defaultUI = () => ({
    route: 'home', p: {}, filter: 'all', sel: null, sheet: null, dialog: null, menu: null,
    sys: null, snack: null, shade: null, kbd: false, player: null, hint: null, otherOpen: false,
  });

  const selIds = (u) => (u.sel ? u.sel.ids : []);
  const isSel = (u, id) => !!u.sel && u.sel.ids.includes(id);

  /* ------------------------------------------------------------------ */
  /* Shared blocks                                                       */
  /* ------------------------------------------------------------------ */
  function accessBanner(s) {
    if (s.access === 'full') return '';
    if (s.access === 'removed') {
      return `<div class="banner warn" role="alert">${icon('no_photography')}<div class="grow"><b>TakeTray can't see your videos</b><span>Allow access to find new clips.</span></div>${h.btn({ label: 'Allow', kind: 'text', a: 'allowAccess' })}</div>`;
    }
    return `<div class="banner info">${icon('lock')}<div class="grow"><b>Manual mode</b><span>New clips aren't found automatically.</span></div>${h.btn({ label: 'Allow full access', kind: 'text', a: 'allowAccess' })}</div>`;
  }

  function shootingCard(s, u) {
    const on = s.shooting.on;
    const n = s.toTag.length;
    if (!on) {
      return `<section class="shoot ${u.hint === 'shoot' ? 'hint' : ''}" aria-label="Shooting mode"><div class="top"><span class="ico">${icon('videocam', 'fill')}</span><div class="txt"><b>Shooting mode</b><span>Off. Turn on before you start filming, and new videos wait in To tag.</span></div>${h.sw(false, { a: 'toggleShoot', label: 'Shooting mode' })}</div></section>`;
    }
    const manual = s.access !== 'full';
    const refN = RH.recRefCount ? RH.recRefCount(s) : 0;
    const latestId = s.toTag[s.toTag.length - 1];
    const latest = latestId ? s.clips[latestId] : Object.values(s.clips).find((c) => !c.missing);
    return `<section class="shoot on" aria-label="Shooting mode, on">${latest ? `<span class="shoot-media" aria-hidden="true">${h.img(latest)}</span>` : ''}<div class="top"><span class="ico">${icon('videocam', 'fill')}<span class="recdot live"></span></span><div class="txt"><b>Shooting mode on</b><span>On since ${fmt.time(s.shooting.since)}${manual ? ' · Manual mode: add clips yourself' : ''}</span></div>${h.sw(true, { a: 'toggleShoot', label: 'Shooting mode', inv: true })}</div>
      <div class="acts">${h.btn({ label: 'Open camera', ic: 'videocam', kind: 'filled', cls: 'camb', a: 'openCamera' })}</div>
      ${refN ? `<button class="refrow tap" data-a="openRefsSheet" aria-label="References, ${refN}, from your Recording reels">${icon('link')}<span class="grow"><b>References · ${refN}</b><span>From ${RH.fmt.n(RH.recRefs(s).length, 'Recording reel')}</span></span>${icon('chevron_right')}</button>` : ''}
      ${s.access === 'full' && !s.earlierUsed ? `<button class="refrow tap" data-a="openEarlier" data-from="card" aria-label="Add earlier videos, shot before Shooting mode was on">${icon('history')}<span class="grow"><b>Add earlier videos</b><span>Shot before Shooting mode was on</span></span>${icon('chevron_right')}</button>` : ''}
      ${n ? `<button class="strip tap" data-a="tab" data-tab="totag">${icon('sell', 'fill')}<span class="grow">${fmt.n(n, 'clip')} to tag</span><span>Tag now</span>${icon('arrow_forward')}</button>` : ''}</section>`;
  }

  /** Extended FAB; sits above the navigation bar on tab screens and lifts over a snackbar. */
  function fab(label, ic, a, cls = '', { nav, snack } = {}) {
    const bottom = (nav ? 96 : 16) + (snack ? 64 : 0);
    return `<button class="fab ext tap ${cls}" data-a="${a}" style="bottom:${bottom}px">${icon(ic)}<span>${esc(label)}</span></button>`;
  }

  /* ------------------------------------------------------------------ */
  /* Routes                                                              */
  /* ------------------------------------------------------------------ */
  const routes = (RH.routes = {});

  routes.splash = () => ({ html: `<div class="scr"><div class="splash">${h.brandIcon(144, 'tray', 'circle')}<div class="wm">TakeTray</div></div></div>`, splash: true });

  function obDots(i) {
    return `<div class="steps-dots" aria-label="Step ${i + 1} of 4">${[0, 1, 2, 3].map((k) => `<i class="${k === i ? 'on' : ''}"></i>`).join('')}</div>`;
  }

  routes['ob-welcome'] = (s) => {
    const pool = Object.values(s.clips).slice(0, 18);
    const bg = (c) => `background-image:url(&quot;${RH.thumb(c.theme, c.seed, 'v')}&quot;)`;
    const gal = pool.map((c) => `<i style="${bg(c)}"></i>`).join('');
    const rl = (name, a, b) => `<div class="rl"><b>${name}</b><div class="stk"><i style="left:0;top:4px;${bg(pool[a])};transform:rotate(-6deg)"></i><i style="left:18px;top:0;${bg(pool[b])}"></i></div></div>`;
    return {
      html: `<div class="scr"><div class="ob"><div class="art" role="img" aria-label="Clips from a busy gallery flying into reels named London Food, Cinematic and Day 1 Vlog"><div class="fly"><div class="gal">${gal}</div>
        <i class="mover m1" style="${bg(pool[3])}"></i><i class="mover m2" style="${bg(pool[8])}"></i><i class="mover m3" style="${bg(pool[13])}"></i>
        <div class="reels">${rl('London Food', 4, 5)}${rl('Cinematic', 0, 1)}${rl('Day 1 Vlog', 9, 10)}</div></div></div>
        <div class="body"><h1>Every clip you shoot, sorted into the right reel</h1>
        <div class="points"><div>${icon('videocam')}<div><b>Turn on Shooting mode</b><span>Then film with your phone's camera, as usual.</span></div></div>
        <div>${icon('sell')}<div><b>Tag clips into reels</b><span>One tap per clip, on the bus or in the evening.</span></div></div>
        <div>${icon('movie_edit')}<div><b>Send a reel to your editor</b><span>CapCut, Instagram Edits or VN.</span></div></div></div></div>
        <div class="foot">${h.btn({ label: 'Get started', kind: 'filled', size: 'lg block', a: 'obNext', d: { to: 'ob-video' } })}</div></div></div>`,
    };
  };

  routes['ob-video'] = (s, u) => {
    const st = u.p.state || 'before';
    const allowLabel = s.android >= 14 ? 'Allow all' : 'Allow';
    let art = h.illus('perm'), title, body, extra = '', foot;
    if (st === 'before') {
      title = 'Let TakeTray see your videos';
      body = 'To find new clips you shoot, TakeTray needs access to all your videos.';
      extra = `<div class="callout">${icon('shield', 'fill')}<div><b>Your videos stay on your phone</b>TakeTray only reads them. It never uploads, moves or deletes them.</div></div>`;
      foot = h.btn({ label: 'Allow access', kind: 'filled', size: 'lg block', a: 'askVideo' }) + `<p class="t-bs v" style="margin:4px 0 0;text-align:center">On the next screen, choose <b>${allowLabel}</b>.</p>`;
    } else if (st === 'limited') {
      title = 'TakeTray can see only some videos';
      body = "You allowed access to selected videos, so TakeTray can't find new clips by itself. You can still add videos yourself. We call this Manual mode.";
      extra = `<div class="callout warn">${icon('info', 'fill')}<div><b>Want new clips found for you?</b>Choose <b>Allow all</b> in the next step or in Android settings.</div></div>`;
      foot = h.btn({ label: 'Allow all videos', kind: 'filled', size: 'lg block', a: 'askVideo' }) + h.btn({ label: 'Continue in Manual mode', kind: 'text', size: 'block', a: 'obManual' });
    } else if (st === 'denied') {
      title = "TakeTray can't see your videos";
      body = "Without video access, new clips aren't found automatically. You can still pick videos yourself in Manual mode.";
      extra = `<div class="callout">${icon('settings')}<div><b>To allow access later</b>Settings › Apps › TakeTray › Permissions › Photos and videos › ${allowLabel}.</div></div>`;
      foot = h.btn({ label: 'Open settings', ic: 'open_in_new', kind: 'filled', size: 'lg block', a: 'openSettingsApp' }) + h.btn({ label: 'Continue in Manual mode', kind: 'text', size: 'block', a: 'obManual' });
    } else {
      art = `<svg class="ill" viewBox="0 0 168 140" aria-hidden="true"><circle cx="84" cy="70" r="44" style="fill:var(--x-success-color)"/><path d="M64 70l14 14 26-28" fill="none" stroke-width="9" stroke-linecap="round" stroke-linejoin="round" style="stroke:var(--x-success-on-color)"/></svg>`;
      title = 'All set';
      body = 'TakeTray can now find the new clips you shoot while Shooting mode is on.';
      foot = h.btn({ label: 'Continue', kind: 'filled', size: 'lg block', a: 'obNext', d: { to: 'ob-notif' } });
    }
    return {
      html: `<div class="scr"><div class="ob"><div class="art soft" style="display:grid;place-items:center;height:260px"><div style="width:220px;height:184px">${art.replace('class="ill"', 'class="ill" style="width:100%;height:100%"')}</div></div>
      <div class="body">${obDots(1)}<h1>${title}</h1><p>${body}</p>${extra}</div><div class="foot">${foot}</div></div></div>`,
    };
  };

  routes['ob-notif'] = (s) => {
    const cl = s.toTag.slice(0, 4).map((id) => s.clips[id]);
    const notif = `<div class="notif" style="width:268px;box-shadow:var(--elev-2)" aria-hidden="true"><div class="nh"><span class="appic">${icon('sell', 'fill')}</span>TakeTray · now</div><div class="nb"><div class="grow"><b>5 new clips to tag</b><span>Tap to tag them into your reels.</span></div></div><div class="thumbs">${cl.map((c) => `<i style="background-image:url(&quot;${RH.thumb(c.theme, c.seed, 'v')}&quot;)"></i>`).join('')}<i class="more">+1</i></div></div>`;
    return {
      html: `<div class="scr"><div class="ob"><div class="art soft" style="display:grid;place-items:center;height:260px">${notif}</div>
      <div class="body">${obDots(2)}<h1>Know when clips are waiting</h1><p>One quiet notification when new clips are waiting, and a reminder at 9 pm if you haven't tagged them. No sound.</p></div>
      <div class="foot">${h.btn({ label: 'Allow notifications', kind: 'filled', size: 'lg block', a: 'askNotif' })}${h.btn({ label: 'Not now', kind: 'text', size: 'block', a: 'obNext', d: { to: 'ob-reels' } })}</div></div></div>`,
    };
  };

  routes['ob-reels'] = (s, u) => {
    const names = u.p.names || [];
    const ideas = ['Day 1 Vlog', 'Food', 'Cinematic', 'Behind the scenes', 'Get ready with me'].filter((x) => !names.includes(x));
    const pre = s.reels.filter((r) => r.pre);
    const preRows = pre.map((r) => `<div class="reel-row">${icon('link', 'lead')}<span class="grow" style="min-width:0"><span class="t-bl clamp1" style="display:block">${esc(r.name)}</span><span class="t-bs v">${RH.fmt.n((r.refs || []).length, 'reference')} saved from Instagram</span></span><span class="ms pc" style="padding:12px" aria-label="Already created">check</span></div>`).join('');
    const rows = preRows + names.map((n, i) => `<div class="reel-row">${icon('radio_button_checked', 'lead fill')}<span class="grow t-bl clamp1">${esc(n)}</span>${h.ib('close', { a: 'obRemoveName', label: `Remove ${n}`, d: { i } })}</div>`).join('');
    const draft = u.p.draft || '';
    return {
      html: `<div class="scr"><div class="ob"><div class="body" style="padding-top:28px">${obDots(3)}<h1>What reels are you planning?</h1><p>Add the reels for your next trip or shoot. You can change them later.</p>
      <div class="tf ${u.kbd ? 'focus' : ''}" style="--bgfield:var(--md-surface)"><label for="obname">Reel name</label><div class="box"><input id="obname" value="${esc(draft)}" placeholder="London Food" data-in="obDraft" autocomplete="off" maxlength="40">${h.ib('add', { a: 'obAddName', label: 'Add reel', cls: 'tonal' })}</div><div class="help"><span>Press Enter to add the next one</span></div></div>
      ${rows ? `<div class="reel-rows">${rows}</div>` : ''}
      <p class="t-bs v ob-tip">${icon('ios_share', 's16')}Tip: share any Instagram reel to TakeTray to save it as a reference.</p>
      ${ideas.length && names.length < 5 ? `<div class="t-lm v" style="margin-top:4px">Ideas</div><div class="sugg">${ideas.slice(0, 4).map((x) => `<button class="fchip tap" data-a="obIdea" data-name="${esc(x)}">${icon('add')}${esc(x)}</button>`).join('')}</div>` : ''}
      </div><div class="foot">${h.btn({ label: names.length ? `Create ${fmt.n(names.length, 'reel')}` : pre.length ? 'Continue' : 'Create reels', kind: 'filled', size: 'lg block', a: 'obCreate', dis: !names.length && !pre.length })}${h.btn({ label: 'Skip for now', kind: 'text', size: 'block', a: 'obFinish' })}</div></div>${u.kbd ? h.keyboard() : ''}</div>`,
    };
  };

  routes.home = (s, u) => {
    const counts = q.counts(s);
    const f = u.filter || 'all';
    const list = s.reels.slice().sort((a, b) => (a.created < b.created ? 1 : a.created > b.created ? -1 : 0)).filter((r) => f === 'all' || r.status === f);
    const chip = (id, label) => `<button class="fchip tap ${f === id ? 'on' : ''}" data-a="filter" data-f="${id}" aria-pressed="${f === id}">${f === id ? icon('check') : ''}${label} <span class="cnt">${counts[id]}</span></button>`;
    let content;
    if (!s.reels.length) {
      content = h.empty({ ill: 'noreels', title: 'Plan your first reel', body: "A reel is a video you're planning, like London Food or Day 1 Vlog. Clips you tag go into it.", acts: h.btn({ label: 'New reel', ic: 'add', a: 'newReel' }) });
    } else if (!list.length) {
      const st = h.STATUS[f];
      content = h.empty({ ill: 'emptyreel', title: `No reels marked ${st.label}`, body: f === 'pub' ? 'When you post a reel, mark it as Published from its page.' : f === 'ready' ? 'When a reel has all its clips, mark it as Ready to edit.' : 'New reels start as Recording.', acts: h.btn({ label: 'Show all reels', kind: 'tonal', a: 'filter', d: { f: 'all' } }) });
    } else {
      content = `<div class="reelgrid">${list.map((r) => h.reelCard(r, s)).join('')}</div>`;
    }
    const banner = !s.shooting.on && s.toTag.length ? `<button class="banner attn tap" data-a="tab" data-tab="totag" style="width:calc(100% - 32px)">${icon('sell', 'fill')}<div class="grow"><b>${fmt.n(s.toTag.length, 'clip')} to tag</b><span>${fmt.mins(q.total(s.toTag.map((id) => s.clips[id])))} of video waiting</span></div>${icon('chevron_right')}</button>` : '';
    const tip = u.hint === 'shoot' ? `<div class="tooltip right" style="right:16px;top:${s.access === 'full' ? 182 : 246}px" role="note"><b>Going out to shoot?</b>Turn on Shooting mode first. New videos will wait in To tag.<br>${h.btn({ label: 'Got it', kind: 'text', a: 'dismissHint' })}</div>` : '';
    return {
      nav: 'home',
      html: `<div class="scr">${h.appbar({ title: 'Reels', big: true })}<div class="scroll" data-scroll="home">${accessBanner(s)}${shootingCard(s, u)}${banner}
        ${s.reels.length ? `<div class="chips" role="group" aria-label="Filter by status">${chip('all', 'All')}${chip('rec', 'Recording')}${chip('ready', 'Ready to edit')}${chip('pub', 'Published')}</div>` : ''}
        ${content}<div class="end-space"></div></div>${s.reels.length ? fab('New reel', 'add', 'newReel', '', { nav: true, snack: !!u.snack }) : ''}${tip}${h.navbar('home', s.toTag.length)}</div>`,
    };
  };

  routes.reel = (s, u) => {
    const reel = q.reel(s, u.p.id);
    if (!reel) return routes.home(s, u);
    const clips = q.clipsOf(s, reel.id);
    const live = clips.filter((c) => !c.missing);
    const missing = clips.length - live.length;
    const sel = u.sel && u.sel.ctx === 'reel';
    const bar = sel
      ? h.appbar({ title: `${selIds(u).length} selected`, nav: 'close', navA: 'clearSel', sel: true, actions: h.ib('library_add', { a: 'selAddTo', label: 'Add to another reel' }) + h.ib('drive_file_move', { a: 'selMove', label: 'Move to another reel' }) + h.ib('playlist_remove', { a: 'selRemove', label: 'Remove from this reel' }) + h.ib('more_vert', { a: 'menu', d: { m: 'reelSel' }, label: 'More' }) })
      : h.appbar({ title: '', nav: 'back', actions: h.ib('library_add', { a: 'addVideos', d: { kind: 'reel', id: reel.id }, label: 'Add videos' }) + h.ib('more_vert', { a: 'menu', d: { m: 'reelMore', id: reel.id }, label: 'More options' }) });
    const vnMB = q.vnMB(s, reel);
    const vn = reel.vn ? `<div class="banner vn" role="region" aria-label="Editing in VN">${icon('folder_copy', 'fill')}<div class="grow"><b>Editing in VN · ${fmt.size(vnMB)}</b><span>${fmt.n(reel.vn.copied.length, 'copy', 'copies')} in Movies/TakeTray/${esc(reel.vn.folder)}</span></div><div class="acts">${h.btn({ label: 'Done editing', kind: 'filled', size: 'sm', a: 'doneEditing', d: { id: reel.id } })}${h.btn({ label: 'Add more clips', kind: 'text', size: 'sm', a: 'vnAddMore', d: { id: reel.id } })}</div></div>` : '';
    const descOpen = u.p.descOpen;
    const desc = reel.desc ? `<div class="desc"><div class="dh">${icon('lightbulb')}Shot ideas</div><div class="${descOpen ? '' : 'clamp2'}">${esc(reel.desc)}</div>${reel.desc.length > 90 ? `<button class="btn text" data-a="toggleDesc" aria-expanded="${!!descOpen}">${descOpen ? 'Show less' : 'Show more'}</button>` : ''}</div>` : '';
    const firstDay = clips.length ? RH.dateOf(clips[0].at) : null;
    const dayN = (d) => Math.round((RH.epochMin(d) - RH.epochMin(firstDay)) / 1440) + 1;
    let grid;
    if (u.p.loading) {
      grid = `<div class="day-h"><span class="skel-line" style="width:120px;display:block"></span></div><div class="grid3">${h.skelTiles(9)}</div>`;
    } else if (!clips.length) {
      grid = h.empty({ ill: 'emptyreel', title: 'No clips yet', body: 'Tag clips from To tag, or add videos from your phone. You can also share a reel from Instagram to save it here as a reference.', acts: h.btn({ label: 'Go to To tag', ic: 'sell', kind: 'tonal', a: 'tab', d: { tab: 'totag' } }) + h.btn({ label: 'Add videos', ic: 'library_add', kind: 'text', a: 'addVideos', d: { kind: 'reel', id: reel.id } }) });
    } else {
      grid = q.days(clips).map((d) => `<div class="day-h">Day ${dayN(d.day)} · ${fmt.day(d.day)}<span>${fmt.n(d.clips.length, 'clip')}</span></div><div class="grid3">${d.clips.map((c) => h.tile(c, s, { a: sel ? 'toggleSel' : 'openClip', lp: 'startSel', d: { ctx: 'reel' }, selecting: sel, sel: isSel(u, c.id) })).join('')}</div>`).join('');
    }
    return {
      html: `<div class="scr">${bar}<div class="scroll" data-scroll="reel-${reel.id}"><div class="rd-head"><h1>${esc(reel.name)}</h1><div class="meta">${h.statusPill(reel.status, { big: true, caret: true, a: 'menu', d: { m: 'status', id: reel.id } })}<span>${clips.length ? `${fmt.n(clips.length, 'clip')} · ${fmt.dur(q.total(live))}` : 'No clips yet'}</span>${missing ? `<span class="er" style="display:inline-flex;gap:4px;align-items:center;font-weight:600">${icon('error', 'fill s18')}${missing} missing</span>` : ''}</div></div>
        ${desc}${h.refsSection ? h.refsSection(reel, s, u) : ''}${vn}${grid}<div class="end-space"></div></div>${clips.length && !sel ? fab('Edit video', 'movie_edit', 'editVideo', 'primary', { snack: !!u.snack }) : ''}</div>`,
    };
  };

  routes.totag = (s, u) => {
    const sel = u.sel && u.sel.ctx === 'totag';
    const n = s.toTag.length;
    const scenes = q.scenes(s, s.toTag);
    const bar = sel
      ? h.appbar({ title: `${selIds(u).length} selected`, nav: 'close', navA: 'clearSel', sel: true, actions: `${h.btn({ label: 'Skip', kind: 'text', a: 'selSkip', cls: 'on-sel' })}${h.btn({ label: 'Tag', ic: 'sell', kind: 'filled', size: 'sm', a: 'selTag' })}<span style="width:8px"></span>` })
      : h.appbar({ title: 'To tag', big: true, actions: h.ib('library_add', { a: 'addVideos', d: { kind: 'totag' }, label: 'Add videos' }) + h.ib('more_vert', { a: 'menu', d: { m: 'totagMore' }, label: 'More options' }) });
    const strip = s.shooting.on
      ? `<div class="stat-strip"><span class="recdot live"></span><span class="grow">Shooting since ${fmt.time(s.shooting.since)}</span>${h.btn({ label: 'Open camera', ic: 'videocam', kind: 'text', a: 'openCamera' })}</div>`
      : n ? `<div class="stat-strip v"><span class="ms s18" aria-hidden="true">videocam_off</span><span class="grow">Shooting mode off</span>${h.btn({ label: 'Turn on', kind: 'text', a: 'toggleShoot' })}</div>` : '';
    let body;
    if (u.p.loading) {
      body = `<div class="sumrow"><span class="skel-line" style="width:140px"></span></div><div class="sec-h"><div class="grow"><span class="skel-line" style="width:110px;display:block"></span></div></div><div class="grid3">${h.skelTiles(6)}</div><div class="sec-h"><div class="grow"><span class="skel-line" style="width:90px;display:block"></span></div></div><div class="grid3">${h.skelTiles(6)}</div>`;
    } else if (!n) {
      body = s.shooting.on
        ? h.empty({ ill: 'caught', title: 'All caught up', body: 'New clips you shoot will show up here.', acts: h.btn({ label: 'Open camera', ic: 'videocam', kind: 'tonal', a: 'openCamera' }) })
        : h.empty({ ill: 'shootoff', title: 'Nothing to tag', body: 'Turn on Shooting mode before you start filming. New videos will show up here.', acts: h.btn({ label: 'Turn on Shooting mode', ic: 'videocam', a: 'toggleShoot' }) + h.btn({ label: 'Add videos', ic: 'library_add', kind: 'text', a: 'addVideos', d: { kind: 'totag' } }) });
      if (s.skipped.length) body += `<div style="display:flex;justify-content:center">${h.btn({ label: `Skipped (${s.skipped.length})`, kind: 'text', a: 'go', d: { r: 'skipped' } })}</div>`;
    } else {
      let lastDay = null;
      const multiDay = new Set(scenes.map((sc) => sc.day)).size > 1;
      body = `<div class="sumrow"><span class="grow">${fmt.n(n, 'clip')} · ${fmt.n(scenes.length, 'scene')} · ${fmt.mins(q.total(s.toTag.map((id) => s.clips[id])))}</span>${s.skipped.length ? h.btn({ label: `Skipped (${s.skipped.length})`, kind: 'text', a: 'go', d: { r: 'skipped' } }) : ''}</div>`;
      body += scenes.map((sc) => {
        const dayHead = multiDay && sc.day !== lastDay ? `<div class="day-h">${fmt.dayRel(sc.day)}</div>` : '';
        lastDay = sc.day;
        const allSel = sel && sc.ids.every((id) => isSel(u, id));
        return dayHead + h.sceneHeader(sc, s, { selecting: sel, allSel }) + `<div class="grid3">${sc.ids.map((id) => h.tile(s.clips[id], s, { a: sel ? 'toggleSel' : 'playFrom', lp: 'startSel', d: { ctx: 'totag' }, selecting: sel, sel: isSel(u, id) })).join('')}</div>`;
      }).join('');
    }
    return {
      nav: 'totag',
      html: `<div class="scr">${bar}<div class="scroll" data-scroll="totag">${accessBanner(s)}${strip}${body}<div class="end-space"></div></div>${n && !sel && !u.p.loading ? fab('Start tagging', 'play_arrow', 'startTagging', 'primary', { nav: true, snack: !!u.snack }) : ''}${h.navbar('totag', n)}</div>`,
    };
  };

  routes.player = (s, u) => {
    const P = u.player;
    if (!P || P.done) return routes['player-done'](s, u);
    const id = P.session[P.i];
    const clip = s.clips[id];
    const scenes = q.scenes(s, P.session);
    const scIdx = scenes.findIndex((sc) => sc.ids.includes(id));
    const sc = scenes[scIdx];
    const total = P.session.length;
    const segs = total <= 40 ? P.session.map((cid, k) => `<i class="${k === P.i ? 'cur' : !s.toTag.includes(cid) ? 'done' : ''}"></i>`).join('') : `<i class="done" style="flex:${P.i}"></i><i class="cur" style="flex:1"></i><i style="flex:${total - P.i - 1}"></i>`;
    const recReels = q.orderedReels(s).filter((r) => r.status === 'rec');
    const others = q.orderedReels(s).filter((r) => r.status !== 'rec');
    const multi = P.multi;
    const chip = (r) => h.reelChip(r, s, { state: P.confirm === r.id ? 'done' : multi && P.picked.includes(r.id) ? 'pick' : '', multi, a: multi ? 'pickChip' : 'chip' });
    const otherOpen = u.otherOpen || !recReels.length;
    let chips;
    if (!s.reels.length) {
      chips = `<div style="grid-column:1/-1;text-align:center;padding:8px 8px 4px" class="t-bm v">You don't have any reels yet. Create one and this clip goes into it.</div><button class="rchip new tap" data-a="newReelPlayer" style="grid-column:1/-1;justify-content:center"><span class="cv">${icon('add')}</span><span class="t" style="flex:none"><b>New reel</b></span></button>`;
    } else {
      chips = recReels.map(chip).join('')
        + `<button class="rchip new tap" data-a="newReelPlayer" aria-label="New reel"><span class="cv">${icon('add')}</span><span class="t"><b>New reel</b><span>Add this clip to it</span></span></button>`
        + (others.length ? `<button class="lbl tap" data-a="toggleOthers" aria-expanded="${otherOpen}" style="display:flex;align-items:center;gap:4px;min-height:36px;border-radius:8px;text-align:left">${otherOpen ? 'Other reels' : `Other reels (${others.length})`}${icon(otherOpen ? 'expand_less' : 'expand_more', 's18')}</button>` + (otherOpen ? others.map(chip).join('') : '') : '');
    }
    const head = multi
      ? `<div class="ph-h"><b>Pick reels for this clip</b>${h.btn({ label: 'Cancel', kind: 'text', a: 'multiOff' })}</div>`
      : `<div class="ph-h"><b>Add to reel</b>${s.reels.length > 1 ? `<button class="btn text sm tap" data-a="multiOn" aria-pressed="false">${icon('library_add_check')}<span>Pick several</span></button>` : ''}</div>`;
    const foot = multi ? `<div class="multi-foot">${h.btn({ label: P.picked.length ? `Add to ${fmt.n(P.picked.length, 'reel')} & next` : 'Pick one or more reels', kind: 'filled', a: 'multiConfirm', dis: !P.picked.length })}</div>` : '';
    const prev = s.lastTags.filter((rid) => q.reel(s, rid));
    const sameNames = prev.map((rid) => q.reel(s, rid).name).join(', ');
    const hasPrev = P.session.slice(0, P.i).some((cid) => s.toTag.includes(cid));
    const hasNext = P.session.slice(P.i + 1).some((cid) => s.toTag.includes(cid));
    const vidCls = `vid ${clip.orient === 'h' ? 'h' : ''} ${P.paused ? 'paused' : ''}`;
    const long = clip.dur > 120;
    const loading = P.loading;
    const snack = u.snack ? h.snack({ ...u.snack, bottom: 8 }) : '';
    return {
      video: true,
      html: `<div class="scr rh-dark" style="background:#000"><div class="player ${P.paused ? 'paused-all' : ''}" style="padding-top:32px">
        <div class="pbar" style="top:34px" aria-hidden="true">${segs}</div>
        <div class="ptop">${h.ib('close', { a: 'closePlayer', label: 'Close tagging' })}<div class="mid" aria-live="polite"><b>${P.i + 1} of ${total}</b><span>Scene ${scIdx + 1} of ${scenes.length} · ${fmt.range(sc.start, sc.end)}</span></div>${h.ib(P.muted ? 'volume_off' : 'volume_up', { a: 'toggleMute', label: P.muted ? 'Unmute' : 'Mute', pressed: !P.muted })}</div>
        <div class="stage ${u.anim === 'adv' ? 'adv' : u.anim === 'back' ? 'back' : ''}"><div class="blur" style="background-image:url(&quot;${RH.thumb(clip.theme, clip.seed, clip.orient)}&quot;)"></div>
          <button class="arrow l tap" data-a="prevClip" aria-label="Previous clip"${hasPrev ? '' : ' disabled'}>${icon('chevron_left')}</button>
          <button class="${vidCls}" data-a="togglePlay" aria-label="${P.paused ? 'Play' : 'Pause'} clip, ${fmt.time(clip.at)}, ${fmt.dur(clip.dur)}" style="--clipdur:${clip.dur}s"><img class="${loading || P.paused ? '' : 'play'}" src="${RH.thumb(clip.theme, clip.seed, clip.orient)}" alt="">${P.paused ? `<span class="ctr">${icon('play_arrow', 'fill')}</span>` : ''}${loading ? '<span class="ld"><span class="spin"></span></span>' : ''}</button>
          <button class="arrow r tap" data-a="nextClip" aria-label="Next clip"${hasNext ? '' : ' disabled'}>${icon('chevron_right')}</button>${snack}</div>
        <div class="scrub ${long ? 'big' : ''}" style="--clipdur:${clip.dur}s;position:relative"><span>${loading ? '0:00' : long ? '1:12' : '0:00'}</span><span class="trk">${long ? '<i style="width:26%"></i><b style="left:26%"></b><span class="hint">Drag to skim · 4:32 clip</span>' : `<i class="${loading || P.paused ? '' : 'play'}"></i>`}</span><span>${fmt.dur(clip.dur)}</span></div>
        <div class="qrow">${h.btn({ label: 'Skip', ic: 'redo', kind: 'ghost', a: 'skipClip', aria: 'Skip this clip' })}<button class="btn same tap ${prev.length ? '' : 'dis'}" data-a="sameAsPrev"${prev.length ? ` aria-label="Same as previous: ${esc(sameNames)}"` : ' aria-disabled="true"'}>${icon('repeat')}<span class="two"><span>Same as previous</span>${prev.length ? `<small>${esc(sameNames)}</small>` : ''}</span></button></div>
        <div class="tagpanel" role="group" aria-label="Reels">${head}<div class="chipgrid">${chips}</div>${foot}</div>
      </div></div>`,
    };
  };

  routes['player-done'] = (s, u) => {
    const P = u.player || { tagged: {}, skippedN: 0, session: [] };
    const rows = Object.entries(P.tagged || {}).map(([rid, n]) => { const r = q.reel(s, rid); return r ? `<div><span>${esc(r.name)}</span><b>+${n}</b></div>` : ''; }).join('');
    const sorted = P.session.length - s.toTag.filter((id) => P.session.includes(id)).length;
    return {
      video: true,
      html: `<div class="scr rh-dark"><div class="done-scr" style="padding-top:56px"><div class="big">${icon('check', 's48')}</div><h2>All done!</h2><p>${fmt.n(sorted, 'clip')} sorted. Nice work.</p>
      <div class="sum">${rows}${P.skippedN ? `<div><span>Skipped</span><b>${P.skippedN}</b></div>` : ''}</div>
      ${h.btn({ label: 'See your reels', kind: 'filled', size: 'lg', a: 'tab', d: { tab: 'home' } })}${h.btn({ label: 'Back to To tag', kind: 'text', a: 'tab', d: { tab: 'totag' } })}</div></div>`,
    };
  };

  routes.skipped = (s, u) => {
    const sel = u.sel && u.sel.ctx === 'skipped';
    const ids = s.skipped.slice().sort((a, b) => (s.clips[a].at < s.clips[b].at ? 1 : -1));
    const bar = sel
      ? h.appbar({ title: `${selIds(u).length} selected`, nav: 'close', navA: 'clearSel', sel: true, actions: h.btn({ label: 'Restore', ic: 'undo', kind: 'filled', size: 'sm', a: 'restoreSel' }) + '<span style="width:8px"></span>' })
      : h.appbar({ title: 'Skipped', nav: 'back', actions: ids.length ? h.btn({ label: 'Select', kind: 'text', a: 'startSelBtn', d: { ctx: 'skipped' } }) : '' });
    const days = q.days(ids.map((id) => s.clips[id]));
    const body = ids.length
      ? `<div class="infobar">${icon('info')}<span>Skipped clips are still in your gallery. Restore any you want to tag.</span></div>` + days.map((d) => `<div class="day-h">${fmt.dayRel(d.day)}<span>${fmt.n(d.clips.length, 'clip')}</span></div><div class="grid3">${d.clips.map((c) => h.tile(c, s, { a: sel ? 'toggleSel' : 'restoreOne', lp: 'startSel', d: { ctx: 'skipped' }, selecting: sel, sel: isSel(u, c.id) })).join('')}</div>`).join('')
      : h.empty({ ill: 'skipped', title: 'No skipped clips', body: 'Clips you skip in To tag show up here, in case you change your mind.' });
    return { html: `<div class="scr">${bar}<div class="scroll" data-scroll="skipped">${body}<div class="end-space"></div></div></div>` };
  };

  routes.viewer = (s, u) => {
    const list = u.p.list || [];
    const i = Math.max(0, list.indexOf(u.p.id));
    const clip = s.clips[u.p.id];
    const reel = q.reel(s, u.p.reel);
    const inReels = clip.reels.map((rid) => q.reel(s, rid)).filter(Boolean);
    return {
      video: true,
      html: `<div class="scr rh-dark"><div class="viewer"><div class="vstage ${clip.orient === 'h' ? 'h' : ''}">${u.p.err ? '' : `<img src="${RH.thumb(clip.theme, clip.seed, clip.orient)}" alt="">`}</div>
        ${u.p.err ? `<div class="err">${icon('error', 's48')}<b class="t-tm">This video can't be played</b><p class="t-bm">It may be damaged, or in a format your phone doesn't support. The file is still in your gallery.</p>${h.btn({ label: 'Remove from reel', kind: 'tonal', a: 'viewerRemove' })}</div>` : ''}
        <div class="vtop">${h.ib('arrow_back', { a: 'back', label: 'Back' })}<div class="mid"><b>${i + 1} of ${list.length}${reel ? ' · ' + esc(reel.name) : ''}</b><span>${fmt.day(clip.at)} · ${fmt.time(clip.at)} ${clip.tz === 'BST' ? 'London time' : ''}</span></div>${h.ib('volume_up', { a: 'noop', label: 'Mute' })}</div>
        <div class="stage" style="position:absolute;inset:120px 0 240px;pointer-events:none"><button class="arrow l tap" style="pointer-events:auto" data-a="viewerPrev" aria-label="Previous clip"${i === 0 ? ' disabled' : ''}>${icon('chevron_left')}</button><button class="arrow r tap" style="pointer-events:auto" data-a="viewerNext" aria-label="Next clip"${i >= list.length - 1 ? ' disabled' : ''}>${icon('chevron_right')}</button></div>
        <div class="vbot"><div class="scrub" style="--clipdur:${clip.dur}s"><span>0:03</span><span class="trk"><i style="width:22%"></i><b style="left:22%"></b></span><span>${fmt.dur(clip.dur)}</span></div>
        <div class="inreels"><span>In</span>${inReels.map((r) => `<span class="tagc">${icon('video_library', 's16')}${esc(r.name)}</span>`).join('')}</div>
        <div class="vacts"><button class="tap" data-a="viewerAdd">${icon('library_add')}Add to reel</button><button class="tap" data-a="viewerMove">${icon('drive_file_move')}Move</button><button class="tap" data-a="viewerRemove">${icon('playlist_remove')}Remove</button><button class="tap" data-a="share" data-n="1">${icon('share')}Share</button></div></div>
      </div></div>`,
    };
  };

  routes['add-folders'] = (s, u) => {
    const t = u.p.target || { kind: 'totag' };
    const reel = t.kind === 'reel' ? q.reel(s, t.id) : null;
    const rows = s.browse.map((f) => {
      const cl = f.count ? q.folderClips(s, f.id).slice(0, 4) : [];
      const mosaic = cl.length ? `<span style="display:grid;grid-template-columns:1fr 1fr;gap:2px;width:100%;height:100%">${cl.map((c) => `<img src="${RH.thumb(c.theme, c.seed, 'v')}" alt="" style="width:100%;height:100%;object-fit:cover">`).join('')}</span>` : icon('folder');
      return `<button class="li tall tap" data-a="openFolder" data-f="${f.id}"><span class="thumb" style="width:56px;height:56px">${mosaic}</span><span class="txt"><b>${esc(f.name)}</b><span>${fmt.n(f.count, 'video')}</span></span>${icon('chevron_right')}</button>`;
    }).join('');
    const tip = s.folderTipSeen ? '' : `<div class="callout" style="margin:4px 16px 8px">${icon('tips_and_updates', 'fill')}<div class="grow"><b>Keep friends' clips sharp</b>Ask friends to send videos as HD or by Quick Share to keep full quality.<div>${h.btn({ label: 'Got it', kind: 'text', a: 'tipSeen', cls: '' })}</div></div></div>`;
    return { html: `<div class="scr">${h.appbar({ title: 'Add videos', sub: reel ? `to ${reel.name}` : 'to To tag', nav: 'back' })}<div class="scroll" data-scroll="folders">${tip}${rows}<div class="end-space"></div></div></div>` };
  };

  routes['add-grid'] = (s, u) => {
    const t = u.p.target || { kind: 'totag' };
    const f = s.browse.find((b) => b.id === u.p.folder) || s.browse[0];
    const clips = q.folderClips(s, f.id);
    const picked = u.sel ? u.sel.ids : [];
    const markFor = (c) => {
      if (t.kind === 'reel' && c.reels && c.reels.includes(t.id)) return { ic: 'check_circle', label: 'In this reel' };
      if (s.toTag.includes(c.id)) return { ic: 'sell', label: 'In To tag' };
      if (t.kind === 'totag' && c.reels && c.reels.length) return { ic: 'video_library', label: 'In a reel' };
      return null;
    };
    const body = clips.length
      ? q.days(clips.slice().reverse()).reverse().map((d) => `<div class="day-h">${fmt.dayRel(d.day)}</div><div class="grid3">${d.clips.slice().reverse().map((c) => { const m = markFor(c); return h.tile(c, s, { a: m ? 'alreadyAdded' : 'toggleSel', d: { ctx: 'add' }, selecting: !m, sel: picked.includes(c.id), mark: m, hideMulti: true }); }).join('')}</div>`).join('')
      : h.empty({ ill: 'folder', title: 'No videos in this folder', body: 'Videos saved here will show up when you come back.' });
    const sum = picked.length ? fmt.dur(q.total(picked.map((id) => clips.find((c) => c.id === id)).filter(Boolean))) : '';
    return {
      html: `<div class="scr">${h.appbar({ title: f.name, sub: 'Tap videos to pick them', nav: 'back' })}<div class="scroll" data-scroll="grid-${f.id}">${body}<div class="end-space" style="height:24px"></div></div>
      <div class="bottombar"><div class="grow"><b>${picked.length ? fmt.n(picked.length, 'video') + ' picked' : 'No videos picked'}</b><span>${picked.length ? sum + ' · added in shooting order' : 'Videos already added are marked'}</span></div>${h.btn({ label: picked.length ? `Add ${picked.length}` : 'Add', kind: 'filled', a: 'addPicked', dis: !picked.length })}</div></div>`,
    };
  };

  routes['edit-select'] = (s, u) => {
    const reel = q.reel(s, u.p.id);
    const clips = q.liveClipsOf(s, reel.id);
    const vnAdd = u.p.vnAdd;
    const copied = reel.vn ? reel.vn.copied : [];
    const picked = u.sel ? u.sel.ids : [];
    const isCopied = (c) => vnAdd && copied.includes(c.id);
    const days = q.days(clips);
    const chosen = clips.filter((c) => picked.includes(c.id));
    const newOnes = vnAdd ? chosen.filter((c) => !copied.includes(c.id)) : chosen;
    const allOn = clips.filter((c) => !isCopied(c)).every((c) => picked.includes(c.id));
    const grid = days.map((d) => `<div class="day-h">${fmt.day(d.day)}<span>${fmt.n(d.clips.length, 'clip')}</span></div><div class="grid3">${d.clips.map((c) => isCopied(c) ? h.tile(c, s, { a: 'copiedInfo', selecting: true, sel: true, vnMark: true, hideMulti: true }) : h.tile(c, s, { a: 'toggleSel', d: { ctx: 'edit' }, selecting: true, sel: picked.includes(c.id), hideMulti: true })).join('')}</div>`).join('');
    const sumTitle = vnAdd ? (newOnes.length ? `${fmt.n(newOnes.length, 'new clip')} to copy` : 'Pick clips to add') : picked.length ? `${fmt.n(picked.length, 'clip')} · ${fmt.dur(q.total(chosen))}` : 'No clips picked';
    const sumSub = newOnes.length ? `${fmt.size(q.sizeOf(newOnes))}${vnAdd ? ' · copies are added, never renamed' : ' · in shooting order'}` : vnAdd ? `${copied.length} already in the VN folder` : 'Tap the clips you want to edit';
    return {
      html: `<div class="scr">${h.appbar({ title: vnAdd ? 'Add clips to VN folder' : 'Pick clips to edit', sub: reel.name, nav: 'close', navA: 'back', actions: h.btn({ label: allOn ? 'Clear' : 'Select all', kind: 'text', a: 'editSelectAll' }) })}
      <div class="scroll" data-scroll="edit-${reel.id}"><div class="infobar">${icon('sort')}<span>Clips go to your editor in the order you shot them.</span></div>${grid}<div class="end-space" style="height:24px"></div></div>
      <div class="bottombar"><div class="grow"><b>${sumTitle}</b><span>${sumSub}</span></div>${h.btn({ label: vnAdd ? 'Copy' : 'Continue', kind: 'filled', a: vnAdd ? 'vnAddConfirm' : 'editContinue', dis: !newOnes.length })}</div></div>`,
    };
  };

  routes['vn-space'] = (s, u) => {
    const reel = q.reel(s, u.p.id);
    const ids = u.p.ids || [];
    const clips = ids.map((id) => s.clips[id]);
    const need = u.p.needMB || q.sizeOf(clips);
    const free = u.p.freeMB || s.storageFreeMB;
    const ok = need < free;
    // OK: the bar is your free space, with the copies' share in violet.
    // Not OK: the bar is what the copies need; the part you have is solid, the shortfall hatched red.
    const bar = ok
      ? `<div class="storage"><div class="bar" role="img" aria-label="Free space ${fmt.size(free)}, copies need ${fmt.size(need)}"><i class="need" style="width:${Math.max(4, (need / free) * 100)}%"></i></div><div class="legend"><span><i style="background:var(--md-primary)"></i>Copies: ${fmt.size(need)}</span><span><i style="background:var(--md-surface-container-highest);outline:1px solid var(--md-outline-variant)"></i>Free after copying: ${fmt.size(free - need)}</span></div></div>`
      : `<div class="storage"><div class="bar" role="img" aria-label="Copies need ${fmt.size(need)}, you have ${fmt.size(free)}, short by ${fmt.size(need - free)}"><i class="used" style="width:${(free / need) * 100}%"></i><i class="over" style="width:${100 - (free / need) * 100}%"></i></div><div class="legend"><span><i style="background:var(--md-outline)"></i>You have ${fmt.size(free)}</span><span><i style="background:var(--md-error)"></i>Short by ${fmt.size(need - free)}</span></div></div>`;
    const body = ok
      ? `<h2 class="t-hs" style="margin:0">These ${clips.length} clips need ${fmt.size(need)}</h2><p class="t-bm v" style="margin:0">You have ${fmt.size(free)} free.</p>${bar}
         <div class="callout">${icon('folder_copy', 'fill')}<div><b>Why copies?</b>VN needs all the clips in one folder. TakeTray copies them to <b>Movies/TakeTray/${esc(reel.name)}</b>. Your original clips stay where they are.</div></div>
         <div class="callout">${icon('delete_sweep')}<div><b>Copies are temporary</b>After you export from VN, tap Done editing and TakeTray deletes them.</div></div>`
      : `<h2 class="t-hs" style="margin:0">Not enough space</h2><p class="t-bm v" style="margin:0">These ${clips.length} clips need ${fmt.size(need)}. You have ${fmt.size(free)} free.</p>${bar}
         <div class="callout warn">${icon('info', 'fill')}<div><b>What you can do</b>Select fewer clips, or free up space on your phone and try again.</div></div>`;
    return {
      html: `<div class="scr">${h.appbar({ title: 'Copy clips for VN', nav: 'close', navA: 'back' })}<div class="scroll" style="padding:8px 24px;display:flex;flex-direction:column;gap:14px">${body}</div>
      <div style="padding:12px 16px 16px;display:flex;flex-direction:column;gap:8px">${ok ? h.btn({ label: `Copy ${clips.length} clips`, ic: 'content_copy', kind: 'filled', size: 'lg block', a: 'vnCopy' }) : h.btn({ label: 'Select fewer clips', kind: 'filled', size: 'lg block', a: 'back' })}${h.btn({ label: ok ? 'Back' : 'Cancel', kind: 'text', size: 'block', a: ok ? 'back' : 'cancelVN' })}</div></div>`,
    };
  };

  routes['vn-copy'] = (s, u) => {
    const reel = q.reel(s, u.p.id);
    const ids = u.p.ids || [];
    const total = ids.length;
    const done = Math.min(total, u.p.done || 0);
    const mbAll = q.sizeOf(ids.map((id) => s.clips[id]));
    const mbDone = q.sizeOf(ids.slice(0, done).map((id) => s.clips[id]));
    let body, foot;
    if (u.p.fail === 'space') {
      body = `<span class="ms s48 er" aria-hidden="true">sd_card_alert</span><h2 class="t-hs" style="margin:0">Phone storage is full</h2><p class="t-bm v" style="margin:0">${done} of ${total} clips were copied before space ran out. Free up some space, then try again.</p><div class="prog" style="width:100%"><i style="width:${(done / total) * 100}%;background:var(--md-error)"></i></div>`;
      foot = h.btn({ label: 'Try again', kind: 'filled', size: 'lg block', a: 'vnRetry' }) + h.btn({ label: 'Delete copies and stop', kind: 'text', size: 'block', a: 'cancelVN' });
    } else if (u.p.fail === 'error') {
      body = `<span class="ms s48" style="color:var(--md-tertiary)" aria-hidden="true">warning</span><h2 class="t-hs" style="margin:0">1 clip couldn't be copied</h2><p class="t-bm v" style="margin:0">The clip from ${fmt.time(s.clips[ids[3]].at)} may have been deleted or moved. The other ${total - 1} clips were copied.</p>`;
      foot = h.btn({ label: `Continue with ${total - 1} clips`, kind: 'filled', size: 'lg block', a: 'vnFinish' }) + h.btn({ label: 'Cancel', kind: 'text', size: 'block', a: 'cancelVN' });
    } else {
      body = `<span class="ms s48 pc" aria-hidden="true">folder_copy</span><h2 class="t-hs" style="margin:0">Copying clips for VN</h2><p class="t-tm" style="margin:0" aria-live="polite">${done} of ${total} clips</p><div class="prog" style="width:100%" role="progressbar" aria-valuemin="0" aria-valuemax="${total}" aria-valuenow="${done}"><i style="width:${(done / total) * 100}%"></i></div><p class="t-bs v" style="margin:0">${fmt.size(mbDone)} of ${fmt.size(mbAll)} · into Movies/TakeTray/${esc(reel.name)}</p><p class="t-bm v" style="margin:12px 0 0">This takes up to a minute. You can leave the app; copying continues.</p>`;
      foot = h.btn({ label: 'Cancel', kind: 'outlined', size: 'lg block', a: 'stopCopy' });
    }
    return { html: `<div class="scr"><div style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;gap:12px;padding:24px 32px">${body}</div><div style="padding:12px 16px 16px;display:flex;flex-direction:column;gap:8px">${foot}</div></div>` };
  };

  routes['vn-ready'] = (s, u) => {
    const reel = q.reel(s, u.p.id);
    const folder = reel.vn ? reel.vn.folder : reel.name;
    const cl = q.liveClipsOf(s, reel.id).slice(0, 6);
    const tg = cl.map((c, i) => `<i style="background-image:url(&quot;${RH.thumb(c.theme, c.seed, 'v')}&quot;)"><b>${i + 1}</b></i>`).join('');
    return {
      html: `<div class="scr">${h.appbar({ title: '', nav: 'close', navA: 'vnDone' })}<div class="scroll" style="padding:0 24px;display:flex;flex-direction:column;gap:16px">
      <div style="display:flex;align-items:center;gap:12px"><span style="width:48px;height:48px;border-radius:50%;display:grid;place-items:center;background:var(--x-success-color-container);color:var(--x-success-on-color-container)">${icon('check', 's32')}</span><h2 class="t-hs" style="margin:0">Ready for VN</h2></div>
      <p class="t-bl" style="margin:0">In VN, tap <b>New project</b> and open the <b>${esc(folder)}</b> folder.</p>
      <div class="vsteps">
        <div class="vstep"><div class="mock" aria-hidden="true"><div class="bar" style="width:60%"></div><div class="bar" style="width:40%"></div><div class="plus">${icon('add', 's32')}</div></div><div><span class="n">Step 1</span><b>Open VN, tap New project</b><span>It's the big + button.</span></div></div>
        <div class="vstep"><div class="mock" aria-hidden="true"><div class="fl">${icon('folder')}Camera</div><div class="fl">${icon('folder')}Download</div><div class="fl hl">${icon('folder', 'fill')}${esc(folder)}</div><div class="fl">${icon('folder')}WhatsApp Video</div></div><div><span class="n">Step 2</span><b>Open the ${esc(folder)} folder</b><span>Inside Movies › TakeTray.</span></div></div>
        <div class="vstep"><div class="mock" aria-hidden="true"><div class="tg">${tg}</div></div><div><span class="n">Step 3</span><b>Select all the clips</b><span>They're already in shooting order.</span></div></div>
      </div><div class="end-space" style="height:16px"></div></div>
      <div style="padding:12px 16px 16px;display:flex;flex-direction:column;gap:8px">${h.btn({ label: 'Open VN', ic: 'open_in_new', kind: 'filled', size: 'lg block', a: 'openVN' })}${h.btn({ label: 'Done', kind: 'text', size: 'block', a: 'vnDone' })}</div></div>`,
    };
  };

  routes.settings = (s) => {
    const vnReels = q.vnReels(s);
    const vnTotal = vnReels.reduce((t, r) => t + q.vnMB(s, r), 0);
    const li = (ic, title, sub, trail, a, d) => `<${a ? 'button' : 'div'} class="li tap"${a ? ` data-a="${a}"` : ''}${h.data(d)}><span class="lead">${icon(ic)}</span><span class="txt"><b>${title}</b>${sub ? `<span>${sub}</span>` : ''}</span>${trail || ''}</${a ? 'button' : 'div'}>`;
    const chev = icon('chevron_right');
    const watched = s.folders.filter((f) => f.watched).map((f) => f.name).join(', ') || 'None';
    const access = s.access === 'full' ? ['All videos', `<span class="trail">${icon('check_circle', 'fill pc')}</span>`] : s.access === 'removed' ? ['Not allowed', h.btn({ label: 'Allow', kind: 'tonal', size: 'sm', a: 'allowAccess' })] : ['Some videos only · Manual mode', h.btn({ label: 'Allow all', kind: 'tonal', size: 'sm', a: 'allowAccess' })];
    return {
      nav: 'settings',
      html: `<div class="scr">${h.appbar({ title: 'Settings', big: true })}<div class="scroll" data-scroll="settings">
        <div class="li-h">Shooting mode</div>
        ${li('timer', 'Remind me to turn it off', 'If Shooting mode stays on for 14 days', h.sw(s.settings.shootingReminder, { a: 'setToggle', d: { k: 'shootingReminder' }, label: 'Remind me to turn off Shooting mode' }))}
        <div class="li-h">Reminders</div>
        ${li('bedtime', 'Evening reminder', `${s.settings.eveningTime}, only if clips are waiting`, h.sw(s.settings.evening, { a: 'setToggle', d: { k: 'evening' }, label: 'Evening reminder' }))}
        ${s.settings.evening ? li('schedule', 'Reminder time', s.settings.eveningTime, chev, 'noop') : ''}
        ${li('folder_copy', 'VN copies reminder', '3 days after copying, if copies are still there', h.sw(s.settings.vnReminder, { a: 'setToggle', d: { k: 'vnReminder' }, label: 'VN copies reminder' }))}
        <div class="li-h">Clips</div>
        ${li('folder_open', 'Watched folders', watched, chev, 'go', { r: 'watched' })}
        ${li('sd_storage', 'Storage used by VN copies', vnReels.length ? `${fmt.size(vnTotal)} in ${fmt.n(vnReels.length, 'reel')}` : 'None', chev, 'go', { r: 'vn-storage' })}
        <div class="li-h">Help</div>
        ${li('notifications_off', 'Notifications not arriving?', 'Steps for Samsung, Xiaomi, Realme and more', chev, 'go', { r: 'notif-help' })}
        <div class="li-h">Your data</div>
        ${li('settings_backup_restore', 'Export and import', `Last backup: ${fmt.dateShort(s.settings.lastExport)}`, chev, 'go', { r: 'backup' })}
        <div class="li-h">Permissions</div>
        ${li('photo_library', 'Video access', access[0], access[1])}
        ${li('notifications', 'Notifications', s.notifPerm ? 'Allowed' : 'Not allowed', s.notifPerm ? `<span class="trail">${icon('check_circle', 'fill pc')}</span>` : h.btn({ label: 'Allow', kind: 'tonal', size: 'sm', a: 'askNotif' }))}
        <div class="li-h">About</div>
        ${li('shield', 'Your videos never leave your phone', 'No account, no cloud, no ads. TakeTray only stores which clips are in which reel.')}
        ${li('info', 'TakeTray', 'Version 1.0.0')}
        <div class="end-space"></div></div>${h.navbar('settings', s.toTag.length)}</div>`,
    };
  };

  routes.watched = (s) => ({
    html: `<div class="scr">${h.appbar({ title: 'Watched folders', nav: 'back' })}<div class="scroll"><div class="infobar">${icon('info')}<span>While Shooting mode is on, new videos saved in these folders go to To tag.</span></div>
      ${s.folders.map((f) => `<div class="li tall"><span class="lead box">${icon(f.id === 'camera' ? 'photo_camera' : 'folder', 'fill')}</span><span class="txt"><b>${esc(f.name)}</b><span>${esc(f.path)} · ${fmt.n(f.count, 'video')}</span></span>${h.sw(f.watched, { a: 'watchToggle', d: { id: f.id }, label: `Watch ${f.name}` })}</div>`).join('')}
      <button class="li tap" data-a="noop"><span class="lead pc">${icon('create_new_folder')}</span><span class="txt"><b class="pc">Add a folder</b></span></button>
      <div class="callout" style="margin:12px 16px">${icon('lightbulb')}<div>Pro camera apps like Open Camera or MotionCam save to their own folders. Turn them on here if you shoot with them.</div></div></div></div>`,
  });

  routes['vn-storage'] = (s) => {
    const reels = q.vnReels(s);
    const total = reels.reduce((t, r) => t + q.vnMB(s, r), 0);
    const body = reels.length
      ? `<div style="padding:8px 16px 4px"><div class="t-hs">${fmt.size(total)}</div><div class="t-bm v">used by VN copies in ${fmt.n(reels.length, 'reel')}</div></div>
        ${reels.map((r) => { const c = q.cover(s, r.id); return `<div class="li tall"><span class="thumb">${c ? h.img(c) : icon('movie')}</span><span class="txt"><b>${esc(r.name)}</b><span>${fmt.n(r.vn.copied.length, 'copy', 'copies')} · ${fmt.size(q.vnMB(s, r))} · since ${fmt.dateShort(r.vn.since)}</span></span>${h.btn({ label: 'Delete', kind: 'text', a: 'doneEditing', d: { id: r.id, from: 'storage' }, cls: 'danger' })}</div>`; }).join('')}
        <div class="callout ok" style="margin:12px 16px">${icon('verified_user', 'fill')}<div>Copies are only for VN. Deleting them never touches your original clips.</div></div>`
      : h.empty({ ill: 'folder', title: 'No VN copies', body: 'When you edit a reel in VN, its temporary copies show up here.' });
    return { html: `<div class="scr">${h.appbar({ title: 'VN copies', nav: 'back' })}<div class="scroll">${body}</div></div>` };
  };

  routes['notif-help'] = (s, u) => {
    const open = u.p.open || 'samsung';
    const brands = [
      ['samsung', 'Samsung', ['Open Settings › Battery › Background usage limits.', 'Tap Never sleeping apps and add TakeTray.', 'If TakeTray is under Sleeping apps, remove it.'], 'Open battery settings'],
      ['xiaomi', 'Xiaomi, Redmi, POCO', ['Long-press the TakeTray icon › App info.', 'Turn on Autostart.', 'Tap Battery saver › No restrictions.'], 'Open app info'],
      ['oppo', 'Oppo, Realme', ['Long-press the TakeTray icon › App info › Battery usage.', 'Turn on Allow background activity.', 'Turn on Allow auto launch.'], 'Open app info'],
      ['vivo', 'Vivo, iQOO', ['Open Settings › Battery › Background power consumption management.', 'Find TakeTray and choose Allow.'], 'Open battery settings'],
      ['oneplus', 'OnePlus', ['Long-press the TakeTray icon › App info › Battery.', 'Choose Unrestricted.'], 'Open app info'],
    ];
    return {
      html: `<div class="scr">${h.appbar({ title: 'Notifications not arriving?', nav: 'back' })}<div class="scroll">
      <p class="t-bm v" style="margin:0 16px 12px">Some phones stop apps in the background to save battery. Then the "new clips" notification can be late or missing.</p>
      <div class="callout ok" style="margin:0 16px 16px">${icon('verified', 'fill')}<div><b>Your clips are never lost</b>They show up in To tag when you open the app.</div></div>
      ${brands.map(([id, name, steps, btn]) => `<div class="acc"><button class="ah tap" data-a="helpOpen" data-id="${id}" aria-expanded="${open === id}"><span class="grow">${name}</span>${id === 'samsung' ? '<span class="you">Your phone</span>' : ''}${icon(open === id ? 'expand_less' : 'expand_more')}</button>${open === id ? `<div class="ab"><ol>${steps.map((x) => `<li>${x}</li>`).join('')}</ol>${h.btn({ label: btn, ic: 'open_in_new', kind: 'tonal', a: 'openSettingsApp' })}</div>` : ''}</div>`).join('')}
      <p class="t-bs v" style="margin:8px 16px 24px">Menu names can be a little different on your phone.</p></div></div>`,
    };
  };

  routes.backup = (s) => ({
    html: `<div class="scr">${h.appbar({ title: 'Export and import', nav: 'back' })}<div class="scroll" style="display:flex;flex-direction:column;gap:12px;padding:4px 16px 24px">
      <section class="desc" style="margin:0;padding:16px;display:flex;flex-direction:column;gap:8px"><div class="row">${icon('download', 'pc')}<b class="t-tm">Export a backup</b></div><p class="v" style="margin:0">Saves your reels, tags and shot ideas to a file. Your videos aren't in it; they stay in your gallery.</p><p class="t-bs v" style="margin:0">Last backup: ${fmt.dateShort(s.settings.lastExport)} 2026</p><div>${h.btn({ label: 'Export backup', kind: 'filled', a: 'exportData' })}</div></section>
      <section class="desc" style="margin:0;padding:16px;display:flex;flex-direction:column;gap:8px"><div class="row">${icon('upload_file', 'pc')}<b class="t-tm">Import a backup</b></div><p class="v" style="margin:0">Brings back reels and tags from a backup made on this phone. It replaces everything in the app now.</p><div>${h.btn({ label: 'Import backup', kind: 'outlined', a: 'importData' })}</div></section>
      <div class="callout warn">${icon('smartphone', 'fill')}<div><b>Moving to a new phone?</b>That isn't supported yet. A backup only links to videos on this phone, so on a new phone every clip would show as missing.</div></div></div></div>`,
  });

  routes['perm-lost'] = () => ({
    html: `<div class="scr"><div style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;gap:12px;padding:24px 32px">${h.illus('perm').replace('class="ill"', 'class="ill" style="width:200px;height:166px"')}<h2 class="t-hs" style="margin:0">Allow video access again</h2><p class="t-bm v" style="margin:0">Android turned off TakeTray's video access, maybe because the app wasn't used for a while. Your reels and tags are safe.</p></div>
      <div style="padding:12px 16px 16px;display:flex;flex-direction:column;gap:8px">${h.btn({ label: 'Allow access', kind: 'filled', size: 'lg block', a: 'askVideo' })}${h.btn({ label: 'Continue in Manual mode', kind: 'text', size: 'block', a: 'obManualHome' })}</div></div>`,
  });

  routes.camera = (s, u) => {
    const last = Object.values(s.clips).sort((a, b) => (a.at < b.at ? 1 : -1))[0];
    const scene = u.p.scene || { theme: 'street', seed: 77 };
    return {
      video: true,
      html: `<div class="scr" style="background:#000"><div class="cam"><div style="position:absolute;top:32px;left:4px;z-index:3">${h.ib('arrow_back', { a: 'closeCamera', label: 'Back to TakeTray' })}</div>
        <div class="vf"><img src="${RH.thumb(scene.theme, scene.seed, 'v')}" alt="Camera viewfinder">${u.p.rec ? `<span class="timer">00:0${(u.p.tick || 3) % 10}</span>` : ''}</div>
        ${!s.shooting.on ? `<div class="note">${icon('info', 'fill')}<span>Phone camera (simulated). Shooting mode is off, so clips you shoot now won't go to To tag.</span></div>` : u.p.count ? `<div class="note">${icon('check_circle', 'fill')}<span>${fmt.n(u.p.count, 'clip')} shot. ${s.access === 'full' ? (u.p.count === 1 ? 'It waits in To tag.' : 'They wait in To tag.') : 'Manual mode: add them yourself from To tag.'}</span></div>` : `<div class="note">${icon('info', 'fill')}<span>Phone camera (simulated). Tap the red button to shoot a clip.</span></div>`}
        <div class="modes"><span>PHOTO</span><span class="on">VIDEO</span><span>PRO</span></div>
        <div class="ctrl"><span class="gthumb"><img src="${RH.thumb(last.theme, last.seed, 'v')}" alt=""></span><button class="shutter ${u.p.rec ? 'rec' : ''}" data-a="camShutter" aria-label="${u.p.rec ? 'Stop recording' : 'Start recording'}"><i></i></button><span class="ms" style="color:#fff;width:44px;text-align:center" aria-hidden="true">flip_camera_android</span></div></div></div>`,
    };
  };

  /* ------------------------------------------------------------------ */
  /* Overlays                                                            */
  /* ------------------------------------------------------------------ */
  const sheets = (RH.sheets = {});

  sheets.reelForm = (s, u) => {
    const f = u.sheet;
    const edit = f.mode === 'edit';
    const fromPlayer = f.from === 'player';
    const statuses = Object.entries(h.STATUS).map(([k, st]) => `<button class="li tap" data-a="formStatus" data-st="${k}" role="radio" aria-checked="${f.status === k}" style="padding:4px 8px"><span class="radio ${f.status === k ? 'on' : ''}"></span>${h.statusPill(k)}<span class="t-bs v grow">${st.desc}</span></button>`).join('');
    return `<div class="sheet ${f.fresh ? 'fresh' : ''}" role="dialog" aria-modal="true" aria-labelledby="sh-t"><div class="handle"></div><div class="sh-head"><h2 id="sh-t">${edit ? 'Reel details' : 'New reel'}</h2>${fromPlayer ? '<p>This clip will be added to it.</p>' : ''}</div>
      <div class="sh-body pad24" style="display:flex;flex-direction:column;gap:8px;padding-bottom:12px">
      ${h.tf({ id: 'rname', label: 'Reel name', value: f.name || '', ph: 'For example: London Food', focus: f.focus !== 'desc' && u.kbd, err: f.err, counter: 40, a: 'formName' })}
      ${fromPlayer ? '' : h.tf({ id: 'rref', label: 'Reference link (optional)', value: f.ref || '', ph: 'Paste an Instagram reel link', err: f.refErr, help: edit && (q.reel(s, f.id).refs || []).length ? `${fmt.n(q.reel(s, f.id).refs.length, 'reference')} saved. Add another, or manage them on the reel.` : 'A reel you want to recreate. You can add more later.', a: 'formRef' })}
      ${fromPlayer ? '' : h.tf({ id: 'rdesc', label: 'Shot ideas (optional)', value: f.desc || '', ph: 'Concept, shots to get, songs to try…', multi: true, help: 'Only you see this.', focus: f.focus === 'desc', a: 'formDesc' })}
      ${edit ? `<div class="t-lm v" style="margin-top:8px">Status</div><div role="radiogroup" aria-label="Status">${statuses}</div>` : ''}
      </div><div class="sh-foot">${h.btn({ label: 'Cancel', kind: 'text', a: 'closeSheet' })}${h.btn({ label: edit ? 'Save' : fromPlayer ? 'Create and add' : 'Create reel', kind: 'filled', a: 'formSave' })}</div>${u.kbd ? h.keyboard() : ''}</div>`;
  };

  sheets.picker = (s, u) => {
    const pk = u.sheet;
    const multi = pk.mode !== 'move';
    const picked = pk.picked || [];
    const n = pk.ids.length;
    const exclude = pk.exclude;
    const all = q.orderedReels(s).filter((r) => r.id !== exclude);
    const rec = all.filter((r) => r.status === 'rec');
    const other = all.filter((r) => r.status !== 'rec');
    const row = (r) => { const c = q.cover(s, r.id); const on = picked.includes(r.id); return `<button class="li tap" data-a="pickReel" data-id="${r.id}" role="${multi ? 'checkbox' : 'radio'}" aria-checked="${on}"><span class="thumb" style="width:40px;height:52px">${c ? h.img(c) : icon('movie')}</span><span class="txt"><b class="clamp1">${esc(r.name)}</b><span>${fmt.n(q.clipsOf(s, r.id).length, 'clip')}</span></span>${multi ? `<span class="cbox ${on ? 'on' : ''}">${icon('check')}</span>` : `<span class="radio ${on ? 'on' : ''}"></span>`}</button>`; };
    const title = pk.mode === 'tag' ? `Tag ${fmt.n(n, 'clip')}` : pk.mode === 'add' ? `Add ${n > 1 ? fmt.n(n, 'clip') : 'clip'} to reels` : `Move ${n > 1 ? fmt.n(n, 'clip') : 'clip'} to`;
    const sub = pk.mode === 'tag' ? 'Pick one or more reels.' : pk.mode === 'add' ? 'It stays in this reel too.' : `${n > 1 ? 'They leave' : 'It leaves'} ${esc(q.reel(s, exclude) ? q.reel(s, exclude).name : 'this reel')}.`;
    const confirm = pk.mode === 'tag' ? (picked.length > 1 ? `Tag into ${picked.length} reels` : `Tag ${fmt.n(n, 'clip')}`) : pk.mode === 'add' ? (picked.length ? `Add to ${fmt.n(picked.length, 'reel')}` : 'Add') : 'Move';
    const newRow = pk.newOpen
      ? `<div style="padding:4px 16px 8px;display:flex;gap:8px;align-items:flex-start"><div class="grow">${h.tf({ id: 'pkname', label: 'New reel name', value: pk.newName || '', ph: 'For example: London Food', focus: true, err: pk.err, a: 'pickerName' })}</div><div style="padding-top:12px">${h.btn({ label: 'Create', kind: 'tonal', a: 'pickerCreate' })}</div></div>`
      : `<button class="li tap" data-a="pickerNew"><span class="lead box" style="background:var(--md-secondary-container);color:var(--md-on-secondary-container)">${icon('add')}</span><span class="txt"><b class="pc">New reel</b></span></button>`;
    return `<div class="sheet ${pk.fresh ? 'fresh' : ''}" role="dialog" aria-modal="true" aria-labelledby="pk-t" style="max-height:${u.kbd ? '96%' : '86%'}"><div class="handle"></div><div class="sh-head"><h2 id="pk-t">${title}</h2><p>${sub}</p></div>
      <div class="sh-body">${newRow}${rec.length ? `<div class="li-h" style="padding-top:8px">Recording</div>${rec.map(row).join('')}` : ''}${other.length ? `<div class="li-h">Other reels</div>${other.map(row).join('')}` : ''}<div style="height:8px"></div></div>
      <div class="sh-foot">${h.btn({ label: 'Cancel', kind: 'text', a: 'closeSheet' })}${h.btn({ label: confirm, kind: 'filled', a: 'pickerConfirm', dis: !picked.length })}</div>${u.kbd ? h.keyboard() : ''}</div>`;
  };

  sheets.editor = (s, u) => {
    const e = u.sheet;
    const clips = e.ids.map((id) => s.clips[id]);
    const inst = s.editorsInstalled;
    const row = (key, name, sub, a) => {
      const ok = key === 'other' || inst[key];
      return `<button class="li tall tap ${ok ? '' : 'dis'}" ${ok ? `data-a="${a}" data-ed="${key}"` : 'aria-disabled="true"'}>${h.editorIcon(key)}<span class="txt"><b>${name}</b><span>${ok ? sub : 'Not installed'}</span></span>${ok ? icon('chevron_right') : ''}</button>`;
    };
    const vnMB = q.sizeOf(clips);
    return `<div class="sheet ${e.fresh ? 'fresh' : ''}" role="dialog" aria-modal="true" aria-labelledby="ed-t"><div class="handle"></div><div class="sh-head"><h2 id="ed-t">Edit ${fmt.n(clips.length, 'clip')} in…</h2><p>${fmt.dur(q.total(clips))} · in shooting order</p></div>
      <div class="sh-body" style="padding-bottom:12px">${row('capcut', 'CapCut', 'Gets your original clips', 'pickEditor')}${row('edits', 'Instagram Edits', 'Gets your original clips', 'pickEditor')}${row('vn', 'VN', `Makes temporary copies · ${fmt.size(vnMB)}`, 'pickEditor')}${row('other', 'Other app…', "Opens Android's share menu", 'pickEditor')}
      ${!inst.capcut || !inst.edits || !inst.vn ? '<p class="t-bs v" style="margin:8px 24px 0">Editors you don\'t have are greyed out.</p>' : ''}</div></div>`;
  };

  sheets.share = (s, u) => {
    const apps = [['share', 'Quick Share'], ['add_to_drive', 'Drive'], ['sms', 'Messages'], ['mail', 'Gmail'], ['bluetooth', 'Bluetooth'], ['folder', 'Files'], ['send', 'Telegram'], ['more_horiz', 'More']];
    return `<div class="sheet ${u.sheet.fresh ? 'fresh' : ''}" role="dialog" aria-modal="true" aria-label="Android share menu"><div class="handle"></div><div class="sh-head"><h2>Share ${fmt.n(u.sheet.n || 1, 'video')}</h2><p>Android's share menu (shown by the system)</p></div><div class="share-grid">${apps.map(([ic, n]) => `<div><span class="appic-g" style="background:var(--md-surface-container-highest);color:var(--md-on-surface)">${icon(ic)}</span>${n}</div>`).join('')}</div></div>`;
  };

  sheets.manualPick = (s, u) => `<div class="sheet ${u.sheet.fresh ? 'fresh' : ''}" role="dialog" aria-modal="true" aria-labelledby="mp-t"><div class="handle"></div><div class="sh-head"><h2 id="mp-t">Pick videos yourself</h2></div>
    <div class="sh-body pad24" style="display:flex;flex-direction:column;gap:12px;padding-bottom:12px"><p class="t-bm v" style="margin:0">TakeTray can see only some of your videos (Manual mode), so it opens Android's photo picker.</p>
    <div class="callout">${icon('info')}<div>The photo picker doesn't show folder counts, and it can't mark videos you've already added.</div></div></div>
    <div class="sh-foot" style="flex-direction:column">${h.btn({ label: 'Open photo picker', kind: 'filled', size: 'block', a: 'closeSheet' })}${h.btn({ label: 'Allow full access instead', kind: 'text', size: 'block', a: 'allowAccess' })}</div></div>`;

  const dialogs = (RH.dialogs = {});
  const dlg = (RH.dlg = (ic, title, body, acts) => `<div class="dlg-wrap"><div class="dlg" role="alertdialog" aria-modal="true" aria-labelledby="dlg-t">${ic ? `<span class="dico">${icon(ic)}</span>` : ''}<h2 id="dlg-t">${title}</h2>${body}<div class="acts">${acts}</div></div></div>`);
  dialogs.deleteReel = (s, u) => {
    const r = q.reel(s, u.dialog.id);
    const vn = r.vn ? `<p>The ${fmt.n(r.vn.copied.length, 'VN copy', 'VN copies')} (${fmt.size(q.vnMB(s, r))}) will also be deleted, and the VN project can't be edited after that.</p>` : '';
    return dlg('delete', `Delete ${esc(r.name)}?`, `<div class="safe">${icon('verified_user', 'fill')}<span>Your videos stay in your gallery. Only this reel and its tags are removed.</span></div>${vn}`, h.btn({ label: 'Cancel', kind: 'text', a: 'closeDialog' }) + h.btn({ label: 'Delete reel', kind: 'text danger', a: 'confirmDelete' }));
  };
  dialogs.skipAll = (s) => dlg(null, `Skip all ${fmt.n(s.toTag.length, 'clip')}?`, `<p>They move to Skipped, and you can restore them any time.</p><div class="safe">${icon('verified_user', 'fill')}<span>Your videos stay in your gallery.</span></div>`, h.btn({ label: 'Cancel', kind: 'text', a: 'closeDialog' }) + h.btn({ label: 'Skip all', kind: 'text', a: 'confirmSkipAll' }));
  dialogs.doneEditing = (s, u) => {
    const r = q.reel(s, u.dialog.id);
    return dlg('folder_delete', 'Have you exported your video?', `<p>Once the copies are deleted, the VN project for <b>${esc(r.name)}</b> can't be edited any more. This frees ${fmt.size(q.vnMB(s, r))}.</p><div class="safe">${icon('verified_user', 'fill')}<span>Your original clips are safe in your gallery.</span></div>`, h.btn({ label: 'Not yet', kind: 'text', a: 'closeDialog' }) + h.btn({ label: 'Delete copies', kind: 'text danger', a: 'confirmDoneEditing' }));
  };
  dialogs.markStatus = (s, u) => {
    const r = q.reel(s, u.dialog.id);
    const st = h.STATUS[u.dialog.status];
    return dlg(st.icon, `Mark ${esc(r.name)} as ${st.label}?`, `<p>${u.dialog.status === 'pub' ? 'It moves to the Published filter. You can change this any time.' : 'Helps you find it under Ready to edit. You can change this any time.'}</p>`, h.btn({ label: 'Not now', kind: 'text', a: 'closeDialog' }) + h.btn({ label: `Mark as ${st.label}`, kind: 'tonal', a: 'confirmStatus' }));
  };
  dialogs.importWarn = (s) => dlg('warning', 'Replace everything in the app?', `<p>Your ${fmt.n(s.reels.length, 'reel')} and their tags will be replaced by the backup from 8 Oct 2026.</p><div class="safe">${icon('verified_user', 'fill')}<span>Your videos stay in your gallery.</span></div>`, h.btn({ label: 'Cancel', kind: 'text', a: 'closeDialog' }) + h.btn({ label: 'Replace', kind: 'text danger', a: 'confirmImport' }));
  dialogs.importDone = () => dlg('check_circle', 'Backup restored', '<p><b>120 of 140 clips found.</b> 20 clips aren\'t on this phone any more, so they show as missing. You can remove them from each reel.</p>', h.btn({ label: 'OK', kind: 'text', a: 'closeDialog' }));
  dialogs.stopCopy = (s, u) => dlg(null, 'Stop copying?', `<p>The ${u.p.done || 0} copies made so far will be deleted. Your original clips aren't affected.</p>`, h.btn({ label: 'Keep copying', kind: 'text', a: 'closeDialog' }) + h.btn({ label: 'Stop', kind: 'text danger', a: 'cancelVN' }));
  dialogs.stillShooting = () => dlg('videocam', 'Still shooting?', '<p>Shooting mode has been on for 14 days. While it\'s on, every new video goes to To tag.</p>', h.btn({ label: 'Keep it on', kind: 'text', a: 'closeDialog' }) + h.btn({ label: 'Turn off', kind: 'tonal', a: 'shootOffDialog' }));
  dialogs.editorMissing = (s, u) => dlg(null, `${esc(u.dialog.name)} isn't installed`, `<p>Install ${esc(u.dialog.name)} from the Play Store, or choose another editor.</p>`, h.btn({ label: 'Choose another', kind: 'text', a: 'closeDialog' }) + h.btn({ label: 'Open Play Store', kind: 'text', a: 'closeDialog' }));
  dialogs.cantPlay = () => dlg('error', "This video can't be played", '<p>It may be damaged, or in a format your phone doesn\'t support. The file is still in your gallery.</p>', h.btn({ label: 'OK', kind: 'text', a: 'closeDialog' }));

  const menus = (RH.menus = {});
  menus.status = (s, u) => {
    const r = q.reel(s, u.menu.id);
    return `<div class="menu" role="menu" aria-label="Status" style="left:16px;top:${u.menu.top || 140}px;transform-origin:top left">${Object.entries(h.STATUS).map(([k, st]) => `<button class="mi tall tap ${r.status === k ? 'on' : ''}" role="menuitemradio" aria-checked="${r.status === k}" data-a="setStatus" data-st="${k}">${icon(st.icon, 'fill')}<span class="grow">${st.label}<span class="sub">${st.desc}</span></span>${r.status === k ? icon('check') : ''}</button>`).join('')}</div>`;
  };
  menus.reelMore = () => `<div class="menu" role="menu" style="right:8px;top:52px"><button class="mi tap" role="menuitem" data-a="editDetails">${icon('edit')}Reel details</button><button class="mi tap" role="menuitem" data-a="startSelBtn" data-ctx="reel">${icon('checklist')}Select clips</button><button class="mi tap danger" role="menuitem" data-a="askDelete">${icon('delete')}Delete reel</button></div>`;
  menus.reelSel = () => `<div class="menu" role="menu" style="right:8px;top:52px"><button class="mi tap" role="menuitem" data-a="selEdit">${icon('movie_edit')}Edit video</button><button class="mi tap" role="menuitem" data-a="selAll">${icon('select_all')}Select all</button><button class="mi tap" role="menuitem" data-a="share">${icon('share')}Share</button></div>`;
  menus.totagMore = (s) => `<div class="menu" role="menu" style="right:8px;top:60px">${s.access === 'full' ? `<button class="mi tap" role="menuitem" data-a="openEarlier" data-from="totag">${icon('history')}Add earlier videos</button>` : ''}<button class="mi tap" role="menuitem" data-a="startSelBtn" data-ctx="totag">${icon('checklist')}Select clips</button><button class="mi tap" role="menuitem" data-a="go" data-r="skipped">${icon('redo')}Skipped (${s.skipped.length})</button><button class="mi tap" role="menuitem" data-a="askSkipAll">${icon('clear_all')}Skip all</button></div>`;

  function sysDialog(s, u) {
    const t = u.sys.type;
    const a = s.android;
    let ic, title, opts;
    if (t === 'video') {
      ic = 'photo_library';
      if (a >= 14) { title = 'Allow <b>TakeTray</b> to access photos and videos on this device?'; opts = [['Allow all', 'sysAllowAll'], ['Select photos and videos', 'sysLimited'], ["Don't allow", 'sysDeny']]; }
      else if (a >= 13) { title = 'Allow <b>TakeTray</b> to access photos and videos on this device?'; opts = [['Allow', 'sysAllowAll'], ["Don't allow", 'sysDeny']]; }
      else { title = 'Allow <b>TakeTray</b> to access photos, media and files on your device?'; opts = [['Allow', 'sysAllowAll'], ['Deny', 'sysDeny']]; }
    } else {
      ic = 'notifications';
      title = 'Allow <b>TakeTray</b> to send you notifications?';
      opts = [['Allow', 'sysNotifAllow'], ["Don't allow", 'sysNotifDeny']];
    }
    return `<div class="ov"><div class="scrim" style="background:rgba(0,0,0,.55)"></div><div class="sys"><span class="tag">Android ${a >= 14 ? '14+' : a >= 13 ? '13' : '11–12'} system dialog</span><div class="card" role="alertdialog" aria-modal="true"><span class="ms s32" aria-hidden="true">${ic}</span><h3>${title}</h3><div class="opts ${opts.length === 2 ? 'two' : ''}">${opts.map(([l, act]) => `<button data-a="${act}">${l}</button>`).join('')}</div></div></div></div>`;
  }

  function shade(s, u) {
    const sh = u.shade;
    const items = sh.items || RH.activeNotifications(s);
    const cl = s.toTag.slice(-5).map((id) => s.clips[id]);
    const card = {
      new: () => `<button class="notif tap" data-a="notifTap" data-n="new"><div class="nh"><span class="appic">${icon('sell', 'fill')}</span>TakeTray · now</div><div class="nb"><div class="grow"><b>${fmt.n(sh.newCount || Math.min(s.toTag.length, 5), 'new clip')} to tag</b><span>Tap to tag them into your reels.</span></div>${sh.expanded === 'new' ? '' : `<span class="large">${cl[0] ? h.img(cl[0]) : ''}</span>`}</div>${sh.expanded === 'new' ? `<div class="thumbs">${cl.slice(0, 4).map((c) => `<i style="background-image:url(&quot;${RH.thumb(c.theme, c.seed, 'v')}&quot;)"></i>`).join('')}${cl.length > 4 ? `<i class="more">+${cl.length - 4}</i>` : ''}</div>` : ''}<div class="na"><span data-a="notifCam">Open camera</span><span data-a="notifTap" data-n="new">Tag now</span></div></button>`,
      evening: () => `<button class="notif tap" data-a="notifTap" data-n="evening"><div class="nh"><span class="appic">${icon('sell', 'fill')}</span>TakeTray · 9:00 pm</div><div class="nb"><div class="grow"><b>You shot ${fmt.n(s.toTag.length, 'clip')} today. Tag them?</b><span>Takes a few minutes, one tap per clip.</span></div></div><div class="na"><span data-a="notifTap" data-n="evening">Tag now</span></div></button>`,
      vn: () => { const r = q.vnReels(s)[0]; return r ? `<button class="notif tap" data-a="notifTap" data-n="vn" data-id="${r.id}"><div class="nh"><span class="appic">${icon('folder_copy', 'fill')}</span>TakeTray · 3 days ago</div><div class="nb"><div class="grow"><b>${esc(r.name)} copies are using ${fmt.size(q.vnMB(s, r))}</b><span>Done editing? Tap to clean up.</span></div></div><div class="na"><span data-a="notifTap" data-n="vn" data-id="${r.id}">Done editing</span></div></button>` : ''; },
      still: () => `<button class="notif tap" data-a="notifTap" data-n="still"><div class="nh"><span class="appic">${icon('videocam', 'fill')}</span>TakeTray · 10:00 am</div><div class="nb"><div class="grow"><b>Still shooting?</b><span>Shooting mode has been on for 14 days. Turn it off?</span></div></div><div class="na"><span data-a="notifStillOff">Turn off</span><span data-a="closeShade">Keep on</span></div></button>`,
    };
    return `<div class="shade" role="dialog" aria-label="Notification shade"><div class="clock">7:24</div><div class="date">Mon, 12 October</div><div class="qs" aria-hidden="true"><div class="on">${icon('wifi', 'fill')}Wi-Fi</div><div>${icon('bluetooth')}Bluetooth</div><div>${icon('flashlight_off')}Torch</div><div class="on">${icon('do_not_disturb_on', 'fill')}Do not disturb</div></div>
      <div class="lbl">Notifications</div>${items.length ? items.map((k) => card[k]()).join('') : '<p class="t-bm v" style="padding:8px">No notifications</p>'}
      <button class="btn text" data-a="closeShade" style="align-self:center;margin-top:8px">Close</button></div>`;
  }

  RH.activeNotifications = (s) => {
    const out = [];
    if (s.notifPerm && s.toTag.length && s.access === 'full') out.push('new');
    if (s.notified.evening && s.toTag.length) out.push('evening');
    if (s.notified.vn && q.vnReels(s).length) out.push('vn');
    if (s.notified.still && s.shooting.on) out.push('still');
    return out;
  };

  /* ------------------------------------------------------------------ */
  /* Composer                                                            */
  /* ------------------------------------------------------------------ */
  RH.renderPhone = function (s, u) {
    const r = (routes[u.route] || routes.home)(s, u);
    let ov = '';
    if (u.menu && menus[u.menu.type]) ov += `<div class="ov"><div class="scrim" style="background:transparent" data-a="closeMenu"></div>${menus[u.menu.type](s, u)}</div>`;
    if (u.sheet && sheets[u.sheet.type]) ov += `<div class="ov"><div class="scrim" data-a="closeSheet"></div>${sheets[u.sheet.type](s, u)}</div>`;
    if (u.dialog && dialogs[u.dialog.type]) ov += `<div class="ov"><div class="scrim" style="background:rgba(0,0,0,.5)"></div>${dialogs[u.dialog.type](s, u)}</div>`;
    if (u.sys) ov += sysDialog(s, u);
    if (u.snack && u.route !== 'player') {
      const bottom = r.nav ? 92 : u.route === 'add-grid' || u.route === 'edit-select' ? 84 : 12;
      ov += h.snack({ ...u.snack, bottom });
    }
    if (u.shade) ov += shade(s, u);
    return { html: `${h.statusbar(r.video)}<div class="vp${u.fs2 ? ' fs2' : ''}">${r.html}${ov}</div><div class="gbar ${r.video ? 'on-video' : ''}"></div>`, video: !!r.video, splash: !!r.splash };
  };
})();
