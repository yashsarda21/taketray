/* Welcome screen options (add-on 1). Three directions to choose from, plus the
   previous version for comparison. The prototype panel picks which one runs. */
(function () {
  const RH = window.RH;
  const { h } = RH;
  const { esc, icon } = h;

  const dots = (i) => `<div class="steps-dots" aria-label="Step ${i + 1} of 4">${[0, 1, 2, 3].map((k) => `<i class="${k === i ? 'on' : ''}"></i>`).join('')}</div>`;
  const cta = () => h.btn({ label: 'Get started', kind: 'filled', size: 'lg block', a: 'obNext', d: { to: 'ob-video' } });
  const thumb = (c) => RH.thumb(c.theme, c.seed, 'v');
  // Fixed sample takes, so the welcome looks the same on a fresh install (no clips yet).
  const T = (theme, seed) => ({ theme, seed });
  const DAY = [
    { time: '9:20 am', n: 4, takes: [T('food', 41), T('cafe', 42), T('food', 43)], reel: 'London Food' },
    { time: '11:02 am', n: 6, takes: [T('river', 44), T('selfie', 45), T('river', 46)], reel: 'Cinematic' },
    { time: '6:40 pm', n: 7, takes: [T('sunset', 47), T('night', 48), T('sunset', 49)], reel: 'Day 1 Vlog' },
  ];

  RH.WELCOMES = {
    slate: {
      name: 'A · Slate',
      pitch: 'Film-set language. A clapperboard slate shows the app\'s idea as the fields a camera crew already writes: reel, take, scene. Typographic, no illustration.',
      render(s) {
        const n = 23;
        return `<div class="scr rh-dark wel wel-slate"><div class="slate" role="img" aria-label="Film slate. Production TakeTray, reel London Food, take ${n}, scene Borough Market, 12 Oct, director You, roll Day 3">
            <div class="stick"><span></span><span></span><span></span><span></span><span></span><span></span></div>
            <div class="board"><div class="cell wide"><span>Production</span><b>TakeTray</b></div>
              <div class="cell"><span>Reel</span><b>London Food</b></div><div class="cell num"><span>Take</span><b>${n}</b></div>
              <div class="cell"><span>Scene</span><b>Borough Mkt</b></div><div class="cell num"><span>Date</span><b>12 Oct</b></div>
              <div class="cell"><span>Director</span><b>You</b></div><div class="cell num"><span>Roll</span><b>Day 3</b></div></div></div>
          <div class="wel-body">${dots(0)}<h1>Shoot freely.<br>Every take, sorted.</h1><p>Film with your normal camera. TakeTray collects each new clip, so you can tag it into the right reel later.</p></div>
          <div class="foot">${cta()}</div></div>`;
      },
    },
    tray: {
      name: 'B · Tray',
      pitch: 'The brand object as hero: real takes standing in the TakeTray tray, each tabbed with its reel. It explains the name and ties the welcome to the app icon.',
      render(s) {
        const c = [T('food', 52), T('river', 57), T('selfie', 63)];
        const take = (clip, label, cls) => `<span class="take ${cls}"><span class="tab">${esc(label)}</span><img src="${thumb(clip)}" alt=""></span>`;
        return `<div class="scr wel wel-tray"><div class="tray-art" role="img" aria-label="Three takes standing in a tray, labelled London Food, Cinematic and Day 1 Vlog">
            <span class="disc"></span>${take(c[0], 'London Food', 't1')}${take(c[1], 'Cinematic', 't2')}${take(c[2], 'Day 1 Vlog', 't3')}
            <span class="tray"><span>23 takes · 3 reels</span></span></div>
          <div class="wel-body">${dots(0)}<div class="wm">${h.brandIcon(28, 'tray', 'circle')}<b>TakeTray</b></div><h1>One tray for every take</h1><p>Film with your phone's camera as usual. New clips land in your tray, ready to sort into the reels you plan.</p></div>
          <div class="foot">${cta()}</div></div>`;
      },
    },
    day: {
      name: 'C · Your day',
      pitch: 'Oversized type tells the workflow in three verbs; a real shooting day underneath proves it. Minimal and editorial, with one accent colour.',
      render(s) {
        const rows = DAY.map((x) => `<li><span class="tm">${x.time}</span><span class="dot"></span><span class="stk">${x.takes.map((c) => `<img src="${thumb(c)}" alt="">`).join('')}</span><span class="dest"><span class="pill ready">${icon('video_library', 'fill')}${esc(x.reel)}</span><span class="n">${x.n} takes</span></span></li>`).join('');
        return `<div class="scr wel wel-day"><div class="wel-body" style="padding-top:28px"><div class="wm">${h.brandIcon(24, 'tray', 'circle')}<b>TakeTray</b></div>
            <h1 class="big"><em>Shoot</em> all day.<br><em>Tag</em> on the bus.<br><em>Edit</em> tonight.</h1>
            <ol class="dayline" aria-label="Example day: clips from each scene go into a reel">${rows}</ol>
            <p>TakeTray collects every clip you shoot with your normal camera, so the good take is never lost.</p></div>
          <div class="foot">${dots(0)}${cta()}</div></div>`;
      },
    },
    v1: { name: 'Previous (v1)', pitch: 'The first version, for comparison.', render: null },
  };

  RH.WELCOMES.v1.render = RH.routes['ob-welcome'];
  RH.welcomeChoice = 'tray'; // chosen 2026-10-23
  RH.routes['ob-welcome'] = (s, u) => {
    const w = RH.WELCOMES[u.p.v || RH.welcomeChoice] || RH.WELCOMES.slate;
    const out = w.render(s, u);
    return typeof out === 'string' ? { html: out, video: (u.p.v || RH.welcomeChoice) === 'slate' } : out;
  };
})();
