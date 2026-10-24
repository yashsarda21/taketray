/* Procedural video thumbnails. The prototype has no real footage, so each clip
   gets a seeded SVG "frame" of a recognisable scene. Same theme + seed = same
   picture every time. Returned as cached data: URIs. */
(function () {
  const RH = (window.RH = window.RH || {});

  function rng(seed) {
    let a = (seed * 2654435761) >>> 0 || 1;
    return function () {
      a |= 0; a = (a + 0x6d2b79f5) | 0;
      let t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }
  const pick = (r, arr) => arr[Math.floor(r() * arr.length)];
  const f = (n) => Math.round(n * 10) / 10;

  function grad(id, stops, vertical = true) {
    const xy = vertical ? "x1='0' y1='0' x2='0' y2='1'" : "x1='0' y1='0' x2='1' y2='0'";
    return `<linearGradient id='${id}' ${xy}>${stops.map((s, i) => `<stop offset='${f(i / (stops.length - 1))}' stop-color='${s}'/>`).join('')}</linearGradient>`;
  }
  const rect = (x, y, w, h, fill, extra = '') => `<rect x='${f(x)}' y='${f(y)}' width='${f(w)}' height='${f(h)}' fill='${fill}' ${extra}/>`;
  const circ = (x, y, r, fill, extra = '') => `<circle cx='${f(x)}' cy='${f(y)}' r='${f(r)}' fill='${fill}' ${extra}/>`;

  const SKIES = {
    day: ['#8fb3d9', '#c9dcec', '#e8eef2'],
    overcast: ['#8e9aa8', '#b9c2cc', '#d9dee3'],
    golden: ['#f2a65a', '#f7c98b', '#fbe3c0'],
    blue: ['#2c3e74', '#50609a', '#8a7fb0'],
    dusk: ['#2d2350', '#8c4a7a', '#f08a5d', '#ffc77a'],
    goa: ['#5fb4e6', '#a8d8f0', '#e9f6fb'],
  };

  function skyline(r, W, base, color, minH, maxH, windows) {
    let x = -2, s = '';
    while (x < W) {
      const w = 8 + r() * (W / 5);
      const h = minH + r() * (maxH - minH);
      s += rect(x, base - h, w + 1, h + 2, color);
      if (r() < 0.35) s += `<path d='M${f(x)} ${f(base - h)} L${f(x + w / 2)} ${f(base - h - 6 - r() * 8)} L${f(x + w)} ${f(base - h)} Z' fill='${color}'/>`;
      if (windows) {
        for (let wy = base - h + 4; wy < base - 6; wy += 6) {
          for (let wx = x + 2; wx < x + w - 3; wx += 5) {
            if (r() < windows.p) s += rect(wx, wy, 2.2, 3, windows.c, `opacity='${f(0.5 + r() * 0.5)}'`);
          }
        }
      }
      x += w;
    }
    return s;
  }

  const P = {
    street(r, W, H) {
      const sky = pick(r, [SKIES.overcast, SKIES.day, SKIES.golden]);
      const base = H * (0.72 + r() * 0.08);
      let s = `<defs>${grad('s', sky)}</defs>` + rect(0, 0, W, H, 'url(#s)');
      s += skyline(r, W, base, pick(r, ['#8c5a45', '#7a4b3a', '#6b6f78', '#a08670']), H * 0.25, H * 0.55, { p: 0.55, c: '#f3e2b8' });
      s += skyline(r, W, base, pick(r, ['#5d4037', '#4e5560', '#6d4c41']), H * 0.12, H * 0.3, { p: 0.4, c: '#ffe7a8' });
      s += rect(0, base, W, H - base, '#3a3a40');
      for (let x = 4; x < W; x += 16) s += rect(x, base + (H - base) * 0.5, 8, 1.5, '#e8e1c8');
      if (r() < 0.6) {
        const bx = r() * (W - 40), bw = Math.min(46, W * 0.5), bh = bw * 0.62, by = base - bh + (H - base) * 0.35;
        s += rect(bx, by, bw, bh, '#c8202f', "rx='3'") + rect(bx + 3, by + 4, bw - 6, bh * 0.22, '#2b2d36', "rx='1'") + rect(bx + 3, by + bh * 0.42, bw - 6, bh * 0.22, '#2b2d36', "rx='1'");
        s += circ(bx + 8, by + bh, 4, '#111') + circ(bx + bw - 8, by + bh, 4, '#111');
      }
      return s;
    },
    food(r, W, H) {
      const table = pick(r, [['#7b4f33', '#94603d'], ['#2f3437', '#3b4246'], ['#b98a5b', '#c99a6a']]);
      let s = `<defs>${grad('t', table, false)}<radialGradient id='pl'><stop offset='0.7' stop-color='#f6f1ea'/><stop offset='1' stop-color='#dcd4c8'/></radialGradient></defs>`;
      s += rect(0, 0, W, H, 'url(#t)');
      for (let i = 0; i < 6; i++) s += rect(0, r() * H, W, 0.8, 'rgba(0,0,0,0.12)');
      const cx = W * (0.4 + r() * 0.2), cy = H * (0.42 + r() * 0.16), R = Math.min(W, H) * (0.36 + r() * 0.08);
      s += circ(cx + 2, cy + 3, R, 'rgba(0,0,0,0.25)') + circ(cx, cy, R, 'url(#pl)');
      const dish = pick(r, ['curry', 'naan', 'bowl', 'burger']);
      if (dish === 'curry') {
        s += circ(cx - R * 0.2, cy, R * 0.5, '#d9822b') + circ(cx - R * 0.25, cy - R * 0.08, R * 0.32, '#c4621c');
        s += circ(cx + R * 0.35, cy + R * 0.1, R * 0.38, '#f5ecd0');
        for (let i = 0; i < 6; i++) s += circ(cx - R * 0.4 + r() * R * 0.5, cy - R * 0.3 + r() * R * 0.5, 1.6, '#3f8f3a');
      } else if (dish === 'naan') {
        s += `<ellipse cx='${f(cx)}' cy='${f(cy)}' rx='${f(R * 0.7)}' ry='${f(R * 0.45)}' fill='#e6b873' transform='rotate(${f(r() * 40 - 20)} ${f(cx)} ${f(cy)})'/>`;
        for (let i = 0; i < 10; i++) s += circ(cx - R * 0.5 + r() * R, cy - R * 0.3 + r() * R * 0.6, 1.4 + r() * 1.4, '#8a5a2b', "opacity='0.7'");
      } else if (dish === 'bowl') {
        s += circ(cx, cy, R * 0.72, '#f0e6d6') + circ(cx, cy, R * 0.6, pick(r, ['#c0392b', '#e0a43b', '#7a9a3a']));
        for (let i = 0; i < 8; i++) s += circ(cx - R * 0.4 + r() * R * 0.8, cy - R * 0.4 + r() * R * 0.8, 2 + r() * 2, pick(r, ['#f7e7c6', '#3f8f3a', '#ffcf5c']));
      } else {
        s += circ(cx, cy, R * 0.55, '#c98a3e') + circ(cx, cy, R * 0.47, '#5b3420') + circ(cx, cy, R * 0.4, '#e8b04a');
        for (let i = 0; i < 9; i++) s += circ(cx + Math.cos(i) * R * 0.3, cy + Math.sin(i) * R * 0.3, 1.3, '#f6e9c8');
      }
      s += circ(W * (0.15 + r() * 0.1), H * (0.12 + r() * 0.08), Math.min(W, H) * 0.14, '#e9e3da') + circ(W * (0.15 + r() * 0.1), H * (0.12 + r() * 0.08), Math.min(W, H) * 0.1, pick(r, ['#7a3e1d', '#e9c46a', '#f4a261']));
      return s;
    },
    market(r, W, H) {
      let s = `<defs>${grad('m', ['#f6d7a7', '#e9b97a'])}</defs>` + rect(0, 0, W, H, 'url(#m)');
      const cols = [['#c62828', '#fafafa'], ['#2e7d32', '#f1f8e9'], ['#f9a825', '#fffde7'], ['#1565c0', '#e3f2fd']];
      const [a, b] = pick(r, cols);
      const stripes = 6;
      for (let i = 0; i < stripes; i++) s += rect((W / stripes) * i, 0, W / stripes + 0.5, H * 0.2, i % 2 ? b : a);
      for (let i = 0; i < stripes * 2; i++) s += `<path d='M${f((W / (stripes * 2)) * i)} ${f(H * 0.2)} l${f(W / (stripes * 4))} ${f(H * 0.04)} l${f(W / (stripes * 4))} ${f(-H * 0.04)} Z' fill='${i % 2 ? b : a}'/>`;
      for (let row = 0; row < 3; row++) {
        const y = H * (0.32 + row * 0.14);
        s += rect(0, y + 8, W, 4, '#7b5235');
        for (let x = 4; x < W - 2; x += 7) s += circ(x + r() * 2, y + 4 + r() * 2, 3.2 + r(), pick(r, ['#f57c00', '#fbc02d', '#7cb342', '#d32f2f', '#8e24aa']));
      }
      for (let i = 0; i < 5; i++) {
        const x = r() * W, y = H * (0.78 + r() * 0.1), hr = 5 + r() * 3;
        s += circ(x, y, hr, pick(r, ['#3e2723', '#212121', '#4e342e'])) + `<rect x='${f(x - hr * 1.5)}' y='${f(y + hr - 1)}' width='${f(hr * 3)}' height='${f(H)}' rx='${f(hr)}' fill='${pick(r, ['#37474f', '#263238', '#5d4037', '#455a64'])}'/>`;
      }
      return s;
    },
    river(r, W, H) {
      const sky = pick(r, [SKIES.day, SKIES.golden, SKIES.overcast]);
      const hz = H * (0.52 + r() * 0.08);
      let s = `<defs>${grad('s', sky)}${grad('w', ['#4b6a85', '#2f4a60'])}</defs>` + rect(0, 0, W, H, 'url(#s)');
      s += skyline(r, W, hz, '#6c7a89', H * 0.06, H * 0.16, null);
      const tw = W * 0.12, t1 = W * (0.18 + r() * 0.1), t2 = t1 + W * 0.42, th = H * 0.3;
      const col = '#4f5b66';
      for (const tx of [t1, t2]) {
        s += rect(tx, hz - th, tw, th, col) + `<path d='M${f(tx - 1)} ${f(hz - th)} L${f(tx + tw / 2)} ${f(hz - th - tw * 1.2)} L${f(tx + tw + 1)} ${f(hz - th)} Z' fill='${col}'/>`;
        s += rect(tx + tw * 0.3, hz - th * 0.75, tw * 0.4, th * 0.25, '#9fb0bf', "rx='2'");
      }
      s += rect(t1 + tw, hz - th * 0.82, t2 - t1 - tw, 3, col) + rect(0, hz - th * 0.3, W, 4, col);
      s += rect(0, hz, W, H - hz, 'url(#w)');
      for (let i = 0; i < 14; i++) s += rect(r() * W, hz + r() * (H - hz), 6 + r() * 14, 1, '#d7e3ec', `opacity='${f(0.25 + r() * 0.4)}'`);
      return s;
    },
    sunset(r, W, H) {
      const hz = H * (0.62 + r() * 0.08);
      let s = `<defs>${grad('s', SKIES.dusk)}<radialGradient id='g'><stop offset='0' stop-color='#fff1c1'/><stop offset='1' stop-color='#fff1c1' stop-opacity='0'/></radialGradient></defs>`;
      s += rect(0, 0, W, H, 'url(#s)');
      const sx = W * (0.3 + r() * 0.4);
      s += circ(sx, hz - 4, Math.min(W, H) * 0.42, 'url(#g)') + circ(sx, hz - 4, Math.min(W, H) * 0.12, '#ffe7a3');
      s += skyline(r, W, hz, '#22183a', H * 0.04, H * 0.22, { p: 0.12, c: '#ffcf7a' });
      s += rect(0, hz, W, H - hz, '#2c1f44');
      for (let i = 0; i < 10; i++) s += rect(sx - 10 + r() * 20 - 6, hz + 4 + i * ((H - hz) / 11), 10 + r() * 10, 1.4, '#ffc477', `opacity='${f(0.7 - i * 0.05)}'`);
      return s;
    },
    night(r, W, H) {
      let s = `<defs>${grad('s', ['#0b1030', '#1d1c45', '#3a2a55'])}</defs>` + rect(0, 0, W, H, 'url(#s)');
      s += skyline(r, W, H * 0.8, '#141530', H * 0.2, H * 0.55, { p: 0.35, c: '#ffd36b' });
      s += rect(0, H * 0.8, W, H * 0.2, '#0c0d20');
      for (let i = 0; i < 16; i++) s += circ(r() * W, H * (0.45 + r() * 0.5), 3 + r() * 9, pick(r, ['#ffcc66', '#ff7a59', '#fff2cc', '#ff9ec7']), `opacity='${f(0.18 + r() * 0.35)}'`);
      return s;
    },
    park(r, W, H) {
      let s = `<defs>${grad('s', SKIES.day)}</defs>` + rect(0, 0, W, H, 'url(#s)');
      s += `<path d='M0 ${f(H * 0.55)} Q${f(W * 0.35)} ${f(H * 0.45)} ${f(W)} ${f(H * 0.56)} L${f(W)} ${f(H)} L0 ${f(H)} Z' fill='#6fae5c'/>`;
      s += `<path d='M0 ${f(H * 0.68)} Q${f(W * 0.6)} ${f(H * 0.58)} ${f(W)} ${f(H * 0.7)} L${f(W)} ${f(H)} L0 ${f(H)} Z' fill='#4f8f4a'/>`;
      for (let i = 0; i < 4; i++) {
        const x = r() * W, y = H * (0.5 + r() * 0.12), rr = 8 + r() * 10;
        s += rect(x - 1.5, y, 3, rr * 1.2, '#5d4037') + circ(x, y, rr, pick(r, ['#2e7d32', '#388e3c', '#1b5e20'])) + circ(x - rr * 0.5, y + 3, rr * 0.7, '#43a047');
      }
      s += `<path d='M${f(W * 0.45)} ${f(H)} Q${f(W * 0.5)} ${f(H * 0.75)} ${f(W * 0.6)} ${f(H * 0.62)} L${f(W * 0.66)} ${f(H * 0.62)} Q${f(W * 0.62)} ${f(H * 0.8)} ${f(W * 0.75)} ${f(H)} Z' fill='#d9c9a3'/>`;
      return s;
    },
    selfie(r, W, H) {
      const bg = pick(r, [['#c9b79c', '#8d7b68'], ['#9fb3c8', '#5d7189'], ['#e9a46a', '#a3563a'], ['#a3c9a8', '#4f7a5a']]);
      let s = `<defs>${grad('b', bg)}</defs>` + rect(0, 0, W, H, 'url(#b)');
      for (let i = 0; i < 6; i++) s += rect(r() * W, r() * H * 0.6, 10 + r() * 30, 20 + r() * 40, '#ffffff', `opacity='${f(0.06 + r() * 0.1)}' rx='4'`);
      const skin = pick(r, ['#8d5a3b', '#a86b48', '#c58c64', '#e0b08b']);
      const cx = W * (0.45 + r() * 0.1), cy = H * 0.5, hr = Math.min(W, H) * 0.24;
      const shirt = pick(r, ['#263238', '#c62828', '#1565c0', '#f9a825', '#6a1b9a', '#fafafa']);
      s += `<ellipse cx='${f(cx)}' cy='${f(H * 0.98)}' rx='${f(W * 0.48)}' ry='${f(H * 0.26)}' fill='${shirt}'/>`;
      s += rect(cx - hr * 0.35, cy + hr * 0.7, hr * 0.7, hr * 0.6, skin);
      s += circ(cx, cy, hr, skin);
      s += `<path d='M${f(cx - hr * 1.02)} ${f(cy - hr * 0.05)} Q${f(cx - hr)} ${f(cy - hr * 1.25)} ${f(cx)} ${f(cy - hr * 1.12)} Q${f(cx + hr * 1.05)} ${f(cy - hr * 1.2)} ${f(cx + hr * 1.02)} ${f(cy - hr * 0.1)} Q${f(cx + hr * 0.6)} ${f(cy - hr * 0.7)} ${f(cx - hr * 1.02)} ${f(cy - hr * 0.05)} Z' fill='#1b1412'/>`;
      if (r() < 0.5) s += rect(cx - hr * 0.75, cy - hr * 0.15, hr * 0.62, hr * 0.32, '#111', "rx='4'") + rect(cx + hr * 0.13, cy - hr * 0.15, hr * 0.62, hr * 0.32, '#111', "rx='4'");
      else s += circ(cx - hr * 0.38, cy - hr * 0.05, 2, '#1b1412') + circ(cx + hr * 0.38, cy - hr * 0.05, 2, '#1b1412');
      s += `<path d='M${f(cx - hr * 0.35)} ${f(cy + hr * 0.4)} Q${f(cx)} ${f(cy + hr * 0.65)} ${f(cx + hr * 0.35)} ${f(cy + hr * 0.4)}' stroke='#5b2a1e' stroke-width='2' fill='none' stroke-linecap='round'/>`;
      return s;
    },
    beach(r, W, H) {
      const hz = H * (0.46 + r() * 0.06);
      let s = `<defs>${grad('s', r() < 0.5 ? SKIES.goa : SKIES.golden)}${grad('sea', ['#1f8fb8', '#38b3cf'])}</defs>` + rect(0, 0, W, H, 'url(#s)');
      s += circ(W * (0.2 + r() * 0.6), hz - H * 0.12, Math.min(W, H) * 0.09, '#fff3c4');
      s += rect(0, hz, W, H * 0.2, 'url(#sea)');
      for (let i = 0; i < 8; i++) s += rect(r() * W, hz + r() * H * 0.2, 8 + r() * 14, 1.2, '#e6f7fb', "opacity='0.7'");
      s += `<path d='M0 ${f(hz + H * 0.2)} Q${f(W * 0.5)} ${f(hz + H * 0.16)} ${f(W)} ${f(hz + H * 0.21)} L${f(W)} ${f(H)} L0 ${f(H)} Z' fill='#f0d39b'/>`;
      const px = r() < 0.5 ? W * 0.15 : W * 0.82, py = H * 0.86;
      s += `<path d='M${f(px)} ${f(py)} Q${f(px + 6)} ${f(py - H * 0.25)} ${f(px + 2)} ${f(py - H * 0.45)}' stroke='#5d4037' stroke-width='3' fill='none'/>`;
      for (let i = 0; i < 6; i++) { const a = (i / 6) * Math.PI * 2; s += `<path d='M${f(px + 2)} ${f(py - H * 0.45)} q${f(Math.cos(a) * 12)} ${f(Math.sin(a) * 6 - 6)} ${f(Math.cos(a) * 22)} ${f(Math.sin(a) * 10 + 4)}' stroke='#2e7d32' stroke-width='3' fill='none' stroke-linecap='round'/>`; }
      return s;
    },
    cafe(r, W, H) {
      let s = `<defs>${grad('t', ['#8d6748', '#6f4e37'], false)}</defs>` + rect(0, 0, W, H, 'url(#t)');
      const cx = W * (0.5 + r() * 0.1 - 0.05), cy = H * (0.45 + r() * 0.1), R = Math.min(W, H) * 0.34;
      s += circ(cx + 2, cy + 3, R * 1.25, 'rgba(0,0,0,0.25)') + circ(cx, cy, R * 1.25, '#f3eee7') + circ(cx, cy, R, '#fbfaf7') + circ(cx, cy, R * 0.82, '#b9773f');
      s += `<path d='M${f(cx)} ${f(cy + R * 0.45)} C${f(cx - R * 0.7)} ${f(cy)} ${f(cx - R * 0.3)} ${f(cy - R * 0.55)} ${f(cx)} ${f(cy - R * 0.15)} C${f(cx + R * 0.3)} ${f(cy - R * 0.55)} ${f(cx + R * 0.7)} ${f(cy)} ${f(cx)} ${f(cy + R * 0.45)} Z' fill='#f6ead8'/>`;
      s += `<path d='M${f(W * 0.12)} ${f(H * 0.85)} q${f(W * 0.25)} ${f(-H * 0.14)} ${f(W * 0.5)} 0 q${f(-W * 0.25)} ${f(H * 0.06)} ${f(-W * 0.5)} 0 Z' fill='#d9953f'/>`;
      return s;
    },
    festival(r, W, H) {
      let s = `<defs>${grad('s', ['#1a0f2e', '#2c1747'])}<radialGradient id='gl'><stop offset='0' stop-color='#ffb703' stop-opacity='0.9'/><stop offset='1' stop-color='#ffb703' stop-opacity='0'/></radialGradient></defs>`;
      s += rect(0, 0, W, H, 'url(#s)');
      for (let x = 0; x < W; x += 7) s += circ(x, H * 0.12 + Math.sin(x / 9) * 6, 1.6, pick(r, ['#ffd166', '#ef476f', '#06d6a0', '#fff']));
      const cx = W / 2, cy = H * 0.55, R = Math.min(W, H) * 0.32;
      for (let i = 0; i < 12; i++) { const a = (i / 12) * Math.PI * 2; s += circ(cx + Math.cos(a) * R * 0.7, cy + Math.sin(a) * R * 0.7, R * 0.22, ['#ef476f', '#ffd166', '#06d6a0', '#118ab2'][i % 4]); }
      s += circ(cx, cy, R * 0.45, '#f8f0e3') + circ(cx, cy, R * 0.25, '#ef476f');
      for (let i = 0; i < 5; i++) { const x = W * (0.1 + i * 0.2), y = H * 0.88; s += circ(x, y - 6, 12, 'url(#gl)') + `<ellipse cx='${f(x)}' cy='${f(y)}' rx='6' ry='3' fill='#b5562c'/>` + `<path d='M${f(x)} ${f(y - 9)} q3 4 0 6 q-3 -2 0 -6 Z' fill='#ffd166'/>`; }
      return s;
    },
    rain(r, W, H) {
      let s = `<defs>${grad('s', ['#55657a', '#8394a8', '#a9b6c4'])}</defs>` + rect(0, 0, W, H, 'url(#s)');
      for (let i = 0; i < 12; i++) s += circ(r() * W, H * (0.5 + r() * 0.5), 6 + r() * 12, pick(r, ['#ffd27a', '#ff8a65', '#e0f2ff', '#c8202f']), `opacity='${f(0.2 + r() * 0.25)}'`);
      for (let i = 0; i < 40; i++) s += `<ellipse cx='${f(r() * W)}' cy='${f(r() * H)}' rx='${f(0.8 + r() * 1.4)}' ry='${f(1.2 + r() * 2)}' fill='#fff' opacity='${f(0.25 + r() * 0.4)}'/>`;
      return s;
    },
  };

  const cache = new Map();
  RH.thumb = function (theme, seed, orient) {
    const key = theme + seed + orient;
    if (cache.has(key)) return cache.get(key);
    const W = orient === 'h' ? 160 : 90;
    const H = orient === 'h' ? 90 : 160;
    const painter = P[theme] || P.street;
    const body = painter(rng(seed), W, H);
    const svg = `<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 ${W} ${H}' preserveAspectRatio='xMidYMid slice'>${body}</svg>`;
    const uri = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
    cache.set(key, uri);
    return uri;
  };
  RH.THEMES = Object.keys(P);
})();
