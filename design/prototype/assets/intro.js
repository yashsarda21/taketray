/* Launch and welcome motion (design change, 15 Nov 2026).
   1. Splash: the tray icon animates in under 1 s (tray rises, two clips drop in, the tray catches them).
   2. Welcome (B · Tray): a 3.6 s intro on first launch only. Takes drop into the tray one by one, their reel tabs
      pop, the count ticks to 23, the copy rises in, a light glints across the tray. "Get started" works from frame 0,
      a tap on the picture skips to the end, and with reduced motion the final frame shows at once.
   Modes, from u.p: at (ms) freezes one frame (gallery), final shows the end state, otherwise it plays. */
(function () {
  const RH = window.RH;
  const { h } = RH;
  const SPLASH_MS = 900;
  const INTRO_MS = 3600;
  RH.INTRO = { SPLASH_MS, INTRO_MS };

  const mode = (p, playingAt) => {
    if (p && p.at != null) return { cls: 'frozen', at: p.at };
    if (p && p.final) return { cls: 'final', at: 0 };
    if (playingAt == null || playingAt >= Infinity) return { cls: 'final', at: 0 };
    return { cls: 'playing', at: playingAt };
  };

  /* ---------------------------------------------------------------- Splash */
  // The launcher icon's own layers, grouped for animation: back clip, front clip (with its play mark), tray.
  function splashIcon(size) {
    const t = document.createElement('template');
    t.innerHTML = h.brandIcon(size, 'tray', 'circle').trim();
    const svg = t.content.firstElementChild;
    const g = svg && svg.querySelector('g[clip-path]');
    if (!g) return h.brandIcon(size, 'tray', 'circle');
    const kids = Array.from(g.children); // [background, back, front, play, tray, rim]
    const wrap = (cls, nodes) => `<g class="${cls}">${nodes.map((n) => n.outerHTML).join('')}</g>`;
    g.innerHTML = kids[0].outerHTML + wrap('sp-back', [kids[1]]) + wrap('sp-front', [kids[2], kids[3]]) + wrap('sp-tray', [kids[4], kids[5]]);
    return svg.outerHTML;
  }

  RH.routes.splash = (s, u) => {
    const m = mode(u.p, 0);
    return {
      html: `<div class="scr"><div class="splash motion-intro sp-${m.cls}" style="--at:${m.at}ms">${splashIcon(144)}<div class="wm">TakeTray</div></div></div>`,
      splash: true,
    };
  };

  /* --------------------------------------------------------------- Welcome */
  const trayRender = RH.WELCOMES.tray.render;
  RH.WELCOMES.tray.render = (s, u) => {
    let playingAt = null;
    if (!(u.p && (u.p.at != null || u.p.final))) {
      // Plays once: the clock starts on the first render and keeps running across re-renders and Back.
      if (s.welIntroAt == null) s.welIntroAt = Date.now();
      const t = Date.now() - s.welIntroAt;
      playingAt = t < INTRO_MS ? t : Infinity;
    }
    const m = mode(u.p, playingAt);
    return trayRender(s, u)
      .replace('<div class="scr wel wel-tray">', `<div class="scr wel wel-tray motion-intro wi-${m.cls}" style="--at:${m.at}ms">`)
      .replace('<div class="tray-art" role="img"', '<div class="tray-art" data-a="welSkip" role="img"')
      .replace('<span class="tray"><span>23 takes · 3 reels</span></span>', '<span class="tray"><span class="cnt"><span class="tk"></span>&nbsp;takes<span class="rl">&nbsp;· 3 reels</span></span></span>');
  };

  RH.ACTIONS.welSkip = function () {
    if (this.s.welIntroAt == null) return;
    this.s.welIntroAt = Date.now() - INTRO_MS;
    this.render();
  };

  /* --------------------------------------------------------- Gallery states */
  const go = (u, route, p = {}) => { u.route = route; u.p = p; };
  const splash = RH.SCREENS.find((x) => x.id === 'splash');
  splash.notes = [
    'Android 12+ SplashScreen API: the tray icon on graphite, with the wordmark as the branding image. The icon is an animated vector (under 1 s, as Android recommends); the wordmark stays still.',
    '0–300 ms the tray rises in. 150–550 ms the back clip drops in. 300–750 ms the front clip drops in. 700–920 ms the tray squashes slightly as it catches them.',
    'The splash leaves as soon as the first screen is ready, with a 200 ms fade. It never waits for the animation to finish, and it never loops.',
    'Android 11 (the SplashScreen compat library) shows the still icon. With "Remove animations" on, Android shows the still icon too.',
  ];
  splash.spec = { Duration: '900 ms of motion; the splash stays only while the app loads.', Exit: '200 ms fade (exit faster than enter).', Watch: 'Motion page → Launch and welcome, or Prototype → Start from: Onboarding.' };
  splash.states = [
    { id: 'default', label: 'App launch (final frame)', setup: (s, u) => go(u, 'splash', { final: true }) },
    ...[0, 150, 350, 550, 800].map((t) => ({ id: `f${t}`, label: `Frame at ${t} ms`, setup: (s, u) => go(u, 'splash', { at: t }) })),
  ];

  const wel = RH.SCREENS.find((x) => x.id === 'welcome');
  wel.notes = [
    'Chosen: B · Tray. On first launch it plays a 3.6 s intro: the takes drop into the tray one by one, each reel tab pops on as its take lands, the count ticks up to 23 takes, then the wordmark, headline and text rise in, and a light glints across the tray.',
    'Get started is there and works from the first frame; nobody waits for the intro. A tap on the picture skips to the end.',
    'Plays once. If the person comes back (Back from Video access, or the app reopens before onboarding is done), the final frame shows.',
    'With "Remove animations" on, the final frame shows at once. TalkBack reads the headline and text straight away; the picture is one image with its label.',
    'The other two directions are kept below for reference, with their original single motion moment.',
  ];
  wel.spec = Object.assign({}, wel.spec, { Intro: '3.6 s, first launch only; tap the picture to skip.', Watch: 'Motion page → Launch and welcome (with slow motion), or Prototype → Start from: Onboarding.' });
  const trayIdx = wel.states.findIndex((x) => x.id === 'tray');
  wel.states[trayIdx] = { ...wel.states[trayIdx], label: `${RH.WELCOMES.tray.name} (chosen, final frame)`, setup: (s, u) => { s.onboarded = false; go(u, 'ob-welcome', { v: 'tray', final: true }); } };
  const frames = [[400, 'disc and tray come in'], [1000, 'first take falls'], [1500, 'second take lands, tab pops'], [1950, 'third take lands, count reaches 23'], [2500, 'headline rises in'], [3100, 'glint across the tray']];
  wel.states.splice(trayIdx + 1, 0, ...frames.map(([t, what]) => ({ id: `tray-${t}`, label: `Intro at ${(t / 1000).toFixed(1)} s`, desc: what, setup: (s, u) => { s.onboarded = false; go(u, 'ob-welcome', { v: 'tray', at: t }); } })));

  /* ------------------------------------------------- Motion page live demo */
  function demo() {
    const box = document.getElementById('intro-demo');
    if (!box) return;
    const ph = box.querySelector('.ph');
    const speedSel = box.querySelector('#intro-speed');
    const themeSel = box.querySelector('#intro-theme');
    let timer = null;
    const rate = () => Number(speedSel.value) || 1;
    const paint = (route) => {
      const s = RH.fixture();
      s.onboarded = false;
      const u = RH.defaultUI();
      u.route = route; u.p = {};
      const out = RH.renderPhone(s, u);
      ph.className = `ph rh-${themeSel.value}`;
      ph.innerHTML = out.html;
      ph.getAnimations({ subtree: true }).forEach((a) => { a.playbackRate = rate(); });
    };
    const play = () => {
      clearTimeout(timer);
      paint('splash');
      timer = setTimeout(() => paint('ob-welcome'), 1100 / rate());
    };
    box.querySelector('#intro-replay').addEventListener('click', play);
    box.querySelector('#intro-welcome').addEventListener('click', () => { clearTimeout(timer); paint('ob-welcome'); });
    speedSel.addEventListener('change', play);
    themeSel.addEventListener('change', play);
    play();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', demo);
  else demo();
})();
