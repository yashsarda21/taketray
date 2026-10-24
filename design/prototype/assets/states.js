/* Screen catalogue: every screen in section 7 of the design prompt, with every
   state it lists. Each state is a setup(s, u) that starts from a fresh fixture. */
(function () {
  const RH = (window.RH = window.RH || {});
  const { q } = RH;

  const go = (u, route, p = {}) => { u.route = route; u.p = p; };
  const player = (s, u, i, extra = {}) => {
    go(u, 'player');
    u.player = { session: s.toTag.slice(), i, multi: false, picked: [], muted: true, paused: false, tagged: {}, skippedN: 0, ...extra };
  };
  const tagFirst = (s, n, rid) => { s.toTag.slice(0, n).forEach((id) => { s.clips[id].reels.push(rid); }); s.toTag = s.toTag.slice(n); };
  const tag = (s, ids, rid) => { ids.forEach((id) => { s.clips[id].reels.push(rid); }); s.toTag = s.toTag.filter((id) => !ids.includes(id)); };
  const reelIds = (s, rid) => q.clipsOf(s, rid).map((c) => c.id);

  RH.SCREENS = [
    /* ---------------------------------------------------------- Onboarding */
    {
      n: 1, id: 'splash', title: 'Splash', group: 'Onboarding',
      notes: ['Android 12+ SplashScreen API: the TakeTray tray icon centred on brand violet; the wordmark is the optional branding image. Android 11 uses the SplashScreen compat library so it looks the same.', 'Stays only while the reel list loads (usually under half a second). No custom animation.'],
      states: [{ id: 'default', label: 'App launch', setup: (s, u) => go(u, 'splash') }],
    },
    {
      n: 2, id: 'welcome', title: 'Welcome', group: 'Onboarding',
      notes: ['Chosen: B · Tray. Real takes stand in the TakeTray tray, each tabbed with its reel; it explains the name and ties the welcome to the app icon. The other two directions are kept below for reference.', 'A · Slate leans on film-set language; it is dark in both themes, like the tag player.', 'B · Tray makes the brand object the hero and ties the welcome to the app icon.', 'C · Your day is typographic: three verbs, then a real shooting day as proof.', 'Each has one motion moment on load (the slate claps shut, the takes drop into the tray, the day rows appear in order). With reduced motion, the final frame shows straight away.', 'The previous version is kept at the end for comparison.'],
      spec: { Tap: 'Get started → Video access.', Back: 'Leaves the app (first screen).', 'Try them': 'In the prototype panel, "Welcome design" switches the option used by the onboarding flow.' },
      states: [
        { id: 'tray', label: `${RH.WELCOMES.tray.name} (chosen)`, desc: RH.WELCOMES.tray.pitch, setup: (s, u) => { s.onboarded = false; go(u, 'ob-welcome', { v: 'tray' }); } },
        { id: 'slate', label: `${RH.WELCOMES.slate.name} (not used)`, desc: RH.WELCOMES.slate.pitch, setup: (s, u) => { s.onboarded = false; go(u, 'ob-welcome', { v: 'slate' }); } },
        { id: 'day', label: `${RH.WELCOMES.day.name} (not used)`, desc: RH.WELCOMES.day.pitch, setup: (s, u) => { s.onboarded = false; go(u, 'ob-welcome', { v: 'day' }); } },
        { id: 'v1', label: RH.WELCOMES.v1.name, desc: RH.WELCOMES.v1.pitch, setup: (s, u) => { s.onboarded = false; go(u, 'ob-welcome', { v: 'v1' }); } },
      ],
    },
    {
      n: 3, id: 'video-access', title: 'Video access permission', group: 'Onboarding',
      notes: ['Explains why before Android asks. The button label tells people what to pick in the system dialog for their Android version.', 'Limited access and Deny both lead to Manual mode; the app stays usable and a banner offers full access later.', 'Copy never says "MediaStore" or "permission"; it says "see your videos".'],
      spec: { 'Android 11–12': 'READ_EXTERNAL_STORAGE dialog: Allow / Deny.', 'Android 13': 'READ_MEDIA_VIDEO dialog: Allow / Don\'t allow.', 'Android 14+': 'Allow all / Select photos and videos / Don\'t allow. "Select" = limited access = Manual mode.' },
      states: [
        { id: 'before', label: 'Before asking', setup: (s, u) => go(u, 'ob-video', { state: 'before' }) },
        { id: 'sys14', label: 'System dialog · Android 14+', desc: 'Drawn by Android, shown for reference.', setup: (s, u) => { go(u, 'ob-video', { state: 'before' }); u.sys = { type: 'video' }; } },
        { id: 'sys13', label: 'System dialog · Android 13', setup: (s, u) => { s.android = 13; go(u, 'ob-video', { state: 'before' }); u.sys = { type: 'video' }; } },
        { id: 'sys11', label: 'System dialog · Android 11–12', setup: (s, u) => { s.android = 11; go(u, 'ob-video', { state: 'before' }); u.sys = { type: 'video' }; } },
        { id: 'limited', label: 'Limited access chosen', setup: (s, u) => go(u, 'ob-video', { state: 'limited' }) },
        { id: 'denied', label: 'Denied', setup: (s, u) => go(u, 'ob-video', { state: 'denied' }) },
        { id: 'granted', label: 'Granted', desc: 'Moves on by itself after a second.', setup: (s, u) => go(u, 'ob-video', { state: 'granted' }) },
      ],
    },
    {
      n: 4, id: 'notifications', title: 'Notification permission', group: 'Onboarding',
      notes: ['Shown on Android 13+ only. On Android 11–12 notifications are allowed by default, so this step is skipped.', 'The preview card shows exactly what the notification looks like, so allowing it is an informed choice.', '"Not now" is equal-weight text, never hidden.'],
      states: [
        { id: 'before', label: 'Before asking', setup: (s, u) => go(u, 'ob-notif') },
        { id: 'sys', label: 'System dialog · Android 13+', setup: (s, u) => { go(u, 'ob-notif'); u.sys = { type: 'notif' }; } },
      ],
    },
    {
      n: 5, id: 'create-reels', title: 'Create your reels', group: 'Onboarding',
      notes: ['A one-line tip mentions sharing Instagram reels to TakeTray as references.', 'Fast multi-add: type a name, press Enter, type the next. The field keeps focus and the keyboard stays up.', 'Idea chips add common reels in one tap.', 'Skippable. Lands on Home with a tip pointing at Shooting mode.'],
      spec: { Enter: 'Adds the reel and clears the field.', 'Tap ×': 'Removes a reel from the list.', Done: 'Create N reels → Home, with the Shooting mode tip.' },
      states: [
        { id: 'empty', label: 'Empty', setup: (s, u) => go(u, 'ob-reels', { names: [] }) },
        { id: 'typing', label: 'Typing', setup: (s, u) => { go(u, 'ob-reels', { names: ['London Food'], draft: 'London Cinematic' }); u.kbd = true; } },
        { id: 'some', label: 'A few reels added', setup: (s, u) => go(u, 'ob-reels', { names: ['London Food', 'London Cinematic', 'Day 1 Vlog'] }) },
        { id: 'pre', label: 'A reel saved from a share is already listed', desc: 'The user shared an Instagram reel to TakeTray before setting it up. That reel was created then, so it is listed and ticked.', setup: (s, u) => { s.onboarded = false; s.reels = [{ id: 'p1', name: 'London Food', status: 'rec', created: RH.TODAY, desc: '', vn: null, pre: true, refs: [{ id: 'x1', url: 'https://www.instagram.com/reel/DBf2kQ9sLmA/', label: '', added: RH.TODAY }] }]; go(u, 'ob-reels', { names: ['Day 1 Vlog'] }); } },
      ],
    },

    /* ------------------------------------------------------ Home and reels */
    {
      n: 6, id: 'home', title: 'Home (Reels)', group: 'Home and reels',
      notes: ['The Shooting mode card is the first thing on Home: a soft grey card when off, a solid block in the brand colour with a live REC dot when on.', 'When clips are waiting and Shooting mode is on, the To tag banner joins the card as a strip in the "clips waiting" colour. When it is off, the banner stands alone.', 'Reel cards in two columns so covers (videos) lead. Status is an icon + word, never colour alone.', 'Extended "New reel" button sits in the thumb zone above the navigation bar.', 'References: when Shooting mode is on and any Recording reel has references, the card gets a "References · 4" row that opens the References sheet. A small link badge on a reel card (top-right of the cover) jumps to that reel\'s References section.'],
      spec: { 'Tap card': 'Opens Reel detail (container transform).', 'Tap switch': 'Shooting mode on/off. Turning on stamps "On since" time.', 'Tap strip': 'Opens To tag.', Filter: 'Single-select chips with counts; empty filter shows a reset.' },
      states: [
        { id: 'on', label: 'Shooting mode on, clips waiting, references', desc: '"References · 4" collects the references of every Recording reel. Reel cards with references show a small link badge.', setup: () => {} },
        { id: 'off', label: 'Shooting mode off', setup: (s) => { s.shooting.on = false; s.toTag = []; } },
        { id: 'waiting', label: 'Off, but clips still waiting', setup: (s) => { s.shooting.on = false; } },
        { id: 'tip', label: 'First visit: Shooting mode tip', setup: (s, u) => { s.shooting.on = false; s.toTag = []; u.hint = 'shoot'; } },
        { id: 'empty', label: 'First time, no reels', setup: (s) => { s.reels = []; s.shooting.on = false; s.toTag = []; Object.values(s.clips).forEach((c) => { c.reels = []; }); } },
        { id: 'filter-empty', label: 'Filter with no results', setup: (s, u) => { s.reels.forEach((r) => { if (r.status === 'pub') r.status = 'ready'; }); u.filter = 'pub'; } },
        { id: 'many', label: '20+ reels', setup: (s, u) => { RH.manyReels(s); s.shooting.on = false; s.toTag = []; u.p.scrollHint = true; } },
        { id: 'manual', label: 'Manual mode (limited access)', setup: (s) => { s.access = 'limited'; } },
      ],
    },
    {
      n: 7, id: 'reel-form', title: 'Create / edit reel', group: 'Home and reels',
      notes: ['Bottom sheet: quick to open and dismiss, keeps context.', 'Name is required (max 40, counter shown). Errors appear under the field as you save, and focus moves back to it.', '"Shot ideas" is the one description field: concept, shots to get, songs to try.', 'Status shows only when editing; new reels start as Recording.', 'Optional "Reference link" field: paste an Instagram reel (or any link) to save it with the reel. More references are managed on the reel page.'],
      states: [
        { id: 'new', label: 'New reel', setup: (s, u) => { u.sheet = { type: 'reelForm', mode: 'new', name: '' }; u.kbd = true; } },
        { id: 'filled', label: 'Filled in', setup: (s, u) => { u.sheet = { type: 'reelForm', mode: 'new', name: 'Thames Night Walk', desc: 'Tower Bridge lit up, slow pan from the river path, street musician.', focus: 'desc' }; } },
        { id: 'ref', label: 'With a reference link', setup: (s, u) => { u.sheet = { type: 'reelForm', mode: 'new', name: 'Borough Market Eats', ref: 'https://www.instagram.com/reel/DA3kP0sxYz1/', desc: '' }; } },
        { id: 'ref-err', label: 'Error: reference is not a link', setup: (s, u) => { u.sheet = { type: 'reelForm', mode: 'new', name: 'Borough Market Eats', ref: 'dishoom bacon naan reel', refErr: "That isn't a link. Leave it empty, or paste a reel's link." }; } },
        { id: 'err-empty', label: 'Error: empty name', setup: (s, u) => { u.sheet = { type: 'reelForm', mode: 'new', name: '', err: 'Give this reel a name' }; } },
        { id: 'err-dup', label: 'Error: duplicate name', setup: (s, u) => { u.sheet = { type: 'reelForm', mode: 'new', name: 'London Food', err: 'You already have a reel called London Food' }; } },
        { id: 'edit', label: 'Edit details (with status)', setup: (s, u) => { go(u, 'reel', { id: 'r1' }); const r = q.reel(s, 'r1'); u.sheet = { type: 'reelForm', mode: 'edit', id: 'r1', name: r.name, desc: r.desc, status: r.status }; } },
      ],
    },
    {
      n: 8, id: 'reel-detail', title: 'Reel detail', group: 'Home and reels',
      notes: ['Clips oldest first, grouped by day ("Day 1 · Sat 10 Oct"), counting from the reel\'s first clip.', 'Primary action "Edit video" floats bottom-right in the thumb zone. "Reel details" (rename, shot ideas, status) is in the menu, so the two "edit"s never collide.', 'Badges on tiles: "layers 2" = in 2 reels; landscape icon = horizontal video; dashed grey tile = missing.', 'Status pill is the status control: tap it to change.', 'References sit right under Shot ideas, above the clips: one card per reference with its source, label (or the link) and Open. The ⋮ menu has Edit label, Copy link and Remove (Undo, no dialog).'],
      spec: { 'Tap tile': 'Full-screen viewer at that clip.', 'Long-press tile': 'Selection mode (Add to / Move / Remove / Edit).', 'Tap status': 'Status menu.', 'Remove (missing)': 'Removes the placeholder, with Undo.' },
      states: [
        { id: 'normal', label: 'Normal', setup: (s, u) => go(u, 'reel', { id: 'r1' }) },
        { id: 'desc', label: 'Shot ideas expanded', setup: (s, u) => go(u, 'reel', { id: 'r1', descOpen: true }) },
        { id: 'vn', label: 'Editing in VN', setup: (s, u) => go(u, 'reel', { id: 'r3' }) },
        { id: 'missing', label: 'Contains missing clips', setup: (s, u) => go(u, 'reel', { id: 'r2' }) },
        { id: 'empty', label: 'Empty reel', setup: (s, u) => go(u, 'reel', { id: 'r4' }) },
        { id: 'select', label: 'Selection mode', setup: (s, u) => { go(u, 'reel', { id: 'r1' }); const ids = reelIds(s, 'r1'); u.sel = { ctx: 'reel', ids: [ids[1], ids[2], ids[5]] }; } },
        { id: 'many', label: '100+ clips', setup: (s, u) => { RH.bulk(s, { reel: 'r1', count: 120 }); go(u, 'reel', { id: 'r1' }); } },
        { id: 'loading', label: 'Loading thumbnails', setup: (s, u) => go(u, 'reel', { id: 'r1', loading: true }) },
        { id: 'refs-none', label: 'References: none yet', desc: 'A single compact row, not an empty block.', setup: (s, u) => go(u, 'reel', { id: 'r5' }) },
        { id: 'refs-one', label: 'References: one', setup: (s, u) => go(u, 'reel', { id: 'r2' }) },
        { id: 'refs-prompt', label: 'References but no shot ideas', desc: 'A gentle prompt to write the shots, right under the references.', setup: (s, u) => { q.reel(s, 'r2').desc = ''; go(u, 'reel', { id: 'r2' }); } },
        { id: 'refs-menu', label: 'Reference menu', setup: (s, u) => { go(u, 'reel', { id: 'r1' }); u.menu = { type: 'refMenu', rid: 'r1', ref: 'ref1', top: 372 }; } },
        { id: 'refs-removed', label: 'Reference removed, with Undo', setup: (s, u) => { const r = q.reel(s, 'r1'); r.refs = r.refs.slice(1); go(u, 'reel', { id: 'r1' }); u.snack = { text: 'Reference removed', undo: true }; } },
        { id: 'refs-jump', label: 'Opened from the Home badge', desc: 'The References section is scrolled into view and highlighted for a moment.', setup: (s, u) => go(u, 'reel', { id: 'r1', focus: 'refs' }) },
      ],
    },
    {
      n: 9, id: 'delete-reel', title: 'Delete reel confirmation', group: 'Home and reels',
      notes: ['The reassurance comes first, in a green "safe" box: videos stay in the gallery.', 'If VN copies exist, the dialog says they go too, with the size.', 'After deleting: back to Home with "London Food deleted · Undo".'],
      states: [
        { id: 'default', label: 'Delete reel', setup: (s, u) => { go(u, 'reel', { id: 'r1' }); u.dialog = { type: 'deleteReel', id: 'r1' }; } },
        { id: 'vn', label: 'With VN copies', setup: (s, u) => { go(u, 'reel', { id: 'r3' }); u.dialog = { type: 'deleteReel', id: 'r3' }; } },
      ],
    },
    {
      n: 10, id: 'status', title: 'Status change', group: 'Home and reels',
      notes: ['Menu from the status pill, with a one-line meaning for each status.', 'The app suggests a status at natural moments and never forces it: after Done editing ("Mark as Published?") and after sending to CapCut or Edits ("Mark as Ready to edit?").'],
      states: [
        { id: 'menu', label: 'Status menu', setup: (s, u) => { go(u, 'reel', { id: 'r1' }); u.menu = { type: 'status', id: 'r1' }; } },
        { id: 'pub', label: 'Mark as Published? (after Done editing)', setup: (s, u) => { q.reel(s, 'r3').vn = null; go(u, 'reel', { id: 'r3' }); u.dialog = { type: 'markStatus', id: 'r3', status: 'pub' }; } },
        { id: 'ready', label: 'Mark as Ready to edit? (after CapCut)', setup: (s, u) => { go(u, 'reel', { id: 'r1' }); u.dialog = { type: 'markStatus', id: 'r1', status: 'ready' }; } },
      ],
    },

    /* ------------------------------------------------------------- Tagging */
    {
      n: 11, id: 'to-tag', title: 'To tag list', group: 'Tagging',
      notes: ['"Start tagging" plays every clip in order with auto-advance: the fastest path, one tap per clip.', 'Scenes (clips under 10 minutes apart) have a header with time range, count and length, and a "Tag scene" button for one-tap tagging of the group.', 'Shooting mode status sits at the top, with Open camera.', 'Skipped (N) is a quiet text button; Skip all is in the menu, with confirmation and Undo.'],
      spec: { 'Tap tile': 'Tag player at that clip.', 'Long-press tile': 'Selection mode: Tag (reel picker) or Skip.', 'Tag scene': 'Reel picker for the whole scene.', 'Start tagging': 'Tag player from the first clip.' },
      states: [
        { id: 'few', label: 'Clips waiting', setup: (s, u) => go(u, 'totag') },
        { id: 'select', label: 'Multi-select', setup: (s, u) => { go(u, 'totag'); u.sel = { ctx: 'totag', ids: s.toTag.slice(4, 7) }; } },
        { id: 'one', label: 'One scene', setup: (s, u) => { s.toTag = s.toTag.slice(10, 16); go(u, 'totag'); } },
        { id: 'many', label: '100+ clips', setup: (s, u) => { RH.bulk(s, { toTag: true, count: 112 }); s.shooting.on = false; go(u, 'totag'); } },
        { id: 'loading', label: 'Loading thumbnails', setup: (s, u) => go(u, 'totag', { loading: true }) },
        { id: 'off', label: 'Empty, Shooting mode off', setup: (s, u) => { s.toTag = []; s.shooting.on = false; go(u, 'totag'); } },
        { id: 'caught', label: 'All caught up', setup: (s, u) => { s.toTag = []; go(u, 'totag'); } },
      ],
    },
    {
      n: 12, id: 'tag-player', title: 'Tag player', group: 'Tagging',
      notes: ['Always dark, on black, whatever the app theme: the video is the hero and it reads in sunlight.', 'One tap on a reel = tag + auto-advance. The chip fills violet with a tick (150 ms), holds 250 ms, then the next clip slides in from the right.', 'Several reels: tap "Pick several". Chips turn into checkboxes and a big "Add to 2 reels & next" button appears. Long-pressing a chip is a shortcut into the same mode. It switches back to one-tap after each clip.', '"Same as previous" repeats the last clip\'s reel(s) and advances.', 'Recording reels show first. Other reels stay folded under "Other reels (4)" so the video keeps most of the screen.', 'Muted by default; Skip and arrows move without tagging. Horizontal swipe on the video does the same (system back-gesture edges excluded).'],
      spec: { 'Tap chip': 'Tag into that reel, confirm, advance. Snackbar "Added to London Food · Undo".', 'Long-press chip': 'Enter Pick several with that chip ticked.', 'Swipe on video': 'Previous / next clip without tagging.', 'Tap video': 'Play / pause.', Haptic: 'CONFIRM on tag, REJECT on Skip.' },
      states: [
        { id: 'first', label: 'First clip', setup: (s, u) => player(s, u, 0) },
        { id: 'tagged', label: 'Middle of a scene, just tagged', setup: (s, u) => { const sess = s.toTag.slice(); tagFirst(s, 4, 'r1'); tag(s, sess.slice(4, 6), 'r2'); s.lastTags = ['r2']; player(s, u, 6, { session: sess, tagged: { r1: 4, r2: 2 } }); u.snack = { text: 'Added to London Cinematic', undo: true, ic: 'check_circle' }; } },
        { id: 'confirm', label: 'Tap-and-advance moment', desc: 'The chip confirms before the next clip slides in.', setup: (s, u) => { const sess = s.toTag.slice(); player(s, u, 1, { session: sess, confirm: 'r1' }); } },
        { id: 'multi', label: 'Picking several reels', setup: (s, u) => { const sess = s.toTag.slice(); tagFirst(s, 2, 'r1'); s.lastTags = ['r1']; player(s, u, 2, { session: sess, multi: true, picked: ['r1', 'r3'] }); u.otherOpen = true; } },
        { id: 'loading', label: 'Video still loading', setup: (s, u) => player(s, u, 4, { loading: true }) },
        { id: 'long', label: 'Very long clip (scrubbing)', setup: (s, u) => { const sess = s.toTag.slice(); player(s, u, sess.length - 3, { session: sess }); s.lastTags = ['r2']; } },
        { id: 'horizontal', label: 'Horizontal video', setup: (s, u) => { const sess = s.toTag.slice(); player(s, u, 7, { session: sess }); s.lastTags = ['r2']; } },
        { id: 'noreels', label: 'No reels yet', setup: (s, u) => { s.reels = []; Object.values(s.clips).forEach((c) => { c.reels = []; }); player(s, u, 0); } },
        { id: 'newreel', label: 'New reel on the spot', setup: (s, u) => { player(s, u, 0); u.sheet = { type: 'reelForm', mode: 'new', from: 'player', name: 'Borough Mar' }; u.kbd = true; } },
        { id: 'done', label: 'Last clip done: "All done!"', setup: (s, u) => { const sess = s.toTag.slice(); tag(s, sess.slice(0, 9), 'r1'); tag(s, sess.slice(9, 20), 'r2'); s.skipped = s.skipped.concat(sess.slice(20)); s.toTag = []; u.route = 'player'; u.player = { session: sess, i: sess.length - 1, done: true, tagged: { r1: 9, r2: 11 }, skippedN: 3 }; } },
      ],
    },
    {
      n: 13, id: 'reel-picker', title: 'Reel picker sheet', group: 'Tagging',
      notes: ['One component for Tag scene, multi-select Tag, Add to reel and Move to reel.', 'Recording reels first. Checkboxes when several are allowed; radio buttons for Move (one reel only).', 'The confirm button says exactly what happens: "Tag 6 clips", "Tag into 2 reels", "Move".', '"New reel" expands into a field right in the sheet.'],
      states: [
        { id: 'scene', label: 'Tag scene (multi-select)', setup: (s, u) => { go(u, 'totag'); u.sheet = { type: 'picker', mode: 'tag', ids: s.toTag.slice(10, 16), picked: ['r1', 'r2'] }; } },
        { id: 'move', label: 'Move to reel (single)', setup: (s, u) => { go(u, 'reel', { id: 'r1' }); u.sheet = { type: 'picker', mode: 'move', ids: [reelIds(s, 'r1')[0]], exclude: 'r1', picked: ['r2'] }; } },
        { id: 'add', label: 'Add to reel', setup: (s, u) => { go(u, 'reel', { id: 'r1' }); u.sheet = { type: 'picker', mode: 'add', ids: [reelIds(s, 'r1')[0]], exclude: 'r1', picked: [] }; } },
        { id: 'new', label: 'New reel inline', setup: (s, u) => { go(u, 'totag'); u.sheet = { type: 'picker', mode: 'tag', ids: s.toTag.slice(0, 4), picked: [], newOpen: true, newName: 'Breakfast Spots' }; u.kbd = true; } },
      ],
    },
    {
      n: 14, id: 'skip-all', title: 'Skip all + Undo', group: 'Tagging',
      notes: ['Skipping is reversible (Skipped list), so it is a plain action with Undo, not red.', 'The snackbar stays 6 seconds (longer than usual) because it undoes a bulk action.'],
      states: [
        { id: 'confirm', label: 'Confirmation', setup: (s, u) => { go(u, 'totag'); u.dialog = { type: 'skipAll' }; } },
        { id: 'undo', label: 'Undo snackbar', setup: (s, u) => { s.skipped = s.skipped.concat(s.toTag); s.toTag = []; go(u, 'totag'); u.snack = { text: '23 clips skipped', undo: true }; } },
      ],
    },
    {
      n: 15, id: 'skipped', title: 'Skipped list', group: 'Tagging',
      notes: ['Tap a clip to restore it straight away, or Select for several.', 'The note says skipped clips are still in the gallery.'],
      states: [
        { id: 'grid', label: 'Skipped clips', setup: (s, u) => go(u, 'skipped') },
        { id: 'select', label: 'Multi-select', setup: (s, u) => { go(u, 'skipped'); u.sel = { ctx: 'skipped', ids: s.skipped.slice(9, 12) }; } },
        { id: 'empty', label: 'Empty', setup: (s, u) => { s.skipped = []; go(u, 'skipped'); } },
      ],
    },

    /* --------------------------------------------------------------- Clips */
    {
      n: 16, id: 'viewer', title: 'Full-screen clip viewer', group: 'Clips',
      notes: ['Always dark. Swipe left/right or use the arrows to move between clips in this reel.', 'Shows which reels the clip is in; actions sit in the thumb zone.', 'Remove from this reel: snackbar "Removed from London Food. The video is still in your gallery." with Undo. If it was the clip\'s last reel, it leaves the app (it does not go back to To tag).'],
      states: [
        { id: 'v', label: 'Vertical video', setup: (s, u) => { const ids = reelIds(s, 'r3'); go(u, 'viewer', { reel: 'r3', id: ids[5], list: ids }); } },
        { id: 'h', label: 'Horizontal video', setup: (s, u) => { const ids = reelIds(s, 'r2'); go(u, 'viewer', { reel: 'r2', id: ids[1], list: ids }); } },
        { id: 'add', label: 'Add to another reel', setup: (s, u) => { const ids = reelIds(s, 'r1'); go(u, 'viewer', { reel: 'r1', id: ids[2], list: ids }); u.sheet = { type: 'picker', mode: 'add', ids: [ids[2]], exclude: 'r1', picked: ['r2'] }; } },
        { id: 'removed', label: 'Removed, with Undo', setup: (s, u) => { const ids = reelIds(s, 'r1'); go(u, 'reel', { id: 'r1' }); u.snack = { text: 'Removed from London Food. The video is still in your gallery.', undo: true }; } },
        { id: 'err', label: "Video can't play", setup: (s, u) => { const ids = reelIds(s, 'r1'); go(u, 'viewer', { reel: 'r1', id: ids[3], list: ids, err: true }); } },
      ],
    },
    {
      n: 17, id: 'add-videos', title: 'Add videos: folder browser', group: 'Clips',
      notes: ['Folders show a 2×2 preview, name and video count. WhatsApp Video, Download and Quick Share are where friends\' clips land.', 'Videos already in this reel or in To tag are marked and can\'t be picked again.', 'In Manual mode this browser is replaced by Android\'s photo picker, after a short explanation.', 'The quality tip shows once.'],
      states: [
        { id: 'folders', label: 'Folders (with one-time tip)', setup: (s, u) => go(u, 'add-folders', { target: { kind: 'reel', id: 'r1' } }) },
        { id: 'grid', label: 'Video grid, some picked', setup: (s, u) => { go(u, 'add-grid', { target: { kind: 'reel', id: 'r1' }, folder: 'camera' }); const c = q.folderClips(s, 'camera').filter((x) => !x.reels.includes('r1') && !s.toTag.includes(x.id) && !x.reels.length); u.sel = { ctx: 'add', ids: c.slice(0, 2).map((x) => x.id) }; } },
        { id: 'whatsapp', label: "Friends' videos (WhatsApp)", setup: (s, u) => { go(u, 'add-grid', { target: { kind: 'totag' }, folder: 'whatsapp' }); const c = q.folderClips(s, 'whatsapp'); u.sel = { ctx: 'add', ids: [c[0].id, c[1].id, c[4].id] }; } },
        { id: 'empty', label: 'Empty folder', setup: (s, u) => go(u, 'add-grid', { target: { kind: 'totag' }, folder: 'empty' }) },
        { id: 'manual', label: 'Manual mode: before the photo picker', setup: (s, u) => { s.access = 'limited'; go(u, 'totag'); u.sheet = { type: 'manualPick' }; } },
      ],
    },

    /* ------------------------------------------------------------ Editors */
    {
      n: 18, id: 'edit-select', title: 'Clip selection for Edit', group: 'Sending to editors',
      notes: ['All clips start unselected, with Select all in the top bar.', 'The bottom bar shows count, total length and size, so the VN space check is never a surprise.', 'Adding to an existing VN folder: copied clips are marked "In VN folder" and stay ticked; only new clips are copied, and nothing is renamed.'],
      states: [
        { id: 'none', label: 'Nothing picked yet', setup: (s, u) => { go(u, 'edit-select', { id: 'r1' }); u.sel = { ctx: 'edit', ids: [] }; } },
        { id: 'some', label: 'Clips picked', setup: (s, u) => { go(u, 'edit-select', { id: 'r1' }); const ids = q.liveClipsOf(s, 'r1').map((c) => c.id); u.sel = { ctx: 'edit', ids: [ids[0], ids[1], ids[3], ids[4], ids[7], ids[8], ids[9]] }; } },
        { id: 'vnadd', label: 'Add more clips to VN folder', setup: (s, u) => { const r = q.reel(s, 'r3'); const extra = RH.run(s, { start: '2026-10-10T19:30:00', themes: ['night', 'selfie'], count: 3, spanMin: 9, seed: 90, reels: ['r3'] }); go(u, 'edit-select', { id: 'r3', vnAdd: true }); u.sel = { ctx: 'edit', ids: r.vn.copied.concat(extra.slice(0, 2)) }; } },
      ],
    },
    {
      n: 19, id: 'choose-editor', title: 'Choose editor sheet', group: 'Sending to editors',
      notes: ['Only CapCut, Instagram Edits and VN, plus "Other app…" for the Android share menu.', 'Editors that aren\'t installed are greyed out with "Not installed", so the list never changes shape.', 'Real app icons come from the system at runtime; the prototype shows labelled placeholders.'],
      states: [
        { id: 'all', label: 'All installed', setup: (s, u) => { go(u, 'edit-select', { id: 'r1' }); const ids = q.liveClipsOf(s, 'r1').map((c) => c.id).slice(0, 12); u.sel = { ctx: 'edit', ids }; u.sheet = { type: 'editor', id: 'r1', ids }; } },
        { id: 'missing', label: 'CapCut not installed', setup: (s, u) => { s.editorsInstalled.capcut = false; go(u, 'edit-select', { id: 'r1' }); const ids = q.liveClipsOf(s, 'r1').map((c) => c.id).slice(0, 12); u.sel = { ctx: 'edit', ids }; u.sheet = { type: 'editor', id: 'r1', ids }; } },
        { id: 'share', label: 'Other app: share menu', setup: (s, u) => { go(u, 'edit-select', { id: 'r1' }); u.sel = { ctx: 'edit', ids: q.liveClipsOf(s, 'r1').map((c) => c.id).slice(0, 5) }; u.sheet = { type: 'share', n: 5 }; } },
      ],
    },
    {
      n: 20, id: 'vn-space', title: 'VN: space check', group: 'Sending to editors',
      notes: ['A storage bar shows used, needed and free space; numbers are spelled out too.', 'Explains why copies are made and that they are temporary.', 'Not enough space: a hatched red segment shows the shortfall, and the main action becomes "Select fewer clips".'],
      states: [
        { id: 'ok', label: 'Enough space', setup: (s, u) => { const ids = q.liveClipsOf(s, 'r1').map((c) => c.id).slice(0, 12); go(u, 'vn-space', { id: 'r1', ids, needMB: 900, freeMB: 6200 }); } },
        { id: 'low', label: 'Not enough space', setup: (s, u) => { const ids = q.liveClipsOf(s, 'r1').map((c) => c.id); go(u, 'vn-space', { id: 'r1', ids, needMB: 2400, freeMB: 1100 }); } },
      ],
    },
    {
      n: 21, id: 'vn-copying', title: 'VN: copying progress', group: 'Sending to editors',
      notes: ['Determinate progress with clip count and MB. Copying continues if the user leaves the app (foreground service with a progress notification while copying only).', 'Cancel asks first, because it deletes the copies made so far.'],
      states: [
        { id: 'progress', label: 'Copying', setup: (s, u) => { const ids = q.liveClipsOf(s, 'r1').map((c) => c.id).slice(0, 12); go(u, 'vn-copy', { id: 'r1', ids, done: 7 }); } },
        { id: 'cancel', label: 'Cancel confirmation', setup: (s, u) => { const ids = q.liveClipsOf(s, 'r1').map((c) => c.id).slice(0, 12); go(u, 'vn-copy', { id: 'r1', ids, done: 7 }); u.dialog = { type: 'stopCopy' }; } },
        { id: 'space', label: 'Ran out of space', setup: (s, u) => { const ids = q.liveClipsOf(s, 'r1').map((c) => c.id).slice(0, 12); go(u, 'vn-copy', { id: 'r1', ids, done: 7, fail: 'space' }); } },
        { id: 'error', label: 'A clip failed to copy', setup: (s, u) => { const ids = q.liveClipsOf(s, 'r1').map((c) => c.id).slice(0, 12); go(u, 'vn-copy', { id: 'r1', ids, done: 12, fail: 'error' }); } },
      ],
    },
    {
      n: 22, id: 'vn-ready', title: 'VN: ready and instructions', group: 'Sending to editors',
      notes: ['Three illustrated steps that mirror what the user sees in VN, with the real folder name highlighted.', 'The folder name always shows the real folder, even if the reel was renamed after copying.'],
      states: [{ id: 'default', label: 'Ready for VN', setup: (s, u) => { q.reel(s, 'r1').vn = { folder: 'London Food', copied: q.liveClipsOf(s, 'r1').map((c) => c.id).slice(0, 12), since: '2026-10-12' }; go(u, 'vn-ready', { id: 'r1' }); } }],
    },
    {
      n: 23, id: 'done-editing', title: 'Done editing', group: 'Sending to editors',
      notes: ['The question is "Have you exported your video?", because the copies can\'t come back into the same VN project.', 'After deleting: snackbar "Copies deleted · 900 MB freed", then the "Mark as Published?" suggestion.', 'Reminder notification after 3 days if the user forgets.'],
      states: [
        { id: 'confirm', label: 'Confirmation', setup: (s, u) => { go(u, 'reel', { id: 'r3' }); u.dialog = { type: 'doneEditing', id: 'r3' }; } },
        { id: 'after', label: 'After: copies deleted', setup: (s, u) => { const mb = q.vnMB(s, q.reel(s, 'r3')); q.reel(s, 'r3').vn = null; go(u, 'reel', { id: 'r3' }); u.snack = { text: `Copies deleted · ${RH.fmt.size(mb)} freed`, ic: 'check_circle' }; } },
      ],
    },

    /* --------------------------------------------------- Settings and help */
    {
      n: 24, id: 'settings', title: 'Settings home', group: 'Settings and help',
      notes: ['Grouped by what people want to do, not by system feature.', 'Permissions show their state and a fix button when something is off.', 'Privacy promise in plain words: "Your videos never leave your phone".'],
      states: [
        { id: 'default', label: 'Everything allowed', setup: (s, u) => go(u, 'settings') },
        { id: 'manual', label: 'Manual mode', setup: (s, u) => { s.access = 'limited'; s.notifPerm = false; go(u, 'settings'); } },
      ],
    },
    { n: 25, id: 'watched', title: 'Watched folders', group: 'Settings and help', notes: ['Camera is on by default. Pro camera apps save elsewhere, so they can be switched on here.', 'Each folder shows its path and video count.'], states: [{ id: 'default', label: 'Watched folders', setup: (s, u) => go(u, 'watched') }] },
    {
      n: 26, id: 'vn-storage', title: 'Storage used by VN copies', group: 'Settings and help',
      notes: ['Total first, then each reel with its copies, size and date.', 'Delete uses the same "Have you exported?" warning as Done editing.'],
      states: [
        { id: 'copies', label: 'With copies', setup: (s, u) => { q.reel(s, 'r5').vn = { folder: 'Café Hopping Bengaluru', copied: q.liveClipsOf(s, 'r5').map((c) => c.id), since: '2026-09-20' }; go(u, 'vn-storage'); } },
        { id: 'empty', label: 'No copies', setup: (s, u) => { s.reels.forEach((r) => { r.vn = null; }); go(u, 'vn-storage'); } },
      ],
    },
    { n: 27, id: 'notif-help', title: 'Notifications not arriving?', group: 'Settings and help', notes: ['Reassurance first: clips are never lost.', 'Per-brand steps, with the user\'s own brand opened and labelled "Your phone" (from Build.MANUFACTURER).', 'Buttons open the closest settings screen the phone allows.'], states: [{ id: 'default', label: 'Help (Samsung opened)', setup: (s, u) => go(u, 'notif-help') }, { id: 'xiaomi', label: 'Xiaomi steps', setup: (s, u) => go(u, 'notif-help', { open: 'xiaomi' }) }] },
    {
      n: 28, id: 'backup', title: 'Export / import data', group: 'Settings and help',
      notes: ['Says plainly that videos are not in the backup.', 'Import replaces everything, after a warning, then reports how many clips were found.', 'States that moving to a new phone isn\'t supported in version 1.'],
      states: [
        { id: 'default', label: 'Export and import', setup: (s, u) => go(u, 'backup') },
        { id: 'warn', label: 'Import warning', setup: (s, u) => { go(u, 'backup'); u.dialog = { type: 'importWarn' }; } },
        { id: 'done', label: 'Import summary', setup: (s, u) => { go(u, 'backup'); u.dialog = { type: 'importDone' }; } },
      ],
    },
    {
      n: 29, id: 'permission', title: 'Permission problem', group: 'Settings and help',
      notes: ['Shown wherever it matters if Android removed video access (for example after months unused) or it was changed to limited.', 'Full screen at launch when access is gone completely; a banner otherwise. The app stays usable in Manual mode.'],
      states: [
        { id: 'full', label: 'Access removed: full screen', setup: (s, u) => { s.access = 'removed'; go(u, 'perm-lost'); } },
        { id: 'banner', label: 'Access removed: banner on Home', setup: (s) => { s.access = 'removed'; } },
        { id: 'limited', label: 'Limited: banner on To tag', setup: (s, u) => { s.access = 'limited'; go(u, 'totag'); } },
      ],
    },

    /* ------------------------------------------------------- Notifications */
    {
      n: 30, id: 'notif-new', title: 'Notification: new clips', group: 'Notifications',
      notes: ['One notification that updates in place ("5 new clips" becomes "12 new clips"), silent, no vibration after the first. Channel: "New clips", importance LOW.', 'Expanded view shows up to 4 thumbnails and "+N".', 'Tap → To tag. Action: Open camera.', 'Best effort: it appears when the app notices new videos (on open, or via a content observer/WorkManager trigger); there is no permanent notification.'],
      states: [
        { id: 'collapsed', label: 'In the shade', setup: (s, u) => { u.shade = { items: ['new'] }; } },
        { id: 'expanded', label: 'Expanded with thumbnails', setup: (s, u) => { u.shade = { items: ['new'], expanded: 'new', newCount: 5 }; } },
        { id: 'updated', label: 'Updated in place', setup: (s, u) => { u.shade = { items: ['new'], expanded: 'new', newCount: 12 }; } },
      ],
    },
    { n: 31, id: 'notif-evening', title: 'Notification: evening reminder', group: 'Notifications', notes: ['At 9 pm by default, only if clips are waiting. Channel "Reminders", importance DEFAULT, one sound at most.', 'Tap → To tag.'], states: [{ id: 'default', label: 'Evening reminder', setup: (s, u) => { u.shade = { items: ['evening', 'new'] }; } }] },
    { n: 32, id: 'notif-vn', title: 'Notification: VN copies reminder', group: 'Notifications', notes: ['3 days after copying, if the copies still exist. Tap → reel detail with the Done editing dialog.'], states: [{ id: 'default', label: 'VN copies reminder', setup: (s, u) => { u.shade = { items: ['vn'] }; } }] },
    {
      n: 33, id: 'notif-still', title: 'Shooting mode still on', group: 'Notifications',
      notes: ['Asked once, after 14 days on. Action "Turn off" works from the shade.', 'If the user opens the app instead, the same question appears as a dialog.'],
      states: [
        { id: 'shade', label: 'Notification', setup: (s, u) => { u.shade = { items: ['still'] }; } },
        { id: 'dialog', label: 'In-app dialog', setup: (s, u) => { u.dialog = { type: 'stillShooting' }; } },
      ],
    },

    /* ------------------------------------------------------------- System */
    {
      n: 34, id: 'system-states', title: 'Snackbars, loading and errors', group: 'System-wide states',
      notes: ['Snackbars: inverse surface, one line where possible, Undo in inverse primary. 4 s by default, 6 s for bulk actions, and they wait while TalkBack is reading them.', 'Loading: skeleton tiles with a slow shimmer (static with reduced motion). Never a spinner over a whole screen.', 'Errors say what happened and what to do, and repeat that originals are safe.'],
      states: [
        { id: 'snack-tag', label: 'Snackbar: scene tagged', setup: (s, u) => { tag(s, s.toTag.slice(10, 16), 'r1'); go(u, 'totag'); u.snack = { text: '6 clips added to London Food', undo: true, ic: 'check_circle' }; } },
        { id: 'snack-skip', label: 'Snackbar: skipped', setup: (s, u) => { const sess = s.toTag.slice(); s.skipped.push(sess[0]); s.toTag = s.toTag.slice(1); player(s, u, 1, { session: sess, skippedN: 1 }); u.snack = { text: 'Skipped', undo: true }; } },
        { id: 'snack-copy', label: 'Snackbar: link copied', setup: (s, u) => { go(u, 'reel', { id: 'r1' }); u.snack = { text: 'Link copied', ic: 'content_copy' }; } },
        { id: 'snack-del', label: 'Snackbar: reel deleted', setup: (s, u) => { s.reels = s.reels.filter((r) => r.id !== 'r4'); u.snack = { text: 'Diwali at Home deleted', undo: true }; } },
        { id: 'skel', label: 'Loading skeleton', setup: (s, u) => go(u, 'reel', { id: 'r2', loading: true }) },
        { id: 'editor', label: 'Error: editor not installed', setup: (s, u) => { go(u, 'reel', { id: 'r1' }); u.dialog = { type: 'editorMissing', name: 'VN' }; } },
        { id: 'play', label: "Error: video can't play", setup: (s, u) => { const ids = reelIds(s, 'r2'); go(u, 'viewer', { reel: 'r2', id: ids[4], list: ids, err: true }); } },
        { id: 'storage', label: 'Error: storage full', setup: (s, u) => { const ids = q.liveClipsOf(s, 'r1').map((c) => c.id).slice(0, 12); go(u, 'vn-copy', { id: 'r1', ids, done: 7, fail: 'space' }); } },
      ],
    },

    /* ---------------------------------------------------- Reference reels */
    {
      n: 35, id: 'save-ref', title: 'Save reference (share from Instagram)', group: 'Reference reels',
      notes: ['TakeTray appears in Android\'s share menu (ACTION_SEND, text/plain). Sharing a reel opens this sheet over Instagram; it never takes the user out of Instagram.', 'Existing reel is the default when reels exist, with Recording reels first. Nothing is preselected, so a reference can\'t land in the wrong reel by accident.', 'Video access is not needed, so this works even before onboarding.', 'Instagram itself is never drawn: the background is a plain video app, and the source icon comes from the phone.'],
      spec: { Save: 'Saves the link (and label) to the reel, then shows the confirmation.', Done: 'Closes the sheet; the user is back in Instagram.', 'Open reel': 'Opens TakeTray on the reel\'s References section (after onboarding, on a first launch).', 'Not a link': 'Explains, saves nothing.' },
      states: [
        { id: 'share', label: "Android share menu", desc: 'Drawn by the system; TakeTray is one of the targets.', setup: (s, u) => { go(u, 'ext-app'); u.sheet = { type: 'sysShare', text: RH.SHARES.reel.text }; } },
        { id: 'existing', label: 'Choose an existing reel', setup: (s, u) => { go(u, 'ext-app'); u.sheet = { type: 'saveRef', step: 'form', text: RH.SHARES.reel.text, url: RH.SHARES.reel.text, mode: 'existing', pick: 'r2', label: 'Push-in on the plate' }; } },
        { id: 'new', label: 'Choose a new reel', setup: (s, u) => { go(u, 'ext-app'); u.sheet = { type: 'saveRef', step: 'form', text: RH.SHARES.reel.text, url: RH.SHARES.reel.text, mode: 'new', name: 'Borough Market Eats', label: '' }; u.kbd = true; } },
        { id: 'noreels', label: 'No reels exist yet', setup: (s, u) => { s.reels = []; go(u, 'ext-app'); u.sheet = { type: 'saveRef', step: 'form', text: RH.SHARES.reel.text, url: RH.SHARES.reel.text, mode: 'new', name: '' }; u.kbd = true; } },
        { id: 'post', label: 'An Instagram post (accepted)', setup: (s, u) => { go(u, 'ext-app'); u.sheet = { type: 'saveRef', step: 'form', text: RH.SHARES.post.text, url: RH.SHARES.post.text, mode: 'existing', pick: 'r1', label: '' }; } },
        { id: 'notlink', label: "Not a link", setup: (s, u) => { go(u, 'ext-app'); u.sheet = { type: 'saveRef', step: 'notlink', text: RH.SHARES.text.text }; } },
        { id: 'dup', label: 'Already saved in that reel', setup: (s, u) => { go(u, 'ext-app'); u.sheet = { type: 'saveRef', step: 'form', text: RH.SHARES.dup.text, url: RH.SHARES.dup.text, mode: 'existing', pick: 'r1', label: '' }; } },
        { id: 'done', label: 'Saved', setup: (s, u) => { RH.refsOf(q.reel(s, 'r2')).push({ id: 'n1', url: RH.SHARES.reel.text, label: 'Push-in on the plate', added: RH.TODAY }); go(u, 'ext-app'); u.sheet = { type: 'saveRef', step: 'done', url: RH.SHARES.reel.text, saved: 'r2', savedLabel: 'Push-in on the plate' }; } },
        { id: 'first', label: 'Saved on first launch (before onboarding)', desc: 'Done goes back to Instagram and onboarding waits. Open reel runs onboarding first, then lands on the reel.', setup: (s, u) => { s.onboarded = false; s.reels = [{ id: 'p1', name: 'London Food', status: 'rec', created: RH.TODAY, desc: '', vn: null, pre: true, refs: [{ id: 'x1', url: RH.SHARES.reel.text, label: '', added: RH.TODAY }] }]; go(u, 'ext-app'); u.sheet = { type: 'saveRef', step: 'done', url: RH.SHARES.reel.text, saved: 'p1' }; } },
      ],
    },
    {
      n: 36, id: 'add-ref', title: 'Add / edit reference', group: 'Reference reels',
      notes: ['Opened from "Add reference" on reel detail. Paste a link, add an optional label (60 characters).', 'If the clipboard holds a link, the sheet offers it. On Android 12+ the app checks only the clipboard description (no "pasted" toast); the toast appears when the user taps Paste, which they expect.', 'Edit label keeps the link read-only; to change a link, remove the reference and add it again.'],
      states: [
        { id: 'empty', label: 'Empty', setup: (s, u) => { go(u, 'reel', { id: 'r1' }); u.sheet = { type: 'addRef', rid: 'r1', link: '', label: '', noOffer: true }; u.kbd = true; } },
        { id: 'clip', label: 'Link on the clipboard', setup: (s, u) => { go(u, 'reel', { id: 'r1' }); u.sheet = { type: 'addRef', rid: 'r1', link: '', label: '' }; } },
        { id: 'invalid', label: "Invalid link", setup: (s, u) => { go(u, 'reel', { id: 'r1' }); u.sheet = { type: 'addRef', rid: 'r1', link: 'dishoom bacon naan', label: '', noOffer: true, err: "That isn't a link. In Instagram: Share › Copy link, then paste it here." }; u.kbd = true; } },
        { id: 'dup', label: 'Already saved', setup: (s, u) => { go(u, 'reel', { id: 'r1' }); u.sheet = { type: 'addRef', rid: 'r1', link: 'https://www.instagram.com/reel/C9xL2pQhR4a/', label: '', noOffer: true, err: 'Already saved in London Food' }; } },
        { id: 'edit', label: 'Editing a label', setup: (s, u) => { go(u, 'reel', { id: 'r1' }); u.sheet = { type: 'addRef', rid: 'r1', refId: 'ref1', label: 'Fast cuts, food close-ups' }; u.kbd = true; } },
      ],
    },
    {
      n: 37, id: 'refs-sheet', title: 'References sheet (while shooting)', group: 'Reference reels',
      notes: ['Opened from "References · 4" on the Shooting mode card. Lists references from every Recording reel, grouped by reel, with each reel\'s shot ideas.', 'No "currently shooting for" reel and no pinning: every Recording reel is shown.', 'Tap a reference to open it in Instagram (or the browser); tap the reel name to open the reel. Groups collapse with the chevron.'],
      states: [
        { id: 'several', label: 'Several reels', setup: (s, u) => { u.sheet = { type: 'refsList', closed: [] }; } },
        { id: 'one', label: 'One reel with references', setup: (s, u) => { q.reel(s, 'r2').refs = []; q.reel(s, 'r4').refs = []; u.sheet = { type: 'refsList', closed: [] }; } },
        { id: 'noshots', label: 'A reel with references but no shot ideas', setup: (s, u) => { q.reel(s, 'r2').desc = ''; u.sheet = { type: 'refsList', closed: ['r1'] }; } },
      ],
    },
  ];

  RH.screenById = (id) => RH.SCREENS.find((x) => x.id === id);
  RH.buildState = function (screen, state) {
    const s = RH.fixture();
    const u = RH.defaultUI();
    state.setup(s, u);
    return { s, u };
  };
})();
