/* Mock data and formatting for the TakeTray prototype.
   Times are stored as local shooting time ("2026-10-12T13:05:10") plus a zone
   label, and are never converted: a London clip always shows London time. */
(function () {
  const RH = (window.RH = window.RH || {});
  const TODAY = '2026-10-12';
  RH.TODAY = TODAY;

  /* ------------------------------------------------------------------ */
  /* Formatting                                                          */
  /* ------------------------------------------------------------------ */
  const MON = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const DOW = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  function parse(iso) {
    const m = iso.match(/(\d+)-(\d+)-(\d+)(?:T(\d+):(\d+)(?::(\d+))?)?/);
    return { y: +m[1], mo: +m[2], d: +m[3], h: +(m[4] || 0), mi: +(m[5] || 0), s: +(m[6] || 0) };
  }
  const epochMin = (iso) => { const p = parse(iso); return Date.UTC(p.y, p.mo - 1, p.d, p.h, p.mi, p.s) / 60000; };
  const dateOf = (iso) => iso.slice(0, 10);
  const hm = (p) => `${((p.h + 11) % 12) + 1}:${String(p.mi).padStart(2, '0')}`;
  const ampm = (p) => (p.h < 12 ? 'am' : 'pm');
  const fmt = (RH.fmt = {
    time(iso) { const p = parse(iso); return `${hm(p)} ${ampm(p)}`; },
    range(a, b) {
      const pa = parse(a), pb = parse(b);
      if (epochMin(b) - epochMin(a) < 1) return fmt.time(a);
      return ampm(pa) === ampm(pb) ? `${hm(pa)}–${hm(pb)} ${ampm(pb)}` : `${fmt.time(a)}–${fmt.time(b)}`;
    },
    day(iso) { const p = parse(iso); return `${DOW[new Date(Date.UTC(p.y, p.mo - 1, p.d)).getUTCDay()]} ${p.d} ${MON[p.mo - 1]}`; },
    dayRel(iso) {
      const diff = Math.round((epochMin(TODAY) - epochMin(dateOf(iso))) / 1440);
      if (diff === 0) return `Today · ${fmt.day(iso)}`;
      if (diff === 1) return `Yesterday · ${fmt.day(iso)}`;
      return fmt.day(iso);
    },
    dateShort(iso) { const p = parse(iso); return `${p.d} ${MON[p.mo - 1]}`; },
    dur(sec) { sec = Math.round(sec); const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60; return h ? `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}` : `${m}:${String(s).padStart(2, '0')}`; },
    mins(sec) { if (sec < 60) return `${Math.round(sec)} s`; const m = Math.round(sec / 60); return m < 60 ? `${m} min` : `${Math.floor(m / 60)} h ${m % 60} min`; },
    size(mb) { return mb >= 1000 ? `${(mb / 1000).toFixed(1).replace(/\.0$/, '')} GB` : `${Math.round(mb)} MB`; },
    n(n, word, plural) { return `${n.toLocaleString('en-IN')} ${n === 1 ? word : plural || word + 's'}`; },
    fileName(iso) { return iso.replace('T', '_').replace(/:/g, '-') + '.mp4'; },
  });
  RH.parse = parse; RH.epochMin = epochMin; RH.dateOf = dateOf;

  /* ------------------------------------------------------------------ */
  /* Fixture builder                                                     */
  /* ------------------------------------------------------------------ */
  function seeded(seed) {
    let a = seed >>> 0;
    return () => { a = (a * 1664525 + 1013904223) >>> 0; return a / 4294967296; };
  }
  function addSec(iso, sec) {
    const p = parse(iso);
    const d = new Date(Date.UTC(p.y, p.mo - 1, p.d, p.h, p.mi, p.s) + sec * 1000);
    const z = (n) => String(n).padStart(2, '0');
    return `${d.getUTCFullYear()}-${z(d.getUTCMonth() + 1)}-${z(d.getUTCDate())}T${z(d.getUTCHours())}:${z(d.getUTCMinutes())}:${z(d.getUTCSeconds())}`;
  }
  RH.addSec = addSec;

  let uid = 0;
  /** Make a run of clips: themes cycle, times spread across `spanMin`. */
  function run(store, { start, themes, count, spanMin = 10, tz = 'BST', seed = 1, reels = [], folder = 'Camera', durs }) {
    const r = seeded(seed * 97 + count);
    const ids = [];
    const step = (spanMin * 60) / Math.max(1, count - 1);
    for (let i = 0; i < count; i++) {
      const id = 'c' + ++uid;
      const dur = durs ? durs[i % durs.length] : Math.round(5 + r() * 38);
      store.clips[id] = {
        id, theme: themes[i % themes.length], seed: seed * 31 + i * 7 + uid, orient: 'v',
        at: addSec(start, Math.round(i * step + r() * 20)), tz, dur, mb: Math.round(dur * 2.6 + 4),
        folder, missing: false, reels: reels.slice(),
      };
      ids.push(id);
    }
    return ids;
  }
  RH.run = run;

  RH.fixture = function () {
    uid = 0;
    const s = {
      today: TODAY, android: 14, access: 'full', notifPerm: true, onboarded: true,
      shooting: { on: true, since: TODAY + 'T09:12:00' },
      reels: [], clips: {}, toTag: [], skipped: [], lastTags: [],
      storageFreeMB: 6200,
      settings: { evening: true, eveningTime: '9:00 pm', shootingReminder: true, vnReminder: true, lastExport: '2026-10-08' },
      folders: [
        { id: 'camera', name: 'Camera', path: 'DCIM/Camera', count: 1284, watched: true, themes: ['street', 'food', 'river', 'selfie'] },
        { id: 'opencam', name: 'Open Camera', path: 'DCIM/OpenCamera', count: 42, watched: false, themes: ['night', 'sunset'] },
        { id: 'motioncam', name: 'MotionCam', path: 'DCIM/MotionCam', count: 17, watched: false, themes: ['river', 'park'] },
      ],
      browse: [
        { id: 'camera', name: 'Camera', count: 1284, themes: ['street', 'food', 'river', 'selfie'] },
        { id: 'whatsapp', name: 'WhatsApp Video', count: 312, themes: ['selfie', 'food', 'beach', 'festival'] },
        { id: 'download', name: 'Download', count: 46, themes: ['night', 'market', 'park', 'cafe'] },
        { id: 'quickshare', name: 'Quick Share', count: 18, themes: ['river', 'sunset', 'selfie', 'street'] },
        { id: 'instagram', name: 'Instagram', count: 25, themes: ['cafe', 'beach', 'food', 'sunset'] },
        { id: 'screen', name: 'Screen recordings', count: 9, themes: ['rain', 'night', 'park', 'market'] },
        { id: 'empty', name: 'Telegram Video', count: 0, themes: [] },
      ],
      notified: { evening: false, vn: false, still: false },
      editorsInstalled: { capcut: true, edits: true, vn: true },
      folderTipSeen: false,
    };

    const R = (id, name, status, created, desc) => {
      const reel = { id, name, status, created, desc: desc || '', vn: null };
      s.reels.push(reel);
      return reel;
    };
    R('r4', 'Diwali at Home', 'rec', '2026-10-11', 'Rangoli time-lapse from above. Lighting the diyas at dusk. Family sparklers in slow motion. Sweets close-ups: kaju katli, laddoo.');
    R('r3', 'Day 1 Vlog', 'ready', '2026-10-09', 'Landing at Heathrow, Tube ride, first walk along the Thames. Talk to camera at each stop.');
    R('r2', 'London Cinematic', 'rec', '2026-10-09', 'Golden hour on the Thames, Tower Bridge, slow pans, rain on café windows, night lights in Soho.');
    R('r1', 'London Food', 'rec', '2026-10-09', 'Indian food in London on a budget. Shots: Dishoom bacon naan close-up, Borough Market wide shot, first-bite reaction, price boards, walking B-roll.');
    R('r5', 'Café Hopping Bengaluru', 'ready', '2026-09-14', 'Five cafés in Indiranagar in one day. Pour-over close-ups, menu boards, my rating at the end.');
    R('r6', 'Goa Sunsets', 'pub', '2026-08-02', 'Sunset at Anjuna, Vagator and Palolem. Drone-style slow walks.');
    R('r7', 'Mumbai Street Food', 'pub', '2026-07-05', 'Vada pav, pav bhaji at Juhu, Mohammed Ali Road at night.');

    // London, Day 1 (Sat 10 Oct) and Day 2 (Sun 11 Oct)
    const vlogRiver = run(s, { start: '2026-10-10T08:55:00', themes: ['river'], count: 3, spanMin: 9, seed: 2, reels: ['r2', 'r3'] });
    s.clips[vlogRiver[1]].orient = 'h';
    run(s, { start: '2026-10-10T09:40:00', themes: ['food', 'cafe', 'food'], count: 4, spanMin: 12, seed: 3, reels: ['r1'] });
    run(s, { start: '2026-10-10T10:30:00', themes: ['selfie'], count: 5, spanMin: 30, seed: 4, reels: ['r3'] });
    const st = run(s, { start: '2026-10-10T11:20:00', themes: ['street'], count: 3, spanMin: 8, seed: 5, reels: ['r2', 'r3'] });
    s.clips[st[2]].missing = true;
    run(s, { start: '2026-10-10T13:30:00', themes: ['food', 'market', 'food'], count: 3, spanMin: 7, seed: 6, reels: ['r1', 'r3'] });
    run(s, { start: '2026-10-10T15:40:00', themes: ['rain'], count: 2, spanMin: 4, seed: 7, reels: ['r2'] });
    run(s, { start: '2026-10-11T10:15:00', themes: ['market', 'market', 'food', 'market', 'food'], count: 5, spanMin: 14, seed: 8, reels: ['r1'] });
    run(s, { start: '2026-10-11T12:00:00', themes: ['park'], count: 2, spanMin: 5, seed: 9, reels: ['r2'] });
    run(s, { start: '2026-10-11T16:10:00', themes: ['food'], count: 2, spanMin: 3, seed: 10, reels: ['r1'] });
    run(s, { start: '2026-10-11T18:30:00', themes: ['sunset'], count: 3, spanMin: 9, seed: 11, reels: ['r2'] });
    const ng = run(s, { start: '2026-10-11T20:10:00', themes: ['night'], count: 3, spanMin: 6, seed: 12, reels: ['r2'] });
    s.clips[ng[1]].missing = true;
    // VN copies for Day 1 Vlog
    const vlogIds = Object.values(s.clips).filter((c) => c.reels.includes('r3') && !c.missing).map((c) => c.id);
    s.reels.find((r) => r.id === 'r3').vn = { folder: 'Day 1 Vlog', copied: vlogIds.slice(), since: '2026-10-11' };

    run(s, { start: '2026-09-13T10:05:00', themes: ['cafe', 'cafe', 'food'], count: 9, spanMin: 300, seed: 13, reels: ['r5'], tz: 'IST' });
    run(s, { start: '2026-07-28T17:40:00', themes: ['beach', 'sunset', 'beach', 'selfie'], count: 22, spanMin: 2400, seed: 14, reels: ['r6'], tz: 'IST' });
    run(s, { start: '2026-07-03T18:00:00', themes: ['market', 'food', 'night', 'food'], count: 31, spanMin: 1500, seed: 15, reels: ['r7'], tz: 'IST' });

    // Skipped (accidental pocket shots, duplicates)
    s.skipped = run(s, { start: '2026-10-11T09:02:00', themes: ['street', 'park', 'selfie', 'rain', 'river', 'market'], count: 12, spanMin: 600, seed: 16 });

    // To tag: today (Mon 12 Oct), 23 clips in 4 scenes
    const t1 = run(s, { start: TODAY + 'T09:20:10', themes: ['food', 'cafe', 'food', 'market'], count: 4, spanMin: 11, seed: 21 });
    const t2 = run(s, { start: TODAY + 'T11:02:00', themes: ['river', 'river', 'selfie', 'river', 'selfie', 'river'], count: 6, spanMin: 8, seed: 22 });
    const t3 = run(s, { start: TODAY + 'T13:05:30', themes: ['street', 'market', 'street', 'food', 'market', 'street'], count: 6, spanMin: 15, seed: 23 });
    const t4 = run(s, { start: TODAY + 'T18:40:00', themes: ['sunset', 'sunset', 'selfie', 'sunset', 'night', 'sunset', 'night'], count: 7, spanMin: 18, seed: 24, durs: [14, 9, 22, 31, 272, 12, 18] });
    s.clips[t2[3]].orient = 'h';
    s.toTag = [...t1, ...t2, ...t3, ...t4];
    s.lastTags = [];
    return s;
  };

  /* ------------------------------------------------------------------ */
  /* Queries                                                             */
  /* ------------------------------------------------------------------ */
  RH.q = {
    reel: (s, id) => s.reels.find((r) => r.id === id),
    clipsOf(s, rid) { return Object.values(s.clips).filter((c) => c.reels.includes(rid)).sort((a, b) => (a.at < b.at ? -1 : 1)); },
    liveClipsOf(s, rid) { return RH.q.clipsOf(s, rid).filter((c) => !c.missing); },
    total(clips) { return clips.reduce((t, c) => t + c.dur, 0); },
    sizeOf(clips) { return clips.reduce((t, c) => t + c.mb, 0); },
    cover(s, rid) { const c = RH.q.liveClipsOf(s, rid)[0]; return c || null; },
    counts(s) {
      const c = { all: s.reels.length, rec: 0, ready: 0, pub: 0 };
      s.reels.forEach((r) => c[r.status]++);
      return c;
    },
    vnMB(s, reel) { return reel.vn ? reel.vn.copied.reduce((t, id) => t + (s.clips[id] ? s.clips[id].mb : 0), 0) : 0; },
    /** Clips shot close together (gap under 10 min, same day) form a scene. */
    scenes(s, ids) {
      const list = ids.map((id) => s.clips[id]).filter(Boolean).sort((a, b) => (a.at < b.at ? -1 : 1));
      const out = [];
      let cur = null;
      list.forEach((c) => {
        const end = cur && s.clips[cur.ids[cur.ids.length - 1]];
        const gap = end ? epochMin(c.at) - (epochMin(end.at) + end.dur / 60) : Infinity;
        if (!cur || gap >= 10 || dateOf(c.at) !== dateOf(end.at)) {
          cur = { day: dateOf(c.at), ids: [], start: c.at, end: c.at };
          out.push(cur);
        }
        cur.ids.push(c.id);
        cur.end = c.at;
      });
      return out;
    },
    days(clips) {
      const out = [];
      clips.forEach((c) => {
        const d = dateOf(c.at);
        if (!out.length || out[out.length - 1].day !== d) out.push({ day: d, clips: [] });
        out[out.length - 1].clips.push(c);
      });
      return out;
    },
    /** Reels for the tag player and pickers: Recording first, then the rest. */
    orderedReels(s) {
      const rank = { rec: 0, ready: 1, pub: 2 };
      return s.reels.slice().sort((a, b) => rank[a.status] - rank[b.status] || (a.created < b.created ? 1 : -1));
    },
    vnReels(s) { return s.reels.filter((r) => r.vn); },
    folderClips(s, folderId) {
      const f = s.browse.find((b) => b.id === folderId);
      if (!f || !f.count) return [];
      if (folderId === 'camera') {
        // Newest first: today's To tag clips and some reel clips appear here too.
        return Object.values(s.clips).filter((c) => c.folder === 'Camera' && c.tz === 'BST' && !c.missing).sort((a, b) => (a.at < b.at ? 1 : -1)).slice(0, 36);
      }
      const r = seeded(folderId.length * 13);
      const out = [];
      for (let i = 0; i < 18; i++) {
        const id = `f_${folderId}_${i}`;
        out.push(s.clips[id] || {
          id, theme: f.themes[i % f.themes.length], seed: 500 + i * 11 + folderId.length, orient: i % 7 === 3 ? 'h' : 'v',
          at: addSec('2026-10-12T08:00:00', -Math.round(i * 5400 + r() * 3000)), tz: 'BST', dur: Math.round(6 + r() * 50),
          mb: 0, folder: f.name, missing: false, reels: [], external: true,
        });
        out[i].mb = out[i].mb || Math.round(out[i].dur * (folderId === 'whatsapp' ? 0.6 : 2.4));
      }
      return out;
    },
  };

  /** Extra reels for the "20+ reels" state. */
  RH.manyReels = function (s) {
    const names = [
      ['Ladakh Bike Trip', 'pub', ['park', 'sunset']], ['Jaipur Pink City', 'pub', ['street', 'market']],
      ['Rishikesh Rafting', 'pub', ['river', 'selfie']], ['Pondicherry Cafés', 'pub', ['cafe', 'street']],
      ['Kerala Backwaters', 'pub', ['river', 'park']], ['Hampi Sunrise', 'pub', ['sunset', 'park']],
      ['Old Delhi Food Walk', 'pub', ['food', 'market']], ['Coorg Coffee Estate', 'ready', ['park', 'cafe']],
      ['Varanasi Ghats', 'pub', ['river', 'night']], ['Udaipur Lakes', 'pub', ['river', 'sunset']],
      ['Meghalaya Waterfalls', 'pub', ['park', 'rain']], ['Spiti Valley', 'ready', ['park', 'selfie']],
      ['Andaman Diving', 'pub', ['beach', 'selfie']], ['Kolkata Durga Puja', 'pub', ['festival', 'night']],
      ['Amritsar Golden Temple', 'pub', ['night', 'food']],
    ];
    names.forEach(([name, status, themes], i) => {
      const id = 'm' + i;
      const m = String(6 - Math.floor(i / 3)).padStart(2, '0');
      s.reels.push({ id, name, status, created: `2026-${m}-${String(20 - i).padStart(2, '0')}`, desc: '', vn: null });
      run(s, { start: `2026-${m}-${String(18 - i).padStart(2, '0')}T09:00:00`, themes, count: 4 + ((i * 5) % 14), spanMin: 600, seed: 40 + i, reels: [id], tz: 'IST' });
    });
    return s;
  };

  /** Lots of clips in one reel (100+) or in To tag. */
  RH.bulk = function (s, { reel, toTag, count }) {
    const themes = ['street', 'food', 'river', 'selfie', 'market', 'night', 'park', 'sunset', 'cafe', 'rain'];
    const per = Math.ceil(count / 6);
    const ids = [];
    for (let d = 0; d < 6; d++) {
      const day = String(5 + d).padStart(2, '0');
      ids.push(...run(s, { start: `2026-10-${day}T08:30:00`, themes: themes.slice(d % 4).concat(themes.slice(0, d % 4)), count: per, spanMin: 720, seed: 60 + d, reels: reel ? [reel] : [] }));
    }
    if (toTag) s.toTag = ids.slice(0, count);
    return ids.slice(0, count);
  };
})();
