/* TakeTray component library: small functions that return HTML strings.
   Every component reads colours from tokens only (--md-*, --x-*). */
(function () {
  const RH = (window.RH = window.RH || {});
  const fmt = RH.fmt;
  const q = RH.q;

  const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const data = (o) => (o ? Object.entries(o).filter(([, v]) => v != null).map(([k, v]) => ` data-${k}="${esc(v)}"`).join('') : '');
  const icon = (name, cls = '') => `<span class="ms ${cls}" aria-hidden="true">${name}</span>`;

  const STATUS = {
    rec: { label: 'Recording', icon: 'radio_button_checked', cls: 'rec', desc: 'Still shooting clips for it' },
    ready: { label: 'Ready to edit', icon: 'content_cut', cls: 'ready', desc: 'All the clips are in' },
    pub: { label: 'Published', icon: 'check_circle', cls: 'pub', desc: 'Posted on Instagram' },
  };

  const h = (RH.h = {
    esc, data, icon, STATUS,

    /** Button. kind: filled | tonal | outlined | text | danger | attn */
    btn({ label, ic, kind = 'filled', a, d, cls = '', dis, aria, size = '' } = {}) {
      return `<button class="btn tap ${kind} ${size} ${cls}${dis ? ' dis' : ''}"${a ? ` data-a="${a}"` : ''}${data(d)}${dis ? ' aria-disabled="true" tabindex="-1"' : ''}${aria ? ` aria-label="${esc(aria)}"` : ''}>${ic ? icon(ic) : ''}<span>${esc(label)}</span></button>`;
    },

    /** Icon button with a 48 dp target and a required accessible name. */
    ib(ic, { a, label, d, cls = '', fill, pressed } = {}) {
      return `<button class="ib tap ${cls}" aria-label="${esc(label)}"${a ? ` data-a="${a}"` : ''}${data(d)}${pressed != null ? ` aria-pressed="${pressed}"` : ''}>${icon(ic, fill ? 'fill' : '')}</button>`;
    },

    statusPill(status, { big, caret, a, d } = {}) {
      const st = STATUS[status];
      const tag = a ? 'button' : 'span';
      return `<${tag} class="pill ${st.cls} ${big ? 'big' : ''} ${a ? 'tap' : ''}"${a ? ` data-a="${a}" aria-label="Status: ${st.label}. Change status" aria-haspopup="menu"` : ''}${data(d)}>${icon(st.icon, 'fill')}<span>${st.label}</span>${caret ? icon('arrow_drop_down', 'caret') : ''}</${tag}>`;
    },

    sw(on, { a, d, label, inv } = {}) {
      return `<button class="sw-hit" role="switch" aria-checked="${!!on}" aria-label="${esc(label)}"${a ? ` data-a="${a}"` : ''}${data(d)}><span class="sw ${on ? 'on' : ''} ${inv ? 'inv' : ''}">${icon('check')}</span></button>`;
    },

    statusbar(onVideo) {
      return `<div class="sbar ${onVideo ? 'on-video' : ''}" aria-hidden="true"><span>7:24</span><span class="icons">${icon('signal_cellular_alt', 'fill')}${icon('wifi', 'fill')}${icon('battery_5_bar', 'fill')}</span></div>`;
    },

    appbar({ title, sub, nav, navA = 'back', actions = '', big, sel, raised, titleId } = {}) {
      const navBtn = nav === 'back' ? h.ib('arrow_back', { a: navA, label: 'Back' }) : nav === 'close' ? h.ib('close', { a: navA, label: 'Close' }) : '';
      const t = big ? `<h1 class="title t-hm"${titleId ? ` id="${titleId}"` : ''}>${esc(title)}</h1>` : `<div class="title ${nav ? '' : 'first'}"><h1 class="t-tl" style="margin:0">${esc(title)}</h1>${sub ? `<span class="sub">${esc(sub)}</span>` : ''}</div>`;
      return `<header class="appbar ${big ? 'big' : ''} ${sel ? 'sel' : ''} ${raised ? 'raised' : ''}">${navBtn}${t}${actions}</header>`;
    },

    navbar(active, toTagCount) {
      const it = (id, ic, label, badge) => `<button class="it tap ${active === id ? 'on' : ''}" data-a="tab" data-tab="${id}" aria-label="${label}${badge ? `, ${badge} clips waiting` : ''}"${active === id ? ' aria-current="page"' : ''}><span class="ind">${icon(ic, active === id ? 'fill' : '')}${badge ? `<span class="badge" aria-hidden="true">${badge > 99 ? '99+' : badge}</span>` : ''}</span><span>${label}</span></button>`;
      return `<nav class="navbar" aria-label="Main">${it('home', 'video_library', 'Reels')}${it('totag', 'sell', 'To tag', toTagCount)}${it('settings', 'settings', 'Settings')}</nav>`;
    },

    img(clip, alt = '') {
      return `<img src="${RH.thumb(clip.theme, clip.seed, clip.orient)}" alt="${esc(alt)}" loading="lazy" decoding="async">`;
    },

    clipLabel(clip, s) {
      const n = clip.reels.length;
      return `Clip, ${fmt.time(clip.at)}, ${fmt.dur(clip.dur)}${clip.orient === 'h' ? ', horizontal' : ''}${n > 1 ? `, in ${n} reels` : ''}`;
    },

    /** Clip tile with every badge it can carry. */
    tile(clip, s, o = {}) {
      if (clip.missing) {
        return `<div class="tile miss" role="group" aria-label="Clip missing from your phone">${icon('videocam_off')}<span class="ml">Missing from phone</span>${o.noRemove ? '' : h.btn({ label: 'Remove', kind: 'tonal', size: 'sm', a: 'removeMissing', d: { id: clip.id } })}</div>`;
      }
      const sel = o.selecting;
      const on = sel && o.sel;
      const multi = !o.hideMulti && clip.reels.length > 1 ? `<span class="multi">${icon('layers', 'fill')}${clip.reels.length}</span>` : '';
      const hz = clip.orient === 'h' && !multi ? `<span class="hz" title="Horizontal video">${icon('crop_16_9')}</span>` : '';
      const mark = o.mark ? `<span class="mark"><span>${icon(o.mark.ic, 'fill')}${esc(o.mark.label)}</span></span>` : '';
      const vn = o.vnMark ? `<span class="pill vn vnmark" style="height:20px;font-size:11px;padding:0 6px 0 4px">${icon('folder_copy', 's16')}In VN folder</span>` : '';
      const label = h.clipLabel(clip, s) + (o.mark ? `, ${o.mark.label}` : '') + (o.vnMark ? ', already in VN folder' : '');
      return `<button class="tile tap ${on ? 'sel' : ''}" ${o.a ? `data-a="${o.a}"` : ''}${o.lp ? ` data-lp="${o.lp}"` : ''}${data({ id: clip.id, ...(o.d || {}) })} aria-label="${esc(label)}"${sel ? ` aria-pressed="${!!on}"` : ''}${o.disabled ? ' aria-disabled="true"' : ''}>
        <span class="img">${h.img(clip)}</span><span class="scr-b"></span>
        ${o.noTime || o.mark ? '' : `<span class="tm">${fmt.time(clip.at)}</span>`}${o.mark ? '' : `<span class="du">${fmt.dur(clip.dur)}</span>`}
        ${multi}${hz}${vn}${mark}${sel ? `<span class="selc">${icon('check')}</span>` : ''}
      </button>`;
    },

    skelTiles(n) {
      return Array.from({ length: n }, () => '<span class="tile skel" aria-hidden="true"></span>').join('');
    },

    reelCard(reel, s) {
      const clips = q.clipsOf(s, reel.id);
      const live = clips.filter((c) => !c.missing);
      const missing = clips.length - live.length;
      const cover = live[0];
      const vn = reel.vn ? `<span class="pill vn">${icon('folder_copy', 'fill')}<span>Editing in VN</span></span>` : '';
      const coverHtml = cover ? h.img(cover) : `<span class="ph-empty">${icon('movie')}<span>No clips yet</span></span>`;
      const meta = clips.length ? `<span>${fmt.n(clips.length, 'clip')} · ${fmt.dur(q.total(live))}</span>` : '<span>0 clips</span>';
      const miss = missing ? `<span class="miss">${icon('error', 'fill')}${missing} missing</span>` : '';
      const label = `${reel.name}. ${STATUS[reel.status].label}. ${clips.length} clips${missing ? `, ${missing} missing` : ''}${reel.vn ? '. Editing in VN' : ''}`;
      const refs = (reel.refs || []).length;
      const badge = refs ? `<button class="refbadge tap" data-a="openRefs" data-id="${reel.id}" aria-label="${fmt.n(refs, 'reference')} in ${esc(reel.name)}">${icon('link')}${refs}</button>` : '';
      return `<div class="rcard-wrap"><button class="rcard tap" data-a="openReel" data-id="${reel.id}" aria-label="${esc(label)}"><span class="cover">${coverHtml}${h.statusPill(reel.status)}${vn}</span><span class="cap"><span class="nm clamp2">${esc(reel.name)}</span><span class="mt">${meta}${miss}</span></span></button>${badge}</div>`;
    },

    /** Reel chip for the tag player. state: '', 'pick', 'done' */
    reelChip(reel, s, { state = '', multi, a = 'chip' } = {}) {
      const cover = q.cover(s, reel.id);
      const count = q.clipsOf(s, reel.id).length;
      const cv = state === 'done' ? icon('check') : cover ? h.img(cover) : icon('movie');
      return `<button class="rchip tap ${state}" data-a="${a}" data-id="${reel.id}"${a === 'chip' ? ' data-lp="chipLong"' : ''} ${multi ? `role="checkbox" aria-checked="${state === 'pick'}"` : ''} aria-label="${multi ? '' : 'Add to '}${esc(reel.name)}, ${count} clips">
        <span class="cv">${cv}</span><span class="t"><b>${esc(reel.name)}</b><span>${fmt.n(count, 'clip')}</span></span>${multi ? `<span class="cbox ${state === 'pick' ? 'on' : ''}">${icon('check')}</span>` : ''}</button>`;
    },

    sceneHeader(sc, s, { a = 'tagScene', selecting, allSel } = {}) {
      const clips = sc.ids.map((id) => s.clips[id]);
      const range = fmt.range(sc.start, sc.end);
      const action = selecting
        ? `<button class="btn text sm" data-a="selScene" data-ids="${sc.ids.join(',')}">${allSel ? 'Unselect' : 'Select all'}</button>`
        : h.btn({ label: 'Tag scene', ic: 'sell', kind: 'tonal', size: 'sm', a, d: { ids: sc.ids.join(',') }, aria: `Tag scene ${range}, ${sc.ids.length} clips` });
      return `<div class="sec-h"><div class="grow"><b>${range}</b><span>${fmt.n(sc.ids.length, 'clip')} · ${fmt.dur(q.total(clips))}</span></div>${action}</div>`;
    },

    snack(sn) {
      if (!sn) return '';
      return `<div class="snack ${sn.fresh ? 'fresh' : ''}" role="status" aria-live="polite" style="${sn.bottom != null ? `bottom:${sn.bottom}px` : ''}">${sn.ic ? icon(sn.ic, 'lead fill') : ''}<span class="grow">${esc(sn.text)}</span>${sn.undo ? `<button class="btn text" data-a="undo">Undo</button>` : ''}${sn.action ? `<button class="btn text" data-a="${sn.action.a}">${esc(sn.action.label)}</button>` : ''}</div>`;
    },

    empty({ ill, title, body, acts = '' }) {
      return `<div class="empty">${h.illus(ill)}<h2>${esc(title)}</h2><p>${body}</p><div class="acts">${acts}</div></div>`;
    },

    /** Small flat illustrations built from tokens. */
    illus(name) {
      const c = (v) => `style="fill:var(${v})"`;
      const tile = (x, y, w, hh, v, r = 6) => `<rect x="${x}" y="${y}" width="${w}" height="${hh}" rx="${r}" ${c(v)}/>`;
      const svg = (body) => `<svg class="ill" viewBox="0 0 168 140" aria-hidden="true">${body}</svg>`;
      switch (name) {
        case 'caught':
          return svg(tile(30, 30, 48, 64, '--md-surface-container-highest') + tile(60, 22, 48, 64, '--md-surface-container-high') + tile(90, 30, 48, 64, '--md-surface-container-highest')
            + `<circle cx="84" cy="96" r="30" ${c('--x-success-color')}/><path d="M71 96l9 9 18-19" fill="none" stroke-width="7" stroke-linecap="round" stroke-linejoin="round" style="stroke:var(--x-success-on-color)"/>`);
        case 'shootoff':
          return svg(tile(54, 12, 60, 108, '--md-surface-container-highest', 12) + tile(62, 24, 44, 70, '--md-surface-container-high', 6)
            + `<circle cx="84" cy="107" r="7" ${c('--md-outline')}/><rect x="96" y="70" width="56" height="32" rx="16" ${c('--md-primary')}/><circle cx="136" cy="86" r="11" ${c('--md-on-primary')}/><circle cx="34" cy="42" r="8" ${c('--x-record-color')}/>`);
        case 'noreels':
          return svg(tile(22, 20, 56, 76, '--md-surface-container-highest', 12) + tile(90, 20, 56, 76, '--md-surface-container-high', 12)
            + tile(28, 104, 40, 8, '--md-outline-variant', 4) + tile(96, 104, 30, 8, '--md-outline-variant', 4)
            + `<circle cx="118" cy="58" r="20" ${c('--md-primary')}/><path d="M118 48v20M108 58h20" stroke-width="5" stroke-linecap="round" style="stroke:var(--md-on-primary)"/>`);
        case 'emptyreel':
          return svg(tile(46, 14, 76, 100, '--md-surface-container-highest', 14)
            + `<path d="M74 52l26 16-26 16z" ${c('--md-outline')}/><circle cx="122" cy="108" r="20" ${c('--md-tertiary-container')}/><path d="M122 98v20M112 108h20" stroke-width="5" stroke-linecap="round" style="stroke:var(--md-on-tertiary-container)"/>`);
        case 'folder':
          return svg(`<path d="M30 40a8 8 0 0 1 8-8h28l10 10h54a8 8 0 0 1 8 8v58a8 8 0 0 1-8 8H38a8 8 0 0 1-8-8z" ${c('--md-surface-container-highest')}/><path d="M66 86h36" stroke-width="6" stroke-linecap="round" style="stroke:var(--md-outline-variant)"/>`);
        case 'perm':
          return svg(tile(28, 24, 34, 44, '--md-surface-container-highest', 6) + tile(66, 24, 34, 44, '--md-surface-container-high', 6) + tile(104, 24, 34, 44, '--md-surface-container-highest', 6)
            + tile(28, 72, 34, 44, '--md-surface-container-high', 6) + tile(66, 72, 34, 44, '--md-surface-container-highest', 6) + tile(104, 72, 34, 44, '--md-surface-container-high', 6)
            + `<circle cx="84" cy="70" r="26" ${c('--md-primary')}/><rect x="74" y="66" width="20" height="16" rx="3" ${c('--md-on-primary')}/><path d="M78 66v-5a6 6 0 0 1 12 0v5" fill="none" stroke-width="3.5" style="stroke:var(--md-on-primary)"/>`);
        case 'skipped':
          return svg(tile(40, 22, 48, 64, '--md-surface-container-highest') + tile(80, 30, 48, 64, '--md-surface-container-high')
            + `<circle cx="84" cy="98" r="24" ${c('--md-secondary-container')}/><path d="M74 98h16m-6-7l7 7-7 7" fill="none" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round" style="stroke:var(--md-on-secondary-container)"/>`);
        default:
          return '';
      }
    },

    /** TakeTray app icon, drawn from the same geometry as the Android files (tools/build_icons.py).
        mode: 'color' (launcher), 'mono' (Android 13+ themed icon), 'notif' (status bar, 24 dp). */
    brandIcon(size = 96, variant = 'tray', shape = 'circle', mode = 'color') {
      const c = (window.TT_ICONS || {})[variant] || (window.TT_ICONS || {}).tray;
      if (!c) return '';
      const id = `ic${variant}${size}${shape}${mode}${Math.random().toString(36).slice(2, 6)}`;
      // Brand fills follow the active colour option (--ic-* from tokens.css); white stays white.
      const IC = { '#7332DF': 'var(--ic-bg)', '#FFB954': 'var(--ic-accent)', '#E99B00': 'var(--ic-accent-deep)', '#CABEFF': 'var(--ic-soft)', '#B39DFF': 'var(--ic-soft2)', '#FFDDB2': 'var(--ic-peach)' };
      const col = (f) => (String(f).startsWith('ic-') ? `var(--${f})` : IC[String(f).toUpperCase()] || f);
      const paths = (layers, fill) => layers.map((L) => { const p = `<path d="${L.d}" style="fill:${L.fill && mode === 'color' ? col(L.fill) : fill}" fill-rule="${L.evenodd ? 'evenodd' : 'nonzero'}"/>`; return L.rotate ? `<g transform="rotate(${L.rotate.join(' ')})">${p}</g>` : p; }).join('');
      if (mode === 'notif') return `<svg width="${size}" height="${size}" viewBox="0 0 24 24" aria-hidden="true">${paths(c.notification, 'currentColor')}</svg>`;
      const mask = shape === 'circle' ? '<circle cx="54" cy="54" r="54"/>' : '<rect width="108" height="108" rx="30"/>';
      const body = mode === 'mono' ? `<rect width="108" height="108" style="fill:var(--md-secondary-container, #E3E0F7)"/>${paths(c.monochrome, 'var(--md-on-secondary-container, #1D192A)')}` : `<rect width="108" height="108" style="fill:${col(c.background)}"/>${paths(c.foreground, '#fff')}`;
      return `<svg width="${size}" height="${size}" viewBox="0 0 108 108" role="img" aria-label="TakeTray app icon${mode === 'mono' ? ', themed' : ''}"><defs><clipPath id="${id}">${mask}</clipPath></defs><g clip-path="url(#${id})">${body}</g></svg>`;
    },

    /** Placeholder for third-party editor icons (the system supplies the real ones). */
    editorIcon(name) {
      const map = { capcut: ['#1d1d1f', 'C'], edits: ['#3b3b52', 'E'], vn: ['#2a2a2a', 'VN'], other: ['var(--md-secondary-container)', ''] };
      const [bg, t] = map[name] || map.other;
      if (name === 'other') return `<span class="appic-g own" style="background:${bg};color:var(--md-on-secondary-container)">${icon('apps')}</span>`;
      return `<span class="appic-g" style="background:${bg}" aria-hidden="true">${t}</span>`;
    },

    keyboard() {
      const row = (keys, extra = '') => `<div class="kr">${extra}${keys.split('').map((k) => `<i>${k}</i>`).join('')}</div>`;
      return `<div class="kbd" aria-hidden="true">${row('qwertyuiop')}${row('asdfghjkl')}<div class="kr"><i class="w">⇧</i>${'zxcvbnm'.split('').map((k) => `<i>${k}</i>`).join('')}<i class="w">⌫</i></div><div class="kr"><i class="w">?123</i><i>,</i><i class="sp"> </i><i>.</i><i class="go">✓</i></div></div>`;
    },

    tf({ id, label, value = '', ph = '', focus, err, help, counter, multi, a }) {
      const field = multi
        ? `<textarea id="${id}" rows="3" placeholder="${esc(ph)}" aria-describedby="${id}-help"${a ? ` data-in="${a}"` : ''}>${esc(value)}</textarea>`
        : `<input id="${id}" value="${esc(value)}" placeholder="${esc(ph)}" aria-describedby="${id}-help" autocomplete="off"${a ? ` data-in="${a}"` : ''}${err ? ' aria-invalid="true"' : ''}>`;
      return `<div class="tf ${focus ? 'focus' : ''} ${err ? 'err' : ''}"><label for="${id}">${esc(label)}</label><div class="box">${field}</div><div class="help" id="${id}-help"><span>${err ? icon('error', 'fill') + esc(err) : esc(help || '')}</span>${counter != null ? `<span data-counter="${id}">${value.length}/${counter}</span>` : ''}</div></div>`;
    },
  });
})();
