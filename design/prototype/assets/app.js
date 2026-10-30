/* TakeTray design hub: page router, screen galleries, design system,
   navigation map, and the interactive prototype engine. */
(function () {
  const RH = window.RH;
  const { fmt, q, h } = RH;
  const $ = (sel, el = document) => el.querySelector(sel);
  const clone = (o) => (typeof structuredClone === 'function' ? structuredClone(o) : JSON.parse(JSON.stringify(o)));
  const store = {
    get(k, d) { try { const v = localStorage.getItem('rh.' + k); return v == null ? d : JSON.parse(v); } catch (e) { return d; } },
    set(k, v) { try { localStorage.setItem('rh.' + k, JSON.stringify(v)); } catch (e) { /* storage unavailable */ } },
  };

  /* ================================================================== */
  /* Phone frame                                                         */
  /* ================================================================== */
  function phoneHTML(s, u, theme, { label, inert } = {}) {
    const out = RH.renderPhone(s, u);
    return `<div class="phone" ${inert ? `role="img" aria-label="${h.esc(label || '')}"` : ''}><div class="ph rh-${theme} ${out.video ? 'video' : ''}" ${inert ? 'inert' : ''} style="${out.video ? 'background:#000' : ''}">${out.html}</div></div>`;
  }

  /* ================================================================== */
  /* Router                                                              */
  /* ================================================================== */
  const views = ['overview', 'prototype', 'system', 'colours', 'navmap', 'brand', 'motion', 'a11y', 'handoff', 'decisions'];
  const viewTitle = { overview: 'Overview', prototype: 'Prototype', system: 'Design system', colours: 'Colour options', navmap: 'Navigation map', brand: 'Name and icon', motion: 'Motion', a11y: 'Accessibility', handoff: 'Developer handoff', decisions: 'Decisions and questions' };
  let galleryTheme = store.get('theme', 'both');

  function buildSide() {
    const groups = [];
    RH.SCREENS.forEach((sc) => {
      let g = groups.find((x) => x.name === sc.group);
      if (!g) groups.push((g = { name: sc.group, items: [] }));
      g.items.push(sc);
    });
    const link = (id, label, n) => `<a href="#${id}" data-view="${id}">${n != null ? `<span class="n">${n}</span>` : ''}<span>${label}</span></a>`;
    $('#side-nav').innerHTML = `<h4>Start</h4>${link('overview', 'Overview')}${link('prototype', 'Interactive prototype')}${link('navmap', 'Navigation map')}
      <h4>Foundations</h4>${link('colours', 'Colour options')}${link('system', 'Design system')}${link('brand', 'Name and icon')}${link('motion', 'Motion')}${link('a11y', 'Accessibility')}
      ${groups.map((g) => `<h4>${g.name}</h4>${g.items.map((sc) => link('screen-' + String(sc.n).padStart(2, '0'), sc.title, sc.n)).join('')}`).join('')}
      <h4>Handoff</h4>${link('handoff', 'Developer handoff')}${link('decisions', 'Decisions and questions')}`;
  }

  function route() {
    const hash = (location.hash || '#overview').slice(1);
    const id = /^screen-\d\d$/.test(hash) || views.includes(hash) ? hash : 'overview';
    document.querySelectorAll('.view').forEach((v) => { v.hidden = true; });
    document.querySelectorAll('#side-nav a').forEach((a) => { if (a.dataset.view === id) a.setAttribute('aria-current', 'page'); else a.removeAttribute('aria-current'); });
    if (id.startsWith('screen-')) {
      renderScreen(+id.slice(7));
      $('#v-screen').hidden = false;
    } else {
      const el = $('#v-' + id);
      el.hidden = false;
      if (id === 'prototype') App.mount();
      if (id === 'system' && !el.dataset.done) { renderSystem(); el.dataset.done = '1'; }
      if (id === 'colours' && !el.dataset.done) { renderColours(); el.dataset.done = '1'; }
      if (id === 'navmap' && !el.dataset.done) { renderNavmap(); el.dataset.done = '1'; }
      if (id === 'overview' && !el.dataset.done) { renderOverview(); el.dataset.done = '1'; }
      if (id === 'brand' && !el.dataset.done) { renderBrand(); el.dataset.done = '1'; }
    }
    document.title = 'TakeTray Design';
    closeSide();
    window.scrollTo(0, 0);
  }

  function closeSide() { $('.side').classList.remove('open'); $('.scrim-side').classList.remove('show'); }

  /* ================================================================== */
  /* Screen galleries                                                    */
  /* ================================================================== */
  function themeToggle() {
    const b = (v, l) => `<button data-gtheme="${v}" aria-pressed="${galleryTheme === v}">${l}</button>`;
    return `<div class="seg-ctl" role="group" aria-label="Theme">${b('both', 'Light + dark')}${b('light', 'Light')}${b('dark', 'Dark')}</div>`;
  }

  function renderScreen(n) {
    const sc = RH.SCREENS.find((x) => x.n === n);
    const idx = RH.SCREENS.indexOf(sc);
    const prev = RH.SCREENS[idx - 1], next = RH.SCREENS[idx + 1];
    const themes = galleryTheme === 'both' ? ['light', 'dark'] : [galleryTheme];
    const states = sc.states.map((st) => {
      const { s, u } = RH.buildState(sc, st);
      const frames = themes.map((t) => `<div class="frame-wrap"><span class="frame-tag">${t}</span>${phoneHTML(s, u, t, { inert: true, label: `${sc.title}: ${st.label}, ${t} theme` })}</div>`).join('');
      return `<section class="state" aria-labelledby="st-${sc.id}-${st.id}"><div class="state-head"><h3 id="st-${sc.id}-${st.id}">${h.esc(st.label)}</h3><button class="pbtn" data-try="${sc.id}|${st.id}">${h.icon('touch_app')}Try it in the prototype</button>${st.desc ? `<p>${h.esc(st.desc)}</p>` : ''}</div><div class="pair">${frames}</div></section>`;
    }).join('');
    const spec = sc.spec ? `<div class="spec">${Object.entries(sc.spec).map(([k, v]) => `<div><h4>${h.esc(k)}</h4><p>${h.esc(v)}</p></div>`).join('')}</div>` : '';
    $('#v-screen').innerHTML = `<div class="view-head"><div><p class="eyebrow">Screen ${sc.n} of ${RH.SCREENS.length} · ${h.esc(sc.group)}</p><h1>${h.esc(sc.title)}</h1></div>${themeToggle()}</div>
      <ul class="notes">${sc.notes.map((x) => `<li>${h.esc(x)}</li>`).join('')}</ul>${spec}
      <p class="muted" style="margin:18px 0 22px">${sc.states.length} state${sc.states.length > 1 ? 's' : ''} at 360 dp.</p><div class="states">${states}</div>
      <div class="row" style="display:flex;justify-content:space-between;gap:12px;margin-top:40px;flex-wrap:wrap">${prev ? `<a class="pbtn" href="#screen-${String(prev.n).padStart(2, '0')}">${h.icon('arrow_back')}${prev.n}. ${h.esc(prev.title)}</a>` : '<span></span>'}${next ? `<a class="pbtn" href="#screen-${String(next.n).padStart(2, '0')}">${next.n}. ${h.esc(next.title)}${h.icon('arrow_forward')}</a>` : ''}</div>`;
  }

  /* ================================================================== */
  /* Overview, brand, system, navmap                                     */
  /* ================================================================== */
  function renderOverview() {
    const sample = (route, setup, theme) => { const s = RH.fixture(); const u = RH.defaultUI(); setup(s, u); u.route = u.route || route; return phoneHTML(s, u, theme, { inert: true, label: route }); };
    $('#ov-phones').innerHTML = [
      sample('home', () => {}, 'light'),
      sample('totag', (s, u) => { u.route = 'totag'; }, 'dark'),
      sample('player', (s, u) => { const sess = s.toTag.slice(); s.toTag.slice(0, 4).forEach((id) => s.clips[id].reels.push('r1')); s.toTag = s.toTag.slice(4); s.lastTags = ['r1']; u.route = 'player'; u.player = { session: sess, i: 4, multi: false, picked: [], muted: true, paused: false, tagged: {}, skippedN: 0 }; u.snack = { text: 'Added to London Food', undo: true, ic: 'check_circle' }; }, 'light'),
    ].map((x) => `<div class="frame-wrap">${x}</div>`).join('');
  }

  function renderBrand() {
    const T = window.TT_ICONS;
    $('#brand-icons').innerHTML = Object.keys(T).map((v) => {
      const c = T[v];
      const sizes = [192, 96, 48, 24].map((z) => `<figure><span>${h.brandIcon(z, v, 'circle')}</span><figcaption>${z} dp</figcaption></figure>`).join('');
      return `<div class="card icon-card ${v === 'tray' ? 'rec' : ''}"><div class="icon-row">${sizes}<figure><span>${h.brandIcon(64, v, 'squircle')}</span><figcaption>squircle</figcaption></figure></div>
        <div class="icon-row"><figure><span class="rh-light" style="display:block">${h.brandIcon(64, v, 'circle', 'mono')}</span><figcaption>themed, light</figcaption></figure><figure><span class="rh-dark" style="display:block">${h.brandIcon(64, v, 'circle', 'mono')}</span><figcaption>themed, dark</figcaption></figure>
        <figure><span class="notif-prev">${h.brandIcon(24, v, 'circle', 'notif')}<b>TakeTray · now</b></span><figcaption>notification icon, 24 dp</figcaption></figure></div>
        <h3 style="margin:14px 0 4px">${h.esc(c.name)}${v === 'tray' ? ' <span class="pill ready" style="vertical-align:2px">Recommended</span>' : ''}</h3><p class="muted" style="margin:0">${h.esc(c.note)}</p>
        <p class="muted" style="margin:8px 0 0;font-size:13px">Files: <code>design/handoff/icons/${v}/</code></p></div>`;
    }).join('');
  }

  /* ---------------------------------------------------------------- */
  /* Brand colour options                                               */
  /* ---------------------------------------------------------------- */
  let palette = 'graphite'; // chosen 2026-10-23
  function swatches() {
    return Object.entries(window.RH_PALETTES).map(([k, v]) => `<button class="palsw" data-pal="${k}" role="radio" aria-checked="${k === palette}" aria-label="${h.esc(v.name)}" title="${h.esc(v.name)}" style="--a:${v.light.primary};--b:${v.light.tertiaryContainer}"></button>`).join('');
  }
  function syncSwatches() {
    document.querySelectorAll('.palpick').forEach((el) => { el.innerHTML = swatches(); });
    document.querySelectorAll('.palname').forEach((el) => { el.textContent = window.RH_PALETTES[palette].name; });
    document.querySelectorAll('[data-usepal]').forEach((b) => { const on = b.dataset.usepal === palette; b.setAttribute('aria-pressed', on); b.classList.toggle('primary', on); b.lastChild.textContent = on ? 'In use' : 'Use this colour'; });
  }
  function applyPalette(id) {
    if (!window.RH_PALETTES[id]) id = 'graphite';
    palette = id;
    const root = document.documentElement;
    [...root.classList].filter((c) => c.startsWith('pal-')).forEach((c) => root.classList.remove(c));
    root.classList.add('pal-' + id);
    store.set('palette2', id);
    syncSwatches();
    const sys = $('#v-system');
    if (sys) { sys.dataset.done = ''; if (!sys.hidden) { renderSystem(); sys.dataset.done = '1'; } }
  }
  RH.applyPalette = applyPalette;

  function renderColours() {
    const sw = (c, label) => `<span class="cswatch"><i style="background:${c}"></i><b>${label}</b><code>${c}</code></span>`;
    $('#colour-opts').innerHTML = Object.entries(window.RH_PALETTES).map(([k, v]) => {
      const mk = (setup, theme) => { const s = RH.fixture(); const u = RH.defaultUI(); setup(s, u); return phoneHTML(s, u, theme, { inert: true, label: `${v.name}: ${u.route}, ${theme}` }); };
      const home = (s, u) => {};
      const player = (s, u) => { const sess = s.toTag.slice(); s.toTag.slice(0, 4).forEach((id) => s.clips[id].reels.push('r1')); s.toTag = s.toTag.slice(4); s.lastTags = ['r1']; u.route = 'player'; u.player = { session: sess, i: 4, multi: false, picked: [], muted: true, paused: false, tagged: {}, skippedN: 0 }; };
      const totag = (s, u) => { u.route = 'totag'; };
      return `<section class="card pal-opt pal-${k}" aria-labelledby="po-${k}"><div class="po-head"><div style="min-width:0"><h2 id="po-${k}" style="margin:0">${h.esc(v.name)}${k === 'graphite' ? ' <span class="pill ready" style="vertical-align:3px;background:var(--page-accent);color:var(--page-on-accent)">Chosen</span>' : ''}</h2><p class="muted" style="margin:4px 0 0">${h.esc(v.note)}</p></div><button class="pbtn" data-usepal="${k}" aria-pressed="false">${h.icon('palette')}<span>Use this colour</span></button></div>
        <div class="cswatches">${sw(v.light.primary, 'Primary')}${sw(v.light.primaryContainer, 'Container')}${sw(v.light.tertiaryContainer, 'Clips waiting')}${sw(v.light.surface, 'Surface')}<span class="cs-sep"></span>${sw(v.dark.primary, 'Primary (dark)')}${sw(v.dark.tertiaryContainer, 'Waiting (dark)')}${sw(v.dark.surface, 'Surface (dark)')}</div>
        <div class="pair mini">${[[home, 'light', 'Home · light'], [totag, 'dark', 'To tag · dark'], [player, 'light', 'Tag player']].map(([f, t, l]) => `<div class="frame-wrap"><span class="frame-tag">${l}</span>${mk(f, t)}</div>`).join('')}</div></section>`;
    }).join('');
    syncSwatches();
  }

  const ROLE_GROUPS = [
    ['Brand', ['primary', 'onPrimary', 'primaryContainer', 'onPrimaryContainer', 'secondaryContainer', 'onSecondaryContainer', 'tertiary', 'onTertiary', 'tertiaryContainer', 'onTertiaryContainer']],
    ['Surfaces', ['surface', 'onSurface', 'onSurfaceVariant', 'surfaceContainerLowest', 'surfaceContainerLow', 'surfaceContainer', 'surfaceContainerHigh', 'surfaceContainerHighest', 'outline', 'outlineVariant', 'inverseSurface', 'inverseOnSurface', 'inversePrimary']],
    ['Feedback', ['error', 'onError', 'errorContainer', 'onErrorContainer']],
  ];
  const onFor = { primary: 'onPrimary', primaryContainer: 'onPrimaryContainer', secondaryContainer: 'onSecondaryContainer', tertiary: 'onTertiary', tertiaryContainer: 'onTertiaryContainer', error: 'onError', errorContainer: 'onErrorContainer', inverseSurface: 'inverseOnSurface' };

  function renderSystem() {
    const P = window.RH_PALETTES[palette] || window.RH_PALETTES.violet;
    const T = { ...window.RH_TOKENS, color: { light: P.light, dark: P.dark }, palette: { ...window.RH_TOKENS.palette, ...P.palette } };
    const contrast = (a, b) => {
      const lum = (hex) => { const c = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255).map((v) => (v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4)); return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]; };
      const [x, y] = [lum(a), lum(b)].sort((m, n) => n - m); return (x + 0.05) / (y + 0.05);
    };
    const swatches = (theme) => ROLE_GROUPS.map(([g, roles]) => `<h3>${g}</h3><div class="sw-grid">${roles.map((r) => {
      const bg = T.color[theme][r];
      // "on" roles are shown in their base colour (onPrimary on… primary text), so the label stays readable
      const base = r === 'inverseOnSurface' ? 'inverseSurface' : r.startsWith('on') ? r[2].toLowerCase() + r.slice(3) : null;
      const fgRole = onFor[r] || (base && T.color[theme][base] ? base : r === 'outline' || r === 'inversePrimary' ? 'inverseSurface' : 'onSurface');
      const fg = T.color[theme][fgRole];
      const ratio = contrast(bg, fg);
      return `<div class="swatch"><div class="chip" style="background:${bg};color:${fg}">${r}</div><div class="meta"><code>${bg}</code><span>${ratio.toFixed(1)}:1</span></div></div>`;
    }).join('')}</div>`).join('');
    const ext = (theme) => `<h3>Extended (brand-only)</h3><div class="sw-grid">${Object.entries(T.extendedColor).map(([n, e]) => ['color', 'colorContainer'].map((k) => { const bg = e[theme][k]; const fg = e[theme][k === 'color' ? 'onColor' : 'onColorContainer']; return `<div class="swatch"><div class="chip" style="background:${bg};color:${fg}">${n}.${k}</div><div class="meta"><code>${bg}</code><span>${contrast(bg, fg).toFixed(1)}:1</span></div></div>`; }).join('')).join('')}</div>`;
    const tones = ['0', '10', '20', '30', '40', '50', '60', '70', '80', '90', '95', '98', '100'];
    const palettes = Object.entries(T.palette).map(([name, p]) => `<div><b style="font-size:13px">${name}</b><div class="tone-row">${tones.map((t) => p[t] ? `<div style="background:${p[t]};color:${+t > 55 ? '#000' : '#fff'}">${t}</div>` : '<div></div>').join('')}</div></div>`).join('');
    const type = Object.entries(T.typography.scale).map(([k, v]) => `<div class="type-row"><span class="lbl"><b>${k}</b><br>${v.fontSize} sp / ${v.lineHeight} sp · ${v.fontWeight}</span><span style="font:${v.fontWeight} ${v.fontSize}px/${v.lineHeight}px var(--font);letter-spacing:${v.letterSpacing}px;min-width:0">${k.startsWith('display') || k.startsWith('headline') ? 'London Food' : k.startsWith('title') ? '1:05–1:20 pm · 6 clips' : k.startsWith('label') ? 'Tag scene' : 'Tag clips into reels in spare moments.'}</span></div>`).join('');
    const space = Object.entries(T.spacing).filter(([, v]) => v).map(([k, v]) => `<div style="display:flex;align-items:center;gap:12px;font-size:13px"><code style="width:70px">space-${k}</code><span style="height:14px;width:${v * 2}px;background:var(--page-accent);border-radius:3px;display:inline-block"></span>${v} dp</div>`).join('');
    const shape = Object.entries(T.shape).filter(([k]) => k !== 'none').map(([k, v]) => `<div style="display:flex;flex-direction:column;align-items:center;gap:6px;font-size:12px"><span style="width:64px;height:64px;background:var(--page-accent-soft);border:1.5px solid var(--page-accent);border-radius:${Math.min(v, 32)}px"></span><b>${k}</b><span class="muted">${v === 999 ? 'full' : v + ' dp'}</span></div>`).join('');
    const elev = Object.entries(T.elevation).map(([k, v]) => `<div style="display:flex;flex-direction:column;align-items:center;gap:8px;font-size:12px"><span style="width:84px;height:56px;border-radius:12px;background:var(--page-card);box-shadow:${v.shadow}"></span><b>${k}</b><span class="muted">${v.dp} dp</span></div>`).join('');
    $('#sys-colors').innerHTML = `<div class="cards" style="grid-template-columns:repeat(auto-fit,minmax(min(100%,420px),1fr))"><div class="card"><h2 style="margin-top:0">Light</h2>${swatches('light')}${ext('light')}</div><div class="card"><h2 style="margin-top:0">Dark</h2>${swatches('dark')}${ext('dark')}</div></div>`;
    $('#sys-palettes').innerHTML = palettes;
    $('#sys-type').innerHTML = type;
    $('#sys-space').innerHTML = `<div style="display:grid;gap:8px">${space}</div>`;
    $('#sys-shape').innerHTML = `<div style="display:flex;flex-wrap:wrap;gap:20px">${shape}</div>`;
    $('#sys-elev').innerHTML = `<div style="display:flex;flex-wrap:wrap;gap:24px;padding:8px 0 16px">${elev}</div>`;
    renderComponents();
  }

  function renderComponents() {
    const s = RH.fixture();
    const r1 = q.reel(s, 'r1');
    const c = q.clipsOf(s, 'r2');
    const shared = c.find((x) => x.reels.length > 1);
    const hz = c.find((x) => x.orient === 'h');
    const miss = c.find((x) => x.missing);
    const plain = q.clipsOf(s, 'r1')[2];
    const scene = q.scenes(s, s.toTag)[2];
    const comps = [
      ['Reel card', 'Cover = oldest clip. Status pill, VN badge, missing count.', `<div class="reelgrid" style="padding:0;width:328px">${h.reelCard(r1, s)}${h.reelCard(q.reel(s, 'r3'), s)}${h.reelCard(q.reel(s, 'r4'), s)}${h.reelCard(q.reel(s, 'r2'), s)}</div>`],
      ['Clip tile', 'Plain · in 2 reels · horizontal · selected · missing · marked · loading.', `<div class="grid3" style="padding:0;width:328px">${h.tile(plain, s)}${h.tile(shared, s)}${h.tile(hz, s)}${h.tile(plain, s, { selecting: true, sel: true })}${h.tile(miss, s)}${h.tile(plain, s, { mark: { ic: 'sell', label: 'In To tag' }, hideMulti: true })}${h.skelTiles(3)}</div>`],
      ['Scene header', 'Time range, count, length, Tag scene.', `<div style="width:328px;margin:0 -16px">${h.sceneHeader(scene, s)}</div>`],
      ['Reel chips (tag player)', 'Default · picked (Pick several) · tagged confirm · new.', `<div class="rh-dark" style="background:var(--md-surface-container);padding:12px;border-radius:20px;width:328px"><div class="chipgrid">${h.reelChip(r1, s)}${h.reelChip(q.reel(s, 'r2'), s, { state: 'pick', multi: true })}${h.reelChip(q.reel(s, 'r4'), s, { state: 'done' })}<button class="rchip new"><span class="cv">${h.icon('add')}</span><span class="t"><b>New reel</b><span>Add this clip to it</span></span></button></div></div>`],
      ['Status pills', 'Icon + word, never colour alone.', `<div style="display:flex;gap:8px;flex-wrap:wrap">${h.statusPill('rec')}${h.statusPill('ready')}${h.statusPill('pub')}<span class="pill vn">${h.icon('folder_copy', 'fill')}Editing in VN</span></div>`],
      ['Shooting mode card', 'Off and on (with clips waiting).', (() => { const s2 = RH.fixture(); const off = RH.fixture(); off.shooting.on = false; return `<div style="width:360px;margin:0 -16px"><div>${RH.routes.home(off, RH.defaultUI()).html.match(/<section class="shoot[\s\S]*?<\/section>/)[0]}</div><div>${RH.routes.home(s2, RH.defaultUI()).html.match(/<section class="shoot on[\s\S]*?<\/section>/)[0]}</div></div>`; })()],
      ['Buttons', 'Filled · tonal · outlined · text · danger. 40 dp tall, 48 dp touch target.', `<div style="display:flex;gap:8px;flex-wrap:wrap">${h.btn({ label: 'Edit video', ic: 'movie_edit' })}${h.btn({ label: 'Tag scene', ic: 'sell', kind: 'tonal' })}${h.btn({ label: 'Import backup', kind: 'outlined' })}${h.btn({ label: 'Not now', kind: 'text' })}${h.btn({ label: 'Delete copies', kind: 'danger' })}${h.btn({ label: 'Start tagging', kind: 'filled', size: 'lg', ic: 'play_arrow' })}</div>`],
      ['Reference card', 'A designed card: TakeTray never fetches the video or its thumbnail. Source, label (or the link), Open, menu.', `<div style="width:328px;display:flex;flex-direction:column;gap:8px">${RH.refsOf(r1).map((x) => h.refCard(x, r1)).join('')}${h.refCard(RH.refsOf(q.reel(s, 'r2'))[0], q.reel(s, 'r2'))}</div>`],
      ['Snackbar', 'Inverse surface. Undo in inverse primary.', `<div style="position:relative;width:336px;height:64px">${h.snack({ text: 'Added to London Food', undo: true, ic: 'check_circle', bottom: 8 })}</div>`],
      ['Navigation bar', 'Reels · To tag (marigold count badge) · Settings.', `<div style="width:360px;margin:0 -16px">${h.navbar('totag', 23)}</div>`],
      ['Filter chips', 'Single-select with counts.', `<div class="chips" style="padding:0;width:328px"><button class="fchip on">${h.icon('check')}All <span class="cnt">7</span></button><button class="fchip">Recording <span class="cnt">3</span></button><button class="fchip">Ready to edit <span class="cnt">2</span></button></div>`],
      ['Banners', 'Clips waiting · Manual mode · access removed.', `<div style="width:360px;margin:0 -16px"><div class="banner attn">${h.icon('sell', 'fill')}<div class="grow"><b>23 clips to tag</b><span>9 min of video waiting</span></div>${h.icon('chevron_right')}</div><div class="banner info">${h.icon('lock')}<div class="grow"><b>Manual mode</b><span>New clips aren't found automatically.</span></div><button class="btn text">Allow full access</button></div><div class="banner warn">${h.icon('no_photography')}<div class="grow"><b>TakeTray can't see your videos</b><span>Allow access to find new clips.</span></div><button class="btn text">Allow</button></div></div>`],
    ];
    $('#sys-comps').innerHTML = comps.map(([n, d, html]) => `<div class="card"><h3 style="margin-top:0">${n}</h3><p class="muted" style="margin:0 0 12px;font-size:13.5px">${d}</p><div style="display:flex;flex-wrap:wrap;gap:16px">${['light', 'dark'].map((t) => `<div class="rh-${t} comp" inert style="background:var(--md-surface);color:var(--md-on-surface);font:var(--type-body-medium);padding:16px;border-radius:18px;max-width:100%;overflow:hidden;font-feature-settings:'tnum' 1">${html}</div>`).join('')}</div></div>`).join('');
  }

  function renderNavmap() {
    const N = {
      n30: [0, 0, 30, 'New clips notification'], n31: [0, 1, 31, 'Evening reminder'],
      splash: [0, 3, 1, 'Splash'], welcome: [0, 4, 2, 'Welcome'], video: [0, 5, 3, 'Video access'], notif: [0, 6, 4, 'Notifications'], create: [0, 7, 5, 'Create your reels'],
      perm: [0, 9, 29, 'Permission problem'], n32: [0, 11, 32, 'VN copies reminder'], n33: [0, 12, 33, 'Still shooting?'], share: [0, 13.4, null, 'Share from Instagram', 'sheet'],
      saveref: [1, 13.4, 35, 'Save reference', 'sheet'], refsheet: [2, 7.6, 37, 'References sheet', 'sheet'], addref: [3, 9.2, 36, 'Add / edit reference', 'sheet'],
      totag: [1, 1, 11, 'To tag', 'tab'], home: [1, 5, 6, 'Reels (Home)', 'tab'], settings: [1, 10, 24, 'Settings', 'tab'],
      player: [2, 0, 12, 'Tag player'], picker: [2, 1, 13, 'Reel picker', 'sheet'], skipall: [2, 2, 14, 'Skip all', 'sheet'], skipped: [2, 3, 15, 'Skipped'],
      camera: [2, 4.2, null, 'Phone camera (system)', 'sheet'], form: [2, 5.2, 7, 'Create / edit reel', 'sheet'], reel: [2, 6.4, 8, 'Reel detail'],
      watched: [2, 9, 25, 'Watched folders'], vnst: [2, 10, 26, 'VN copies storage'], help: [2, 11, 27, 'Notifications help'], backup: [2, 12, 28, 'Export / import'],
      evsheet: [3, 1, 38, 'Add earlier videos', 'sheet'], evpick: [4, 0.5, 39, 'Date range picker'], evres: [4, 1.6, 40, 'Found / no new videos', 'sheet'],
      add: [3, 3, 17, 'Add videos'], viewer: [3, 5, 16, 'Clip viewer'], status: [3, 6, 10, 'Status menu', 'sheet'], del: [3, 7, 9, 'Delete reel', 'sheet'], edit: [3, 8, 18, 'Pick clips to edit'],
      editor: [4, 8, 19, 'Choose editor', 'sheet'], space: [4, 9, 20, 'VN space check'], copy: [4, 10, 21, 'VN copying'], ready: [4, 11, 22, 'VN ready'], done: [4, 6.6, 23, 'Done editing', 'sheet'],
    };
    const E = [['share', 'saveref'], ['saveref', 'reel'], ['home', 'refsheet'], ['refsheet', 'reel'], ['reel', 'addref'], ['n30', 'totag'], ['n31', 'totag'], ['splash', 'welcome'], ['welcome', 'video'], ['video', 'notif'], ['notif', 'create'], ['create', 'home'], ['perm', 'home'], ['n32', 'reel'], ['n33', 'home'],
      ['totag', 'player'], ['totag', 'picker'], ['totag', 'skipall'], ['totag', 'skipped'], ['totag', 'add'], ['home', 'camera'], ['home', 'form'], ['home', 'reel'], ['home', 'totag'],
      ['reel', 'viewer'], ['reel', 'status'], ['reel', 'del'], ['reel', 'edit'], ['reel', 'add'], ['reel', 'done'], ['edit', 'editor'], ['editor', 'space'], ['space', 'copy'], ['copy', 'ready'],
      ['settings', 'watched'], ['settings', 'vnst'], ['settings', 'help'], ['settings', 'backup'], ['vnst', 'done'], ['player', 'picker'],
      ['totag', 'evsheet'], ['home', 'evsheet'], ['evsheet', 'evpick'], ['evpick', 'evres']];
    const W = 178, H = 38, CX = 214, RY = 52, X0 = 10, Y0 = 34;
    const pos = (k) => { const [c, r] = N[k]; return { x: X0 + c * CX, y: Y0 + r * RY }; };
    const edges = E.map(([a, b]) => {
      const p = pos(a), t = pos(b);
      let x1 = p.x + W, y1 = p.y + H / 2, x2 = t.x, y2 = t.y + H / 2;
      if (N[a][0] === N[b][0]) { // same column: straight down the stack
        x1 = x2 = p.x + 24; y1 = p.y + (t.y > p.y ? H : 0); y2 = t.y + (t.y > p.y ? 0 : H);
        return `<path class="nm-edge" d="M${x1} ${y1} L${x2} ${y2}" marker-end="url(#ar)"/>`;
      }
      if (x2 < x1) { x1 = p.x; x2 = t.x + W; }
      const mx = (x1 + x2) / 2;
      return `<path class="nm-edge" d="M${x1} ${y1} C${mx} ${y1} ${mx} ${y2} ${x2} ${y2}" marker-end="url(#ar)"/>`;
    }).join('');
    const nodes = Object.entries(N).map(([k, [c, r, n, label, kind]]) => {
      const { x, y } = pos(k);
      const inner = `<rect x="${x}" y="${y}" width="${W}" height="${H}" rx="10"/>${n ? `<text class="num" x="${x + 10}" y="${y + 23}">${String(n).padStart(2, '0')}</text>` : ''}<text x="${x + (n ? 32 : 12)}" y="${y + 23}">${label}</text>`;
      return n ? `<a href="#screen-${String(n).padStart(2, '0')}" class="nm-node ${kind || ''}">${inner}</a>` : `<g class="nm-node ${kind || ''}">${inner}</g>`;
    }).join('');
    const cols = ['Entry points', 'Tabs', 'Screens', 'Details', 'Editing'].map((t, i) => `<text class="nm-col" x="${X0 + i * CX}" y="18">${t.toUpperCase()}</text>`).join('');
    $('#navmap-svg').innerHTML = `<svg width="${X0 + 5 * CX}" height="${Y0 + 14.4 * RY + 10}" viewBox="0 0 ${X0 + 5 * CX} ${Y0 + 14.4 * RY + 10}" role="img" aria-label="Navigation map of all ${RH.SCREENS.length} screens"><defs><marker id="ar" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="7" markerHeight="7" orient="auto"><path d="M0 0L8 4L0 8z" style="fill:var(--page-muted)"/></marker></defs>${cols}${edges}${nodes}</svg>`;
  }

  /* ================================================================== */
  /* Interactive prototype                                               */
  /* ================================================================== */
  const FLOWS = {
    tagging: { label: "Tag a day's clips", steps: ['On To tag, tap Start tagging (or Tag scene on a group).', 'Tap a reel to tag the clip. It moves to the next clip by itself.', 'Try Pick several, Same as previous, Skip, and Undo on the snackbar.', 'Tag them all to reach "All done!".'] },
    vn: { label: 'Send a reel to VN', steps: ['On London Food, tap Edit video.', 'Pick some clips (or Select all), then Continue.', 'Choose VN, check the space, and tap Copy.', 'Read the steps, tap Done. The reel now shows "Editing in VN".', 'Tap Done editing, delete the copies, and mark it as Published.'] },
    onboarding: { label: 'First launch (onboarding)', steps: ['Get started, then Allow access. Try "Select photos and videos" to see Manual mode.', 'Allow notifications or tap Not now.', 'Add a few reels (press Enter after each), then Create.', 'Home shows a tip pointing at Shooting mode.'] },
    reference: { label: 'Save a reference from Instagram', steps: ['You start in Instagram (shown as a plain video app). Tap Share.', "In Android's share menu, pick TakeTray.", 'Choose an existing reel (or New reel), add an optional label, and Save.', 'Done returns to Instagram; Open reel shows the References section.', 'Try other shared content in the panel: a post, a YouTube Short, a duplicate, or plain text.'] },
    'reference-first': { label: 'Save a reference on first launch', steps: ['TakeTray is freshly installed and never opened. Share a reel to it from Instagram.', 'There are no reels yet, so the sheet asks for a new reel name. Save.', 'Done returns to Instagram. Open reel runs onboarding first.', 'In "Create your reels" the new reel is already listed, then you land on it.'] },
    earlier: { label: 'Add earlier videos', steps: ['On Reels, the Shooting mode card has an Add earlier videos row (it is also in To tag\'s ⋮ menu).', 'Today adds this morning\'s 3 videos at once. Or tap Choose dates….', 'Tap the first day, then the last (try 8 to 10 Oct, or 10 to 11 Oct for "No new videos"). Try the month name, the arrows and the quick ranges.', 'Find videos counts them; Add puts them in To tag. Undo on the snack takes them back.'] },
    explore: { label: 'Free explore', steps: ['Everything works: reels, To tag, settings, the camera, notifications.', 'Use the simulator buttons to shoot clips or jump in time.'] },
  };

  const App = (RH.App = {
    s: null, u: null, hist: [], theme: store.get('protoTheme', 'dark'), flow: 'tagging', undo: null, timers: {}, suppress: false, mounted: false, rm: false,

    mount() {
      if (!this.mounted) {
        this.mounted = true;
        this.phone = $('#proto-phone');
        this.bind();
        this.load(this.flow);
      }
      this.syncPanel();
      this.render();
    },

    load(flow, preset) {
      Object.values(this.timers).forEach(clearTimeout);
      this.timers = {};
      this.flow = flow;
      this.hist = [];
      this.undo = null;
      if (preset) { this.s = preset.s; this.u = preset.u; this.u.snack = null; }
      else {
        this.s = RH.fixture();
        this.u = RH.defaultUI();
        if (flow === 'tagging') this.u.route = 'totag';
        if (flow === 'vn') { this.u.route = 'reel'; this.u.p = { id: 'r1' }; this.hist = [{ route: 'home', p: {} }]; }
        if (flow === 'reference' || flow === 'reference-first') {
          this.u.route = 'ext-app';
          if (flow === 'reference-first') {
            const s = this.s;
            s.reels = []; s.toTag = []; s.skipped = []; s.onboarded = false; s.shooting.on = false; s.access = 'none'; s.notifPerm = false;
            Object.values(s.clips).forEach((c) => { c.reels = []; });
          }
        }
        if (flow === 'onboarding') {
          const s = this.s;
          s.reels = []; s.toTag = []; s.skipped = []; s.onboarded = false; s.shooting.on = false; s.access = 'none'; s.notifPerm = false;
          Object.values(s.clips).forEach((c) => { c.reels = []; });
          this.u.route = 'splash';
          this.timers.splash = setTimeout(() => { if (this.u.route === 'splash') this.nav('ob-welcome', {}, true); }, 1100);
        }
      }
      this.syncPanel();
      this.render();
    },

    syncPanel() {
      const sel = (id, v) => { const el = $(id); if (el) el.value = v; };
      sel('#pf-flow', this.flow);
      sel('#pf-welcome', RH.welcomeChoice);
      sel('#pf-share', this.shareKey || 'reel');
      sel('#pf-android', String(this.s ? this.s.android : 14));
      sel('#pf-access', this.s ? (this.s.access === 'none' ? 'full' : this.s.access === 'denied' ? 'limited' : this.s.access) : 'full');
      document.querySelectorAll('[data-ptheme]').forEach((b) => b.setAttribute('aria-pressed', b.dataset.ptheme === this.theme));
      const f = FLOWS[this.flow];
      $('#pf-steps').innerHTML = f.steps.map((x) => `<li>${h.esc(x)}</li>`).join('');
      $('#pf-title').textContent = f.label;
    },

    log(msg) { const el = $('#pf-log'); if (el) el.textContent = msg; },

    render() {
      if (!this.phone) return;
      const scrollEl = this.phone.querySelector('.scroll[data-scroll]');
      const key = scrollEl && scrollEl.dataset.scroll;
      const top = scrollEl ? scrollEl.scrollTop : 0;
      const out = RH.renderPhone(this.s, this.u);
      this.phone.className = `ph rh-${this.theme} ${out.video ? 'video' : ''} ${this.rm ? 'rm' : ''}`;
      this.phone.style.background = out.video ? '#000' : '';
      this.phone.innerHTML = out.html;
      const ns = this.phone.querySelector('.scroll[data-scroll]');
      if (ns && key && ns.dataset.scroll === key) ns.scrollTop = top;
      if (this.u.sheet) this.u.sheet.fresh = false;
      if (this.u.snack) this.u.snack.fresh = false;
      this.u.anim = null;
      if (this.u.p && this.u.p.focus === 'refs') {
        const sec = this.phone.querySelector('#refs-sec');
        if (sec && ns) ns.scrollTop = Math.max(0, sec.offsetTop - 8);
        this.timers.flash = setTimeout(() => { if (this.u.p) delete this.u.p.focus; }, 50);
      }
      if (this.u.focus) { const el = this.phone.querySelector('#' + this.u.focus); if (el) { el.focus({ preventScroll: true }); if (el.setSelectionRange) el.setSelectionRange(el.value.length, el.value.length); } this.u.focus = null; }
    },

    /* navigation -------------------------------------------------------- */
    nav(route, p = {}, replace) {
      if (!replace) this.hist.push({ route: this.u.route, p: this.u.p });
      Object.assign(this.u, { route, p, sel: null, menu: null, sheet: null, dialog: null, kbd: false, snack: route === 'player' ? null : this.u.snack });
      this.render();
    },
    back() {
      const u = this.u;
      if (u.shade) { u.shade = null; return this.render(); }
      if (u.sys) { u.sys = null; return this.render(); }
      if (u.menu) { u.menu = null; return this.render(); }
      if (u.dialog) { u.dialog = null; return this.render(); }
      if (u.sheet) { u.sheet = null; u.kbd = false; return this.render(); }
      if (u.sel) { u.sel = null; return this.render(); }
      if (u.route === 'vn-copy') return this.act('stopCopy', {});
      const prev = this.hist.pop();
      if (!prev) { this.log('Back on a top-level screen leaves the app.'); return; }
      Object.assign(u, { route: prev.route, p: prev.p, sel: null, kbd: false });
      if (prev.route === 'add-grid') u.sel = { ctx: 'add', ids: [] };
      this.render();
    },
    tab(t) {
      this.hist = [];
      Object.assign(this.u, { route: t, p: {}, sel: null, menu: null, sheet: null, dialog: null, kbd: false, player: null, hint: null });
      this.render();
    },
    snack(text, opts = {}) {
      clearTimeout(this.timers.snack);
      this.u.snack = { text, fresh: true, ...opts };
      if (!opts.undo) this.undo = null;
      this.timers.snack = setTimeout(() => { this.u.snack = null; this.undo = null; this.render(); }, opts.ms || (opts.undo ? 6000 : 4000));
    },
    snapshot() { this.undo = { s: clone(this.s), player: this.u.player ? clone(this.u.player) : null, route: this.u.route, p: clone(this.u.p) }; },

    /* data helpers ------------------------------------------------------- */
    tagInto(ids, reelIds) {
      ids.forEach((id) => { const c = this.s.clips[id]; reelIds.forEach((r) => { if (!c.reels.includes(r)) c.reels.push(r); }); });
      this.s.toTag = this.s.toTag.filter((id) => !ids.includes(id));
    },
    removeFromReel(ids, rid) {
      ids.forEach((id) => {
        const c = this.s.clips[id];
        if (!c) return;
        c.reels = c.reels.filter((r) => r !== rid);
        if (!c.reels.length) delete this.s.clips[id]; // leaves the app; the video stays in the gallery
      });
      const reel = q.reel(this.s, rid);
      if (reel && reel.vn) reel.vn.copied = reel.vn.copied.filter((id) => this.s.clips[id]);
    },
    sortToTag() { this.s.toTag.sort((a, b) => (this.s.clips[a].at < this.s.clips[b].at ? -1 : 1)); },
    newReel(name) {
      const id = 'n' + Date.now().toString(36);
      this.s.reels.push({ id, name, status: 'rec', created: RH.TODAY, desc: '', vn: null, refs: [] });
      return id;
    },
    validName(name, exceptId) {
      const n = (name || '').trim();
      if (!n) return 'Give this reel a name';
      if (n.length > 40) return 'Use 40 characters or fewer';
      const dup = this.s.reels.find((r) => r.id !== exceptId && r.name.toLowerCase() === n.toLowerCase());
      return dup ? `You already have a reel called ${dup.name}` : null;
    },
    shootClips(n) {
      const s = this.s;
      if (!s.shooting.on) return this.log(`Shot ${n} clips with Shooting mode off: they were ignored, as designed.`);
      const themes = ['street', 'food', 'river', 'selfie', 'market', 'sunset', 'night', 'park'];
      // New clips are shot "now": after the phone clock (7:24 pm) and after any clip already shot.
      const base = [s.lastShot, s.shooting.since, RH.TODAY + 'T19:24:00'].filter(Boolean).sort().pop();
      const start = RH.addSec(base, 60 * 2);
      const ids = RH.run(s, { start, themes: themes.sort(() => Math.random() - 0.5), count: n, spanMin: 4, seed: Math.floor(Math.random() * 999) });
      if (s.access !== 'full') { ids.forEach((id) => { delete s.clips[id]; }); return this.log('Manual mode: new clips are not detected automatically. Use Add videos in To tag.'); }
      s.lastShot = s.clips[ids[ids.length - 1]].at;
      s.toTag.push(...ids);
      this.sortToTag();
      this.log(`${n} new clips landed in To tag. The notification updated silently.`);
      return ids.length;
    },

    /* player helpers ----------------------------------------------------- */
    playerStart(fromId) {
      const session = this.s.toTag.slice();
      this.u.player = { session, i: Math.max(0, session.indexOf(fromId)), multi: false, picked: [], muted: true, paused: false, tagged: {}, skippedN: 0 };
      this.nav('player', {});
    },
    findNext(P, from, dir = 1) {
      for (let j = from + dir; j >= 0 && j < P.session.length; j += dir) if (this.s.toTag.includes(P.session[j])) return j;
      return -1;
    },
    advance() {
      const P = this.u.player;
      let j = this.findNext(P, P.i, 1);
      if (j < 0) j = this.findNext(P, -1, 1);
      if (j < 0) { P.done = true; this.u.snack = null; }
      else { P.i = j; this.u.anim = 'adv'; }
      P.multi = false; P.picked = []; P.confirm = null; P.paused = false;
    },
    tagCurrent(reelIds, message) {
      const P = this.u.player;
      const id = P.session[P.i];
      this.snapshot();
      this.undo.player.confirm = null; // the snapshot was taken mid-confirmation
      this.undo.player.multi = false;
      this.undo.player.picked = [];
      this.tagInto([id], reelIds);
      this.s.lastTags = reelIds.slice();
      reelIds.forEach((r) => { P.tagged[r] = (P.tagged[r] || 0) + 1; });
      this.advance();
      if (!P.done) this.snack(message || `Added to ${reelIds.map((r) => q.reel(this.s, r).name).join(', ')}`, { undo: true, ic: 'check_circle' });
      this.render();
    },

    /* events ------------------------------------------------------------- */
    bind() {
      const ph = this.phone;
      ph.addEventListener('click', (e) => {
        if (this.suppress) { this.suppress = false; e.preventDefault(); return; }
        const el = e.target.closest('[data-a]');
        if (!el || !ph.contains(el)) return;
        if (el.getAttribute('aria-disabled') === 'true' || el.disabled) return;
        e.preventDefault();
        this.act(el.dataset.a, { ...el.dataset }, el);
      });
      let lpTimer = null, start = null;
      const cancel = () => { clearTimeout(lpTimer); lpTimer = null; };
      ph.addEventListener('pointerdown', (e) => {
        const el = e.target.closest('[data-lp]');
        if (!el) return;
        start = { x: e.clientX, y: e.clientY };
        lpTimer = setTimeout(() => { this.suppress = true; if (navigator.vibrate) navigator.vibrate(20); this.act(el.dataset.lp, { ...el.dataset }, el); }, 450);
      });
      ph.addEventListener('pointermove', (e) => { if (start && lpTimer && Math.hypot(e.clientX - start.x, e.clientY - start.y) > 10) cancel(); });
      ['pointerup', 'pointerleave', 'pointercancel'].forEach((t) => ph.addEventListener(t, cancel));
      ph.addEventListener('contextmenu', (e) => { const el = e.target.closest('[data-lp]'); if (!el) return; e.preventDefault(); cancel(); this.act(el.dataset.lp, { ...el.dataset }, el); });
      ph.addEventListener('input', (e) => {
        const k = e.target.dataset.in;
        if (!k) return;
        const v = e.target.value;
        if (k === 'obDraft') this.u.p.draft = v;
        if (k === 'formName') { this.u.sheet.name = v; const c = ph.querySelector('[data-counter="rname"]'); if (c) c.textContent = `${v.length}/40`; }
        if (k === 'formDesc') this.u.sheet.desc = v;
        if (k === 'pickerName') this.u.sheet.newName = v;
        if (RH.INPUTS && RH.INPUTS[k]) RH.INPUTS[k](this, v);
      });
      ph.addEventListener('focusin', (e) => { if (e.target.matches('input,textarea') && !this.u.kbd) { this.u.kbd = true; if (e.target.id) this.u.focus = e.target.id; this.render(); } });
      ph.addEventListener('keydown', (e) => {
        if (e.key !== 'Enter' || !e.target.dataset || e.target.tagName === 'TEXTAREA') return;
        const k = e.target.dataset.in;
        if (k === 'obDraft') { e.preventDefault(); this.act('obAddName', {}); }
        if (k === 'formName') { e.preventDefault(); this.act('formSave', {}); }
        if (k === 'pickerName') { e.preventDefault(); this.act('pickerCreate', {}); }
        if (RH.ENTER && RH.ENTER[k]) { e.preventDefault(); this.act(RH.ENTER[k], {}); }
      });
      // swipe between clips in player / viewer
      let sx = null;
      ph.addEventListener('touchstart', (e) => { const st = e.target.closest('.stage, .vstage, .viewer'); sx = st ? e.touches[0].clientX : null; }, { passive: true });
      ph.addEventListener('touchend', (e) => {
        if (sx == null) return;
        const dx = e.changedTouches[0].clientX - sx; sx = null;
        if (Math.abs(dx) < 60) return;
        if (this.u.route === 'player') this.act(dx < 0 ? 'nextClip' : 'prevClip', {});
        if (this.u.route === 'viewer') this.act(dx < 0 ? 'viewerNext' : 'viewerPrev', {});
      });
      document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && !$('#v-prototype').hidden) this.back(); });
    },

    act(a, d, el) {
      const fn = ACTIONS[a];
      if (fn) fn.call(this, d, el);
      else this.log(`"${a}" is outside the prototype.`);
    },
  });

  /* ================================================================== */
  /* Actions                                                             */
  /* ================================================================== */
  const ACTIONS = (RH.ACTIONS = {
    noop() { this.log('Not wired in the prototype.'); },
    tab(d) { this.tab(d.tab); },
    go(d) { this.nav(d.r, {}); },
    back() { this.back(); },
    closeMenu() { this.u.menu = null; this.render(); },
    closeSheet() { this.u.sheet = null; this.u.kbd = false; this.render(); },
    closeDialog() {
      const t = this.u.dialog && this.u.dialog.type;
      this.u.dialog = null;
      if (t === 'stopCopy') this.copyTick();
      this.render();
    },
    closeShade() { this.u.shade = null; this.render(); },
    dismissHint() { this.u.hint = null; this.render(); },
    undo() {
      if (!this.undo) return;
      const un = this.undo;
      this.s = un.s;
      if (un.player && this.u.route === 'player') { this.u.player = un.player; this.u.anim = 'back'; }
      if (un.route !== this.u.route && un.route === 'reel' && !q.reel(this.s, this.u.p.id)) { /* keep route */ }
      if (un.restoreRoute) { this.u.route = un.route; this.u.p = un.p; }
      this.undo = null;
      clearTimeout(this.timers.snack);
      this.u.snack = { text: 'Undone', fresh: true };
      this.timers.snack = setTimeout(() => { this.u.snack = null; this.render(); }, 2000);
      this.render();
    },

    /* onboarding */
    obNext(d) { this.nav(d.to, d.to === 'ob-reels' ? { names: [] } : {}); },
    askVideo() { this.u.sys = { type: 'video' }; this.render(); },
    askNotif() {
      if (this.s.android < 13) { this.s.notifPerm = true; if (this.u.route === 'ob-notif') return this.nav('ob-reels', { names: [] }); this.log('Android 11–12: notifications are on by default.'); return this.render(); }
      this.u.sys = { type: 'notif' }; this.render();
    },
    sysAllowAll() {
      this.s.access = 'full'; this.u.sys = null;
      if (this.u.route === 'ob-video') { this.u.p = { state: 'granted' }; this.render(); this.timers.ob = setTimeout(() => { if (this.u.route === 'ob-video') this.nav(this.s.android >= 13 ? 'ob-notif' : 'ob-reels', { names: [] }); }, 1200); return; }
      if (this.u.route === 'perm-lost') return this.tab('home');
      this.snack('Full access allowed. New clips will be found automatically.'); this.render();
    },
    sysLimited() { this.s.access = 'limited'; this.u.sys = null; if (this.u.route === 'ob-video') this.u.p = { state: 'limited' }; else this.snack('Still Manual mode: only some videos allowed.'); this.render(); },
    sysDeny() { this.s.access = 'denied'; this.u.sys = null; if (this.u.route === 'ob-video') this.u.p = { state: 'denied' }; this.render(); },
    sysNotifAllow() { this.s.notifPerm = true; this.u.sys = null; if (this.u.route === 'ob-notif') return this.nav('ob-reels', { names: [] }); this.render(); },
    sysNotifDeny() { this.s.notifPerm = false; this.u.sys = null; if (this.u.route === 'ob-notif') return this.nav('ob-reels', { names: [] }); this.render(); },
    obManual() { if (this.s.access === 'none') this.s.access = 'limited'; this.nav(this.s.android >= 13 ? 'ob-notif' : 'ob-reels', { names: [] }); },
    obManualHome() { this.s.access = 'limited'; this.tab('home'); },
    openSettingsApp() { this.log('Opens Android settings (outside the prototype).'); this.snack('Opens Android settings'); this.render(); },
    obAddName() {
      const v = (this.u.p.draft || '').trim();
      if (!v) return;
      const names = this.u.p.names || (this.u.p.names = []);
      if (!names.some((n) => n.toLowerCase() === v.toLowerCase())) names.push(v.slice(0, 40));
      this.u.p.draft = ''; this.u.kbd = true; this.u.focus = 'obname'; this.render();
    },
    obIdea(d) { (this.u.p.names = this.u.p.names || []).push(d.name); this.render(); },
    obRemoveName(d) { this.u.p.names.splice(+d.i, 1); this.render(); },
    obCreate() {
      const names = this.u.p.names || [];
      names.forEach((n) => this.newReel(n));
      this.s.onboarded = true; if (this.s.access === 'none') this.s.access = 'limited';
      this.s.reels.forEach((r) => { delete r.pre; });
      if (this.finishOnboarding()) return;
      this.tab('home'); this.u.hint = 'shoot';
      this.snack(`${fmt.n(names.length, 'reel')} created`); this.render();
    },
    obFinish() { this.s.onboarded = true; if (this.s.access === 'none') this.s.access = 'limited'; this.s.reels.forEach((r) => { delete r.pre; }); if (this.finishOnboarding()) return; this.tab('home'); this.u.hint = 'shoot'; this.render(); },

    /* home & shooting */
    filter(d) { this.u.filter = d.f; this.render(); },
    newReel() { this.u.sheet = { type: 'reelForm', mode: 'new', name: '', fresh: true }; this.u.kbd = true; this.u.focus = 'rname'; this.render(); },
    openReel(d) { this.nav('reel', { id: d.id }); },
    toggleShoot() {
      const sh = this.s.shooting;
      sh.on = !sh.on;
      this.u.hint = null;
      if (sh.on) { sh.since = RH.TODAY + 'T19:24:00'; this.snack('Shooting mode on. Film with your camera as usual.', { ic: 'videocam' }); }
      else this.snack("Shooting mode off. New videos won't be added.");
      this.render();
    },
    openCamera() { this.nav('camera', { count: 0, scene: { theme: 'street', seed: 70 } }); },
    closeCamera() { this.back(); },
    camShutter() {
      const p = this.u.p;
      if (!p.rec) { p.rec = true; p.tick = 1; this.render(); this.timers.cam = setInterval(() => { p.tick++; this.render(); }, 1000); return; }
      clearInterval(this.timers.cam);
      p.rec = false;
      const added = this.shootClips(1);
      if (added) p.count = (p.count || 0) + 1;
      p.scene = { theme: ['food', 'river', 'market', 'sunset', 'park', 'night'][Math.floor(Math.random() * 6)], seed: Math.floor(Math.random() * 500) };
      this.render();
    },
    allowAccess() { this.u.sheet = null; this.u.sys = { type: 'video' }; this.render(); },

    /* menus */
    menu(d) { this.u.menu = { type: d.m, id: d.id || this.u.p.id, top: 140 }; this.render(); },
    setStatus(d) { const r = q.reel(this.s, this.u.menu.id); r.status = d.st; this.u.menu = null; this.snack(`Marked as ${h.STATUS[d.st].label}`); this.render(); },
    editDetails() { const r = q.reel(this.s, this.u.p.id); this.u.menu = null; this.u.sheet = { type: 'reelForm', mode: 'edit', id: r.id, name: r.name, desc: r.desc, status: r.status, fresh: true }; this.render(); },
    askDelete() { this.u.menu = null; this.u.dialog = { type: 'deleteReel', id: this.u.p.id }; this.render(); },
    confirmDelete() {
      const r = q.reel(this.s, this.u.dialog.id);
      this.snapshot(); this.undo.restoreRoute = true;
      const ids = q.clipsOf(this.s, r.id).map((c) => c.id);
      this.removeFromReel(ids, r.id);
      this.s.reels = this.s.reels.filter((x) => x.id !== r.id);
      this.u.dialog = null;
      this.tab('home');
      this.snack(`${r.name} deleted`, { undo: true }); this.render();
    },
    startSelBtn(d) { this.u.menu = null; this.u.sel = { ctx: d.ctx, ids: [] }; this.render(); },
    selAll() { this.u.menu = null; this.u.sel.ids = q.clipsOf(this.s, this.u.p.id).filter((c) => !c.missing).map((c) => c.id); this.render(); },
    share(d) { this.u.menu = null; this.u.sheet = { type: 'share', n: +(d.n || (this.u.sel ? this.u.sel.ids.length : 1)) || 1, fresh: true }; this.render(); },

    /* reel form */
    formStatus(d) { this.u.sheet.status = d.st; this.render(); },
    formSave() {
      const f = this.u.sheet;
      const err = this.validName(f.name, f.mode === 'edit' ? f.id : null);
      if (err) { f.err = err; this.u.focus = 'rname'; return this.render(); }
      const refUrl = f.ref && f.ref.trim() ? RH.findUrl(f.ref) : null;
      if (f.ref && f.ref.trim() && !refUrl) { f.refErr = "That isn't a link. Leave it empty, or paste a reel's link."; this.u.focus = 'rref'; return this.render(); }
      const addRefTo = (rid) => { if (refUrl && !RH.refsOf(q.reel(this.s, rid)).some((x) => RH.normLink(x.url) === RH.normLink(refUrl))) RH.refsOf(q.reel(this.s, rid)).push({ id: 'refF' + Date.now().toString(36), url: refUrl, label: '', added: RH.TODAY }); };
      const name = f.name.trim();
      if (f.mode === 'edit') {
        Object.assign(q.reel(this.s, f.id), { name, desc: f.desc || '', status: f.status });
        addRefTo(f.id);
        this.u.sheet = null; this.u.kbd = false; this.snack('Saved'); return this.render();
      }
      const id = this.newReel(name);
      q.reel(this.s, id).desc = f.desc || '';
      addRefTo(id);
      this.u.sheet = null; this.u.kbd = false;
      if (f.from === 'player') return this.tagCurrent([id], `Added to ${name}`);
      this.snack(`${name} created`); this.render();
    },

    /* reel detail */
    toggleDesc() { this.u.p.descOpen = !this.u.p.descOpen; this.render(); },
    openClip(d) {
      const list = q.liveClipsOf(this.s, this.u.p.id).map((c) => c.id);
      this.nav('viewer', { reel: this.u.p.id, id: d.id, list });
    },
    startSel(d) { this.u.sel = { ctx: d.ctx, ids: [d.id] }; this.render(); },
    toggleSel(d) {
      const sel = this.u.sel || (this.u.sel = { ctx: d.ctx, ids: [] });
      const i = sel.ids.indexOf(d.id);
      if (i >= 0) sel.ids.splice(i, 1); else sel.ids.push(d.id);
      if (!sel.ids.length && (sel.ctx === 'totag' || sel.ctx === 'reel')) this.u.sel = null;
      this.render();
    },
    clearSel() { this.u.sel = null; this.render(); },
    selAddTo() { if (!this.u.sel.ids.length) return; this.u.sheet = { type: 'picker', mode: 'add', ids: this.u.sel.ids.slice(), exclude: this.u.p.id, picked: [], fresh: true }; this.render(); },
    selMove() { if (!this.u.sel.ids.length) return; this.u.sheet = { type: 'picker', mode: 'move', ids: this.u.sel.ids.slice(), exclude: this.u.p.id, picked: [], fresh: true }; this.render(); },
    selRemove() {
      const ids = this.u.sel.ids.slice();
      if (!ids.length) return;
      const r = q.reel(this.s, this.u.p.id);
      this.snapshot();
      this.removeFromReel(ids, r.id);
      this.u.sel = null;
      this.snack(`${fmt.n(ids.length, 'clip')} removed from ${r.name}. The videos are still in your gallery.`, { undo: true }); this.render();
    },
    removeMissing(d) {
      const r = q.reel(this.s, this.u.p.id);
      this.snapshot();
      this.removeFromReel([d.id], r.id);
      this.snack('Missing clip removed', { undo: true }); this.render();
    },
    editVideo() { this.nav('edit-select', { id: this.u.p.id }); this.u.sel = { ctx: 'edit', ids: [] }; this.render(); },
    selEdit() { const ids = this.u.sel.ids.slice(); const id = this.u.p.id; this.u.menu = null; this.nav('edit-select', { id }); this.u.sel = { ctx: 'edit', ids }; this.render(); },
    addVideos(d) {
      if (this.s.access !== 'full') { this.u.sheet = { type: 'manualPick', fresh: true }; return this.render(); }
      this.nav('add-folders', { target: d.kind === 'reel' ? { kind: 'reel', id: d.id } : { kind: 'totag' } });
    },
    doneEditing(d) { this.u.dialog = { type: 'doneEditing', id: d.id, from: d.from }; this.render(); },
    confirmDoneEditing() {
      const r = q.reel(this.s, this.u.dialog.id);
      const mb = q.vnMB(this.s, r);
      r.vn = null;
      this.u.dialog = null;
      this.snack(`Copies deleted · ${fmt.size(mb)} freed`, { ic: 'check_circle' });
      this.render();
      if (r.status !== 'pub') this.timers.mark = setTimeout(() => { this.u.dialog = { type: 'markStatus', id: r.id, status: 'pub' }; this.render(); }, 900);
    },
    confirmStatus() { const d = this.u.dialog; q.reel(this.s, d.id).status = d.status; this.u.dialog = null; this.snack(`Marked as ${h.STATUS[d.status].label}`); this.render(); },
    vnAddMore(d) { const r = q.reel(this.s, d.id); this.nav('edit-select', { id: d.id, vnAdd: true }); this.u.sel = { ctx: 'edit', ids: r.vn.copied.slice() }; this.render(); },

    /* to tag */
    playFrom(d) { this.playerStart(d.id); },
    startTagging() { this.playerStart(this.s.toTag[0]); },
    tagScene(d) { this.u.sheet = { type: 'picker', mode: 'tag', ids: d.ids.split(','), picked: [], fresh: true }; this.render(); },
    selScene(d) {
      const ids = d.ids.split(',');
      const sel = this.u.sel;
      const all = ids.every((id) => sel.ids.includes(id));
      sel.ids = all ? sel.ids.filter((id) => !ids.includes(id)) : Array.from(new Set(sel.ids.concat(ids)));
      this.render();
    },
    selTag() { if (!this.u.sel.ids.length) return; this.u.sheet = { type: 'picker', mode: 'tag', ids: this.u.sel.ids.slice(), picked: [], fresh: true }; this.render(); },
    selSkip() {
      const ids = this.u.sel.ids.slice();
      if (!ids.length) return;
      this.snapshot();
      this.s.toTag = this.s.toTag.filter((id) => !ids.includes(id));
      this.s.skipped.push(...ids);
      this.u.sel = null;
      this.snack(`${fmt.n(ids.length, 'clip')} skipped`, { undo: true }); this.render();
    },
    askSkipAll() { this.u.menu = null; this.u.dialog = { type: 'skipAll' }; this.render(); },
    confirmSkipAll() {
      const n = this.s.toTag.length;
      this.snapshot();
      this.s.skipped.push(...this.s.toTag); this.s.toTag = [];
      this.u.dialog = null;
      this.snack(`${fmt.n(n, 'clip')} skipped`, { undo: true }); this.render();
    },

    /* skipped */
    restoreOne(d) {
      this.snapshot();
      this.s.skipped = this.s.skipped.filter((id) => id !== d.id); this.s.toTag.push(d.id); this.sortToTag();
      this.snack('Restored to To tag', { undo: true }); this.render();
    },
    restoreSel() {
      const ids = this.u.sel.ids.slice();
      if (!ids.length) return;
      this.snapshot();
      this.s.skipped = this.s.skipped.filter((id) => !ids.includes(id)); this.s.toTag.push(...ids); this.sortToTag();
      this.u.sel = null;
      this.snack(`${fmt.n(ids.length, 'clip')} restored to To tag`, { undo: true }); this.render();
    },

    /* player */
    closePlayer() { this.u.player = null; this.u.snack = null; this.tab('totag'); },
    toggleMute() { this.u.player.muted = !this.u.player.muted; this.render(); },
    togglePlay() { this.u.player.paused = !this.u.player.paused; this.render(); },
    prevClip() { const P = this.u.player; const j = this.findNext(P, P.i, -1); if (j >= 0) { P.i = j; P.multi = false; P.picked = []; this.u.anim = 'back'; this.render(); } },
    nextClip() { const P = this.u.player; const j = this.findNext(P, P.i, 1); if (j >= 0) { P.i = j; P.multi = false; P.picked = []; this.u.anim = 'adv'; this.render(); } },
    chip(d) {
      const P = this.u.player;
      if (P.confirm) return;
      P.confirm = d.id;
      if (navigator.vibrate) navigator.vibrate(12);
      this.render();
      const delay = this.rm || matchMedia('(prefers-reduced-motion: reduce)').matches ? 120 : 400;
      this.timers.tag = setTimeout(() => this.tagCurrent([d.id]), delay);
    },
    chipLong(d) { const P = this.u.player; P.multi = true; P.picked = [d.id]; this.render(); },
    multiOn() { this.u.player.multi = true; this.u.player.picked = []; this.render(); },
    multiOff() { this.u.player.multi = false; this.u.player.picked = []; this.render(); },
    pickChip(d) { const P = this.u.player; const i = P.picked.indexOf(d.id); if (i >= 0) P.picked.splice(i, 1); else P.picked.push(d.id); this.render(); },
    multiConfirm() { const P = this.u.player; if (P.picked.length) this.tagCurrent(P.picked.slice()); },
    sameAsPrev() { const prev = this.s.lastTags.filter((r) => q.reel(this.s, r)); if (prev.length) this.tagCurrent(prev); },
    skipClip() {
      const P = this.u.player;
      const id = P.session[P.i];
      this.snapshot();
      this.s.toTag = this.s.toTag.filter((x) => x !== id); this.s.skipped.push(id);
      P.skippedN++;
      this.advance();
      if (!P.done) this.snack('Skipped', { undo: true });
      this.render();
    },
    toggleOthers() { this.u.otherOpen = !this.u.otherOpen; this.render(); },
    newReelPlayer() { this.u.sheet = { type: 'reelForm', mode: 'new', from: 'player', name: '', fresh: true }; this.u.kbd = true; this.u.focus = 'rname'; this.render(); },

    /* pickers */
    pickReel(d) {
      const pk = this.u.sheet;
      if (pk.mode === 'move') pk.picked = [d.id];
      else { const i = pk.picked.indexOf(d.id); if (i >= 0) pk.picked.splice(i, 1); else pk.picked.push(d.id); }
      this.render();
    },
    pickerNew() { this.u.sheet.newOpen = true; this.u.kbd = true; this.u.focus = 'pkname'; this.render(); },
    pickerCreate() {
      const pk = this.u.sheet;
      const err = this.validName(pk.newName);
      if (err) { pk.err = err; this.u.focus = 'pkname'; return this.render(); }
      const id = this.newReel(pk.newName.trim());
      if (pk.mode === 'move') pk.picked = [id]; else pk.picked.push(id);
      Object.assign(pk, { newOpen: false, newName: '', err: null });
      this.u.kbd = false; this.render();
    },
    pickerConfirm() {
      const pk = this.u.sheet;
      if (!pk.picked.length) return;
      const names = pk.picked.map((r) => q.reel(this.s, r).name);
      this.snapshot();
      if (pk.mode === 'tag') {
        this.tagInto(pk.ids, pk.picked);
        this.s.lastTags = pk.picked.slice();
        this.snack(`${fmt.n(pk.ids.length, 'clip')} added to ${names.join(' and ')}`, { undo: true, ic: 'check_circle' });
      } else if (pk.mode === 'add') {
        this.tagInto(pk.ids, pk.picked);
        this.snack(`Added to ${names.join(' and ')}`, { undo: true, ic: 'check_circle' });
      } else {
        const from = q.reel(this.s, pk.exclude);
        pk.ids.forEach((id) => { const c = this.s.clips[id]; c.reels = c.reels.filter((r) => r !== pk.exclude); if (!c.reels.includes(pk.picked[0])) c.reels.push(pk.picked[0]); });
        if (from.vn) from.vn.copied = from.vn.copied.filter((id) => !pk.ids.includes(id));
        this.snack(`Moved to ${names[0]}`, { undo: true });
        if (this.u.route === 'viewer') { this.u.sheet = null; return this.viewerAfterLeave(pk.ids[0]); }
      }
      this.u.sheet = null; this.u.sel = null; this.u.kbd = false; this.render();
    },

    /* viewer */
    viewerPrev() { const p = this.u.p; const i = p.list.indexOf(p.id); if (i > 0) { p.id = p.list[i - 1]; this.render(); } },
    viewerNext() { const p = this.u.p; const i = p.list.indexOf(p.id); if (i < p.list.length - 1) { p.id = p.list[i + 1]; this.render(); } },
    viewerAdd() { this.u.sheet = { type: 'picker', mode: 'add', ids: [this.u.p.id], exclude: this.u.p.reel, picked: [], fresh: true }; this.render(); },
    viewerMove() { this.u.sheet = { type: 'picker', mode: 'move', ids: [this.u.p.id], exclude: this.u.p.reel, picked: [], fresh: true }; this.render(); },
    viewerRemove() {
      const p = this.u.p; const r = q.reel(this.s, p.reel);
      this.snapshot();
      const id = p.id;
      this.removeFromReel([id], r.id);
      this.snack(`Removed from ${r.name}. The video is still in your gallery.`, { undo: true });
      this.viewerAfterLeave(id);
    },

    /* add videos */
    openFolder(d) { const t = this.u.p.target; this.nav('add-grid', { target: t, folder: d.f }); this.u.sel = { ctx: 'add', ids: [] }; this.render(); },
    tipSeen() { this.s.folderTipSeen = true; this.render(); },
    alreadyAdded() { this.snack('Already added'); this.render(); },
    addPicked() {
      const p = this.u.p; const t = p.target;
      const all = q.folderClips(this.s, p.folder);
      const ids = this.u.sel.ids.slice();
      if (!ids.length) return;
      this.snapshot();
      ids.forEach((id) => {
        if (!this.s.clips[id]) { const src = all.find((c) => c.id === id); this.s.clips[id] = { ...src, reels: [], external: false }; }
        const c = this.s.clips[id];
        if (t.kind === 'reel') { if (!c.reels.includes(t.id)) c.reels.push(t.id); }
        else if (!this.s.toTag.includes(id)) this.s.toTag.push(id);
      });
      this.sortToTag();
      this.hist.pop(); const back = this.hist.pop() || { route: 'totag', p: {} };
      Object.assign(this.u, { route: back.route, p: back.p, sel: null });
      this.snack(`${fmt.n(ids.length, 'video')} added to ${t.kind === 'reel' ? q.reel(this.s, t.id).name : 'To tag'}`, { undo: true, ic: 'check_circle' });
      this.render();
    },

    /* edit & editors */
    copiedInfo() { this.snack('Already in the VN folder. Copies are deleted when you tap Done editing.'); this.render(); },
    editSelectAll() {
      const r = q.reel(this.s, this.u.p.id);
      const live = q.liveClipsOf(this.s, r.id).map((c) => c.id);
      const copied = this.u.p.vnAdd && r.vn ? r.vn.copied : [];
      const free = live.filter((id) => !copied.includes(id));
      const allOn = free.every((id) => this.u.sel.ids.includes(id));
      this.u.sel.ids = allOn ? copied.slice() : Array.from(new Set(copied.concat(free)));
      this.render();
    },
    editContinue() { const ids = this.u.sel.ids.slice().sort((a, b) => (this.s.clips[a].at < this.s.clips[b].at ? -1 : 1)); if (ids.length) { this.u.sheet = { type: 'editor', id: this.u.p.id, ids, fresh: true }; this.render(); } },
    pickEditor(d) {
      const e = this.u.sheet;
      if (d.ed === 'other') { this.u.sheet = { type: 'share', n: e.ids.length, fresh: true }; return this.render(); }
      if (d.ed === 'vn') { this.u.sheet = null; return this.nav('vn-space', { id: e.id, ids: e.ids }); }
      const name = d.ed === 'capcut' ? 'CapCut' : 'Instagram Edits';
      this.u.sheet = null;
      const reelId = e.id;
      this.hist.pop();
      Object.assign(this.u, { route: 'reel', p: { id: reelId }, sel: null });
      this.snack(`Sent ${fmt.n(e.ids.length, 'clip')} to ${name}`, { ic: 'open_in_new' });
      this.log(`${name} would open now with the original clips, in shooting order.`);
      this.render();
      const r = q.reel(this.s, reelId);
      if (r.status === 'rec') this.timers.mark = setTimeout(() => { this.u.dialog = { type: 'markStatus', id: reelId, status: 'ready' }; this.render(); }, 1300);
    },
    vnAddConfirm() {
      const r = q.reel(this.s, this.u.p.id);
      const ids = this.u.sel.ids.filter((id) => !r.vn.copied.includes(id));
      if (ids.length) this.nav('vn-space', { id: r.id, ids, add: true });
    },
    vnCopy() { const p = this.u.p; this.nav('vn-copy', { id: p.id, ids: p.ids, add: p.add, done: 0 }, true); this.copyTick(); },
    stopCopy() { clearTimeout(this.timers.copy); this.u.dialog = { type: 'stopCopy' }; this.render(); },
    vnRetry() { this.u.p.fail = null; this.render(); this.copyTick(); },
    vnFinish() { this.finishCopy(); },
    cancelVN() {
      clearTimeout(this.timers.copy);
      this.u.dialog = null;
      const id = this.u.p.id;
      this.hist = this.hist.filter((x) => x.route === 'home' || x.route === 'totag');
      Object.assign(this.u, { route: 'reel', p: { id }, sel: null });
      this.snack('Copying stopped. No copies were kept.'); this.render();
    },
    openVN() { this.log('VN would open now. Its New project picker shows the TakeTray folder.'); this.snack('Opens VN'); this.render(); },
    vnDone() {
      const id = this.u.p.id;
      this.hist = this.hist.filter((x) => x.route === 'home' || x.route === 'totag');
      Object.assign(this.u, { route: 'reel', p: { id }, sel: null });
      this.render();
    },

    /* settings */
    setToggle(d) { this.s.settings[d.k] = !this.s.settings[d.k]; this.render(); },
    watchToggle(d) { const f = this.s.folders.find((x) => x.id === d.id); f.watched = !f.watched; this.render(); },
    helpOpen(d) { this.u.p.open = this.u.p.open === d.id ? 'none' : d.id; this.render(); },
    exportData() { this.s.settings.lastExport = RH.TODAY; this.snack('Backup saved to Download › taketray-backup-2026-10-12.json', { ic: 'check_circle' }); this.render(); },
    importData() { this.u.dialog = { type: 'importWarn' }; this.render(); },
    confirmImport() { this.u.dialog = { type: 'importDone' }; this.render(); },
    shootOffDialog() { this.s.shooting.on = false; this.s.notified.still = false; this.u.dialog = null; this.snack('Shooting mode off'); this.render(); },

    /* notifications */
    notifTap(d) {
      this.u.shade = null;
      if (d.n === 'vn') { this.tab('home'); this.nav('reel', { id: d.id }); this.u.dialog = { type: 'doneEditing', id: d.id }; return this.render(); }
      if (d.n === 'still') { this.u.dialog = { type: 'stillShooting' }; return this.render(); }
      this.tab('totag');
    },
    notifCam() { this.u.shade = null; this.openCameraFromShade = true; this.tab('home'); ACTIONS.openCamera.call(this); },
    notifStillOff() { this.u.shade = null; this.s.shooting.on = false; this.s.notified.still = false; this.snack('Shooting mode off'); this.render(); },

  });

  /** After onboarding, land on a reel saved from a share before the app was set up. */
  App.finishOnboarding = function () {
    const rid = this.s.pendingReel;
    if (!rid || !q.reel(this.s, rid)) return false;
    delete this.s.pendingReel;
    this.tab('home');
    this.nav('reel', { id: rid, focus: 'refs' });
    return true;
  };
  App.openReelFromShare = function (rid) {
    if (!this.s.onboarded) {
      this.s.pendingReel = rid;
      this.hist = [];
      this.nav('ob-welcome', {}, true);
      this.log('Onboarding runs first; the reel opens when it finishes.');
      return;
    }
    this.hist = [{ route: 'home', p: {} }];
    Object.assign(this.u, { route: 'reel', p: { id: rid, focus: 'refs' }, sel: null, sheet: null });
    this.render();
  };

  App.viewerAfterLeave = function (id) {
    const p = this.u.p;
    const list = p.list.filter((x) => x !== id && this.s.clips[x] && this.s.clips[x].reels.includes(p.reel));
    if (!list.length) { this.back(); return; }
    const i = Math.min(p.list.indexOf(id), list.length - 1);
    p.list = list; p.id = list[Math.max(0, i)];
    this.render();
  };

  App.copyTick = function () {
    const p = this.u.p;
    if (this.u.route !== 'vn-copy' || p.fail) return;
    clearTimeout(this.timers.copy);
    this.timers.copy = setTimeout(() => {
      if (this.u.route !== 'vn-copy' || this.u.dialog) return;
      p.done = (p.done || 0) + 1;
      if (p.done >= p.ids.length) { this.render(); this.timers.copy = setTimeout(() => this.finishCopy(), 350); return; }
      this.render();
      this.copyTick();
    }, 260);
  };

  App.finishCopy = function () {
    const p = this.u.p;
    const r = q.reel(this.s, p.id);
    const copied = r.vn ? r.vn.copied : [];
    r.vn = { folder: r.vn ? r.vn.folder : r.name, copied: Array.from(new Set(copied.concat(p.ids))), since: r.vn ? r.vn.since : RH.TODAY };
    if (p.add) {
      this.hist = this.hist.filter((x) => x.route === 'home' || x.route === 'totag');
      Object.assign(this.u, { route: 'reel', p: { id: r.id }, sel: null });
      this.snack(`${fmt.n(p.ids.length, 'clip')} added to the VN folder`, { ic: 'check_circle' });
      return this.render();
    }
    this.nav('vn-ready', { id: r.id }, true);
  };

  /* ================================================================== */
  /* Panel + page wiring                                                 */
  /* ================================================================== */
  function wirePage() {
    document.addEventListener('click', (e) => {
      const pal = e.target.closest('[data-pal], [data-usepal]');
      if (pal) { applyPalette(pal.dataset.pal || pal.dataset.usepal); return; }
      const g = e.target.closest('[data-gtheme]');
      if (g) { galleryTheme = g.dataset.gtheme; store.set('theme', galleryTheme); route(); return; }
      const t = e.target.closest('[data-try]');
      if (t) {
        const [sid, stid] = t.dataset.try.split('|');
        const sc = RH.screenById(sid); const st = sc.states.find((x) => x.id === stid);
        const preset = RH.buildState(sc, st);
        App.flow = 'explore';
        if (!App.mounted) { App.mounted = true; App.phone = $('#proto-phone'); App.bind(); }
        App.load('explore', preset);
        if (preset.u.route !== 'home' && preset.u.route !== 'totag' && preset.u.route !== 'settings') App.hist = [{ route: 'home', p: {} }];
        location.hash = '#prototype';
        return;
      }
      const pt = e.target.closest('[data-ptheme]');
      if (pt) { App.theme = pt.dataset.ptheme; store.set('protoTheme', App.theme); App.syncPanel(); App.render(); return; }
      const sim = e.target.closest('[data-sim]');
      if (sim) simulate(sim.dataset.sim);
      if (e.target.closest('#menu-btn')) { $('.side').classList.add('open'); $('.scrim-side').classList.add('show'); }
      if (e.target.closest('.scrim-side')) closeSide();
    });
    $('#pf-flow').addEventListener('change', (e) => App.load(e.target.value));
    $('#pf-android').addEventListener('change', (e) => { App.s.android = +e.target.value; App.log(`Android ${e.target.selectedOptions[0].textContent}: system dialogs and permissions follow this version.`); App.render(); });
    $('#pf-access').addEventListener('change', (e) => { App.s.access = e.target.value; if (e.target.value === 'removed' && App.u.route === 'home') App.log('Banner shown. A cold start would open the full-screen permission problem screen.'); App.render(); });
    $('#pf-rm').addEventListener('change', (e) => { App.rm = e.target.checked; App.render(); });
    $('#pf-welcome').addEventListener('change', (e) => { RH.welcomeChoice = e.target.value; store.set('welcome2', e.target.value); if (App.u.route === 'ob-welcome') App.render(); else App.log('Applies the next time onboarding starts. Pick "First launch" to see it.'); });
    $('#pf-share').addEventListener('change', (e) => { App.shareKey = e.target.value; App.log(`Next share: ${RH.SHARES[e.target.value].label}.`); });
    window.addEventListener('hashchange', route);
  }

  function simulate(k) {
    const A = App, s = A.s;
    if (!A.s) return;
    if (k === 'shoot') { A.shootClips(3); A.render(); }
    if (k === 'shade') { A.u.shade = A.u.shade ? null : {}; if (A.u.shade && !RH.activeNotifications(s).length) A.log('No notifications right now. Shoot some clips with Shooting mode on.'); A.render(); }
    if (k === 'evening') { if (!s.toTag.length) { A.log('No clips waiting, so the 9 pm reminder stays quiet.'); return; } s.notified.evening = true; A.u.shade = {}; A.log('9 pm: the evening reminder appears because clips are waiting.'); A.render(); }
    if (k === 'vn3') { if (!q.vnReels(s).length) { A.log('No VN copies exist yet. Send a reel to VN first.'); return; } s.notified.vn = true; A.u.shade = {}; A.log('3 days later: the VN copies reminder appears.'); A.render(); }
    if (k === 'still14') { if (!s.shooting.on) { A.log('Shooting mode is off, so there is nothing to remind about.'); return; } s.notified.still = true; A.u.shade = {}; A.log('14 days with Shooting mode on: asked once.'); A.render(); }
    if (k === 'reset') A.load(A.flow);
    if (k === 'back') A.back();
  }

  /* phone scaling for narrow viewports */
  function fit() {
    const main = $('.main');
    const w = main.clientWidth - 32;
    const pz = Math.min(1, w / 376);
    document.documentElement.style.setProperty('--pz', pz.toFixed(3));
  }

  document.addEventListener('DOMContentLoaded', () => {
    RH.welcomeChoice = store.get('welcome2', 'tray');
    buildSide();
    applyPalette(store.get('palette2', 'graphite'));
    document.documentElement.classList.add('style-tt');
    wirePage();
    fit();
    window.addEventListener('resize', fit);
    route();
  });
})();
