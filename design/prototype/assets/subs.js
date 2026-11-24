/* Free week and subscription (owner change, 22 Nov 2026).
   - The free week starts on first launch. No card, nothing to sign; TakeTray keeps the dates on the phone.
   - After the first tagging session, a sheet says once how long the week lasts.
   - The day before it ends: a banner on Reels and one notification.
   - When it ends without a plan, the plans screen shows once, then TakeTray is read-only:
     reels, clips, Shooting mode (still collecting), backups and settings work; tagging, sending to editors,
     adding videos and new reels need a plan.
   - Plans: monthly ₹149 and yearly ₹1,199, with a first-year launch offer of ₹129 a month (first 12 months) and
     ₹899 for the first year (Google Play offers; prices come from Play in the app). Cancel anytime, in Google Play.
   Screens 41–45 in the gallery, the "Free week and subscription" flow, and two Simulate buttons. */
(function () {
  const RH = window.RH;
  const { fmt, h } = RH;
  const { esc, icon } = h;
  const D = RH.days;
  const TODAY = RH.TODAY;
  const MON = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const longDate = (iso) => { const p = D.parse(iso); return `${p.d} ${MON[p.m - 1]} ${p.y}`; };
  const day = (iso) => fmt.day(iso).replace(/ /g, ' ');

  /* Prices as Google Play returns them (the app never hard-codes them). Yearly saves 41 %: 1 − 899 / (12 × 129), rounded down. */
  const PLANS = {
    yearly: {
      name: 'Yearly', unit: 'year', badge: 'Best value',
      offer: { was: '₹1,199', price: '₹899', per: 'first year', sub: 'About ₹75 a month in your first year. Then ₹1,199 a year.', cta: '₹899 for the first year', terms: '₹899 for your first year, then ₹1,199 a year', play: '₹899.00 for the first year, then ₹1,199.00/year' },
      regular: { price: '₹1,199', per: 'a year', sub: 'About ₹100 a month, billed once a year', cta: '₹1,199 a year', terms: '₹1,199 a year', play: '₹1,199.00/year' },
    },
    monthly: {
      name: 'Monthly', unit: 'month',
      offer: { was: '₹149', price: '₹129', per: 'a month', sub: 'For your first 12 months. Then ₹149 a month.', cta: '₹129 a month', terms: '₹129 a month for your first 12 months, then ₹149 a month', play: '₹129.00/month for 12 months, then ₹149.00/month' },
      regular: { price: '₹149', per: 'a month', sub: 'Billed every month', cta: '₹149 a month', terms: '₹149 a month', play: '₹149.00/month' },
    },
  };
  /** The launch offer, unless Google Play says this account can't have it (it subscribed before). */
  const priceOf = (k, noOffer) => (noOffer ? PLANS[k].regular : PLANS[k].offer);
  RH.PLANS = PLANS;

  /* ------------------------------------------------------------ State */
  const baseFixture = RH.fixture;
  RH.fixture = function () {
    const s = baseFixture();
    // First opened Fri 9 Oct; "today" in the prototype is Mon 12 Oct: day 4 of 7.
    s.plan = { st: 'trial', start: '2026-10-09', end: '2026-10-16', product: 'yearly', renew: null, offerSeen: false, tagged: false };
    return s;
  };
  const P = (s) => s.plan || { st: 'trial', start: TODAY, end: D.add(TODAY, 7) };
  const LOCKED = ['ended', 'lapsed', 'pending'];
  const locked = (RH.planLocked = (s) => LOCKED.includes(P(s).st));
  const daysLeft = (s) => Math.max(0, D.span(TODAY, P(s).end) - 1);
  const dayNo = (s) => Math.min(7, D.span(P(s).start, TODAY));
  const leftText = (s) => { const n = daysLeft(s); return n <= 1 ? 'Ends tomorrow' : `${n} days left`; };

  const spinner = (label) => `<span class="spin ev-spin" role="progressbar" aria-label="${esc(label)}"></span>`;
  const dots = (s) => `<div class="pl-days" role="img" aria-label="Day ${dayNo(s)} of 7">${[1, 2, 3, 4, 5, 6, 7].map((k) => `<i class="${k <= dayNo(s) ? 'on' : ''}"></i>`).join('')}</div>`;

  /* ---------------------------------------------------- Plans screen */
  RH.routes.plans = (s, u) => {
    const p = u.p || {};
    const pl = P(s);
    const pick = p.pick || 'yearly';
    const phase = p.phase || 'ready';
    const ended = pl.st === 'ended' || pl.st === 'lapsed';
    const title = pl.st === 'lapsed' ? 'Your plan has ended' : ended ? 'Your free week has ended' : 'Keep sorting after your free week';
    const sub = ended
      ? 'Your reels and clips are safe. Subscribe to keep tagging new clips and sending reels to your editor.'
      : `Free until ${day(pl.end)}. If you subscribe now, your plan starts today.`;
    const incl = [
      ['sell', 'Tag clips into reels, one at a time or a whole scene'],
      ['movie_edit', 'Send reels to CapCut, Instagram Edits and VN'],
      ['library_add', "Add friends' videos and earlier days"],
      ['lightbulb', 'Plan new reels with shot ideas and references'],
    ];
    const plan = (k) => {
      const x = PLANS[k];
      const pr = priceOf(k, p.noOffer);
      const on = pick === k;
      const label = `${x.name}${x.badge ? `, ${x.badge.toLowerCase()}` : ''}, ${pr.was ? `launch offer ${pr.price} ${pr.per}, regular price ${pr.was}` : `${pr.price} ${pr.per}`}. ${pr.sub}`;
      if (phase === 'loading') return `<div class="pl-plan skel" aria-hidden="true"><span class="skel-line" style="width:40%"></span><span class="skel-line" style="width:65%"></span></div>`;
      return `<button class="pl-plan tap" role="radio" aria-checked="${on}" aria-label="${esc(label)}" data-a="plansPick" data-k="${k}"${phase !== 'ready' ? ' aria-disabled="true"' : ''}>
        <span class="pl-radio" aria-hidden="true"></span>
        <span class="pl-name"><b>${x.name}</b>${x.badge ? `<span class="pl-save">${x.badge}</span>` : ''}</span>
        <span class="pl-price">${pr.was ? `<s>${pr.was}</s>` : ''}<b>${pr.price}</b><span>${pr.per}</span></span>
        <span class="pl-sub">${pr.sub}</span></button>`;
    };
    const buyErr = p.buyErr ? `<div class="banner warn" role="alert">${icon('error')}<div class="grow"><b>Couldn't finish the purchase</b><span>You weren't charged. Try again.</span></div></div>` : '';
    const err = phase === 'error' ? `<div class="banner warn" role="alert">${icon('wifi_off')}<div class="grow"><b>Couldn't reach Google Play</b><span>Check your connection and try again.</span></div>${h.btn({ label: 'Try again', kind: 'text', a: 'plansRetry' })}</div>` : '';
    const pending = pl.st === 'pending' ? `<div class="callout">${icon('hourglass_top', 'fill')}<div><b>Payment pending</b>Google Play is confirming your payment. TakeTray unlocks as soon as it's done; you don't need to keep this screen open.</div></div>` : '';
    const pr = priceOf(pick, p.noOffer);
    const cta = phase === 'buying'
      ? `<button class="btn filled lg block" aria-disabled="true">${spinner('Opening Google Play')}<span>Opening Google Play…</span></button>`
      : h.btn({ label: phase === 'ready' && pl.st !== 'pending' ? `Subscribe for ${pr.cta}` : 'Subscribe', kind: 'filled', size: 'lg block', a: 'plansBuy', dis: phase !== 'ready' || pl.st === 'pending' });
    return {
      html: `<div class="scr pl-scr">${h.appbar({ title: '', nav: 'close', navA: 'plansClose' })}<div class="scroll" data-scroll="plans">
        <div class="pl-hero"><h1>${title}</h1><p>${sub}</p></div>
        ${err}${buyErr}${pending}
        <div class="pl-sec"><div class="pl-hrow"><h2 class="pl-h" id="pl-choose">Choose a plan</h2>${p.noOffer ? '' : `<span class="pl-tag">${icon('sell')}Launch offer</span>`}</div><div class="pl-plans" role="radiogroup" aria-labelledby="pl-choose"${phase === 'loading' ? ' aria-busy="true"' : ''}>${plan('yearly')}${plan('monthly')}</div></div>
        <div class="pl-sec"><h2 class="pl-h">Your subscription includes</h2><ul class="pl-incl">${incl.map(([ic, t]) => `<li>${icon(ic)}<span>${t}</span></li>`).join('')}</ul>
        <p class="pl-free">${icon('shield')}<span>Always free: watching your clips, your reels, Shooting mode and backups.</span></p></div>
        <div class="pl-links">${h.btn({ label: 'Restore purchase', kind: 'text', a: 'subRestore' })}${h.btn({ label: 'Terms', kind: 'text', a: 'noop' })}${h.btn({ label: 'Privacy', kind: 'text', a: 'noop' })}</div>
        <div class="pl-foot"><p class="pl-cancel">${icon('check_circle', 'fill')}<span><b>Cancel anytime</b> in Google Play. You keep everything until the end of the time you paid for.</span></p>${cta}<p class="pl-fine">${p.noOffer ? '' : 'Launch offer: '}${pr.terms}. Renews automatically through Google Play.</p>${ended ? h.btn({ label: 'Continue read-only', kind: 'text', size: 'block', a: 'plansClose' }) : ''}</div></div></div>`,
    };
  };

  /* ------------------------------------------------ Subscription page */
  RH.routes.subscription = (s) => {
    const pl = P(s);
    const x = PLANS[pl.product || 'yearly'];
    const card = (ic, title, lines, acts, tone = '') => `<section class="pl-card ${tone}"><div class="row">${icon(ic, 'fill')}<b class="t-tm">${title}</b></div>${lines}${acts ? `<div class="pl-acts">${acts}</div>` : ''}</section>`;
    const seePlans = h.btn({ label: 'See plans', kind: 'filled', a: 'openPlans', d: { from: 'settings' } });
    const manage = h.btn({ label: 'Manage in Google Play', ic: 'open_in_new', kind: 'outlined', a: 'manageGP' });
    const states = {
      trial: () => card('hourglass_top', 'Free week', `<p class="v">${leftText(s)} · free until ${day(pl.end)}</p>${dots(s)}<p class="t-bs v">No card needed. Choose a plan any time before it ends to keep tagging.</p>`, seePlans),
      ended: () => card('lock', 'Read-only', `<p class="v">Your free week ended on ${day(pl.end)}.</p><p class="t-bs v">You can still watch your clips, open your reels and export a backup. Subscribe to keep tagging and sending reels.</p>`, seePlans),
      active: () => card('workspace_premium', `${x.name} plan`, `<p class="v">Renews automatically · cancel anytime</p><p class="t-bs v">Google Play shows your price and the next payment date.</p>`, manage),
      cancelled: () => card('event_busy', `${x.name} plan · won't renew`, `<p class="v">You cancelled. Everything keeps working until the end of the time you paid for; Google Play shows the date.</p>`, h.btn({ label: 'Keep my plan', ic: 'open_in_new', kind: 'filled', a: 'manageGP' })),
      lapsed: () => card('lock', 'Your plan has ended', `<p class="v">TakeTray is read-only. If a payment failed, fixing it in Google Play brings your plan back.</p>`, seePlans + h.btn({ label: 'Fix in Google Play', ic: 'open_in_new', kind: 'outlined', a: 'manageGP' })),
      pending: () => card('hourglass_top', 'Payment pending', `<p class="v">Google Play is confirming your payment for the ${x.name.toLowerCase()} plan. TakeTray unlocks as soon as it's done.</p>`, ''),
    };
    const rows = `<div class="li-h">Purchases</div>
      <button class="li tap" data-a="subRestore"><span class="lead">${icon('restore')}</span><span class="txt"><b>Restore purchase</b><span>Already subscribed on this Google account?</span></span></button>
      ${['active', 'cancelled', 'lapsed'].includes(pl.st) ? '' : `<button class="li tap" data-a="manageGP"><span class="lead">${icon('open_in_new')}</span><span class="txt"><b>Google Play subscriptions</b><span>Payments, plans and cancelling</span></span></button>`}
      <p class="pl-note">Cancel any time in Google Play. You keep everything until the end of the time you paid for, and your reels and clips are never deleted.</p>`;
    return {
      html: `<div class="scr">${h.appbar({ title: 'Subscription', nav: 'back' })}<div class="scroll" data-scroll="subscription" style="padding-top:4px">${(states[pl.st] || states.trial)()}${rows}<div class="end-space"></div></div></div>`,
    };
  };

  /* --------------------------------------------- Sheets and dialogs */
  RH.sheets.trialOffer = (s, u) => `<div class="sheet ${u.sheet.fresh ? 'fresh' : ''}" role="dialog" aria-modal="true" aria-labelledby="to-t"><div class="handle"></div>
    <div class="sh-head"><h2 id="to-t">You're on your free week</h2><p>Nice, your first clips are in their reels. TakeTray is free until ${day(P(s).end)}, with no card needed.</p></div>
    <div class="sh-body pl-offer">${dots(s)}<p class="t-bs v">Day ${dayNo(s)} of 7 · ${leftText(s).toLowerCase()}</p>
    <ul class="pl-incl small"><li>${icon('notifications')}<span>We'll remind you the day before it ends.</span></li><li>${icon('sell')}<span>After that, keep tagging from ₹129 a month with the launch offer.</span></li><li>${icon('check_circle')}<span>No card now, and cancel anytime once you subscribe.</span></li><li>${icon('shield')}<span>Your reels and clips stay yours either way.</span></li></ul>
    <div class="pl-sheet-acts">${h.btn({ label: 'Got it', kind: 'filled', size: 'lg block', a: 'closeSheet' })}${h.btn({ label: 'See plans', kind: 'text', size: 'block', a: 'trialPlans' })}</div></div></div>`;

  const LOCK = {
    tag: ['Subscribe to tag clips', (s) => `${s.toTag.length ? `${fmt.n(s.toTag.length, 'clip')} are waiting in To tag. ` : ''}Your free week has ended, so tagging needs a plan.`],
    send: ['Subscribe to send reels', () => 'Your free week has ended, so sending clips to CapCut, Instagram Edits or VN needs a plan.'],
    add: ['Subscribe to add videos', () => "Your free week has ended, so adding friends' videos and earlier days needs a plan."],
    reel: ['Subscribe to plan new reels', () => 'Your free week has ended, so new reels need a plan.'],
  };
  RH.sheets.locked = (s, u) => {
    const [t, body] = LOCK[u.sheet.ctx] || LOCK.tag;
    const pend = P(s).st === 'pending';
    return `<div class="sheet ${u.sheet.fresh ? 'fresh' : ''}" role="dialog" aria-modal="true" aria-labelledby="lk-t"><div class="handle"></div>
    <div class="sh-head"><span class="pl-lock">${icon('lock', 'fill')}</span><h2 id="lk-t">${pend ? 'Payment pending' : t}</h2><p>${pend ? "Google Play is still confirming your payment. This unlocks as soon as it's done." : body(s)}</p></div>
    <div class="sh-body"><p class="pl-free">${icon('shield')}<span>Your reels and clips are safe. You can still watch them, keep Shooting mode on and export a backup.</span></p>
    <div class="pl-sheet-acts">${pend ? h.btn({ label: 'OK', kind: 'filled', size: 'lg block', a: 'closeSheet' }) : `${h.btn({ label: 'See plans', kind: 'filled', size: 'lg block', a: 'lockedPlans' })}${h.btn({ label: 'Not now', kind: 'text', size: 'block', a: 'closeSheet' })}`}</div></div></div>`;
  };

  /* Google Play's own purchase sheet (system UI, drawn as a stand-in). */
  RH.sheets.gplay = (s, u) => {
    const x = PLANS[u.sheet.product];
    const pr = priceOf(u.sheet.product, u.sheet.noOffer);
    return `<div class="gp-wrap"><span class="tag">Google Play purchase sheet (system, stand-in)</span><div class="gp" role="dialog" aria-modal="true" aria-labelledby="gp-t">
      <div class="gp-h">${icon('shop', 'fill')}<span>Google Play</span></div>
      <div class="gp-p"><span class="gp-ic">${h.brandIcon(40, 'tray', 'circle')}</span><div><b id="gp-t">TakeTray ${x.name}</b><span>${pr.play}</span></div></div>
      <div class="gp-row">${icon('account_balance')}<span>UPI Autopay · you@okbank</span></div>
      <p class="gp-fine">Cancel any time in Google Play › Payments &amp; subscriptions.</p>
      <button class="gp-btn" data-a="gpBuy">Subscribe</button>
      <div class="gp-sim"><button data-a="gpPending">Simulate: payment pending</button><button data-a="gpCancel">Simulate: cancel</button><button data-a="gpFail">Simulate: Play error</button></div></div></div>`;
  };

  const { dlg } = { dlg: RH.dlg };
  RH.dialogs.subDone = (s) => { const pl = P(s); const x = PLANS[pl.product]; const pr = priceOf(pl.product, pl.noOffer); return dlg('check_circle', "You're subscribed", `<p>${x.name} plan: ${pr.terms}. Next payment on ${longDate(pl.renew)}. You can cancel anytime in Google Play.</p><p>Thanks for supporting TakeTray.</p>`, h.btn({ label: 'Done', kind: 'text', a: 'subDoneOk' })); };
  RH.dialogs.restoreNone = () => dlg('search_off', 'No subscription found', "<p>There's no TakeTray subscription on the Google account signed in to Play. If you subscribed with another account, switch to it in the Play Store, then try again.</p>", h.btn({ label: 'OK', kind: 'text', a: 'closeDialog' }));

  /* ------------------------------------------- Banners on other screens */
  const banner = (s) => {
    const pl = P(s);
    if (pl.st === 'trial' && daysLeft(s) <= 1) return `<button class="banner attn tap" data-a="openPlans" data-from="banner" style="width:calc(100% - 32px)">${icon('hourglass_top', 'fill')}<div class="grow"><b>Your free week ends tomorrow</b><span>Keep tagging from ₹129 a month with the launch offer. Your reels stay safe either way.</span></div>${icon('chevron_right')}</button>`;
    if (locked(s)) return `<div class="banner info pl-ro" role="region" aria-label="Read-only">${icon('lock', 'fill')}<div class="grow"><b>${pl.st === 'pending' ? 'Payment pending' : 'Read-only'}</b><span>${pl.st === 'pending' ? "Unlocks as soon as Google Play confirms it." : pl.st === 'lapsed' ? 'Your plan has ended. Subscribe again to keep tagging.' : 'Your free week has ended. Subscribe to keep tagging.'}</span></div>${pl.st === 'pending' ? '' : h.btn({ label: 'See plans', kind: 'tonal', size: 'sm', a: 'openPlans', d: { from: 'banner' } })}</div>`;
    return '';
  };
  const inject = (key, extra) => {
    const base = RH.routes[key];
    RH.routes[key] = (s, u) => {
      const r = base(s, u);
      const b = extra(s, u);
      if (b && r && r.html) r.html = r.html.replace(`data-scroll="${key}">`, `data-scroll="${key}">${b}`);
      return r;
    };
  };
  inject('home', (s) => banner(s));
  inject('totag', (s) => (locked(s) && s.toTag.length ? `<div class="banner info pl-ro" role="region" aria-label="Read-only">${icon('lock', 'fill')}<div class="grow"><b>${fmt.n(s.toTag.length, 'clip')} waiting</b><span>Shooting mode keeps collecting. Subscribe to tag them.</span></div>${h.btn({ label: 'See plans', kind: 'tonal', size: 'sm', a: 'openPlans', d: { from: 'banner' } })}</div>` : ''));
  const baseSettings = RH.routes.settings;
  RH.routes.settings = (s, u) => {
    const r = baseSettings(s, u);
    const pl = P(s);
    const x = PLANS[pl.product || 'yearly'];
    const sub = { trial: `Free week · ${leftText(s).toLowerCase()}`, ended: 'Read-only · free week ended', active: `${x.name} · renews automatically`, cancelled: `${x.name} · won't renew`, lapsed: 'Read-only · plan ended', pending: 'Payment pending' }[pl.st];
    const row = `<div class="li-h">Subscription</div><button class="li tap" data-a="go" data-r="subscription"><span class="lead">${icon(locked(s) ? 'lock' : 'workspace_premium')}</span><span class="txt"><b>${['active', 'cancelled'].includes(pl.st) ? 'TakeTray subscription' : 'Free week and plans'}</b><span>${sub}</span></span>${icon('chevron_right')}</button>`;
    r.html = r.html.replace('<div class="li-h">Shooting mode</div>', `${row}<div class="li-h">Shooting mode</div>`);
    return r;
  };

  RH.notifExtra = (s) => ({
    trial: () => `<button class="notif tap" data-a="notifTrial"><div class="nh"><span class="appic">${icon('hourglass_top', 'fill')}</span>TakeTray · 10:00 am</div><div class="nb"><div class="grow"><b>Your free week ends tomorrow</b><span>Choose a plan to keep tagging. Your reels stay safe either way.</span></div></div><div class="na"><span data-a="notifTrial">See plans</span></div></button>`,
  });

  /* ------------------------------------------------------------ Actions */
  const A = RH.ACTIONS;
  const later = (app, ms, fn) => { clearTimeout(app.timers.sub); app.timers.sub = setTimeout(fn, ms); };
  const ready = (app) => later(app, 700, () => { if (app.u.route === 'plans' && app.u.p.phase === 'loading') { app.u.p.phase = 'ready'; app.render(); } });
  Object.assign(A, {
    openPlans(d = {}) {
      this.u.sheet = null; this.u.menu = null; this.u.shade = null;
      this.nav('plans', { from: d.from || 'settings', pick: 'yearly', phase: 'loading' });
      ready(this);
    },
    plansPick(d) { if (this.u.p.phase === 'ready') { this.u.p.pick = d.k; this.render(); } },
    plansRetry() { this.u.p.phase = 'loading'; this.render(); ready(this); },
    plansBuy() { if (this.u.p.phase !== 'ready') return; this.u.p.buyErr = false; this.u.p.phase = 'buying'; this.render(); later(this, 500, () => { this.u.sheet = { type: 'gplay', product: this.u.p.pick, noOffer: !!this.u.p.noOffer, fresh: true }; this.render(); }); },
    plansClose() { if (this.hist.length) this.back(); else this.tab('home'); if (locked(this.s)) this.log('Read-only: reels, clips, Shooting mode and backups still work. Try Start tagging or New reel.'); },
    gpBuy() {
      const k = this.u.sheet.product;
      const noOffer = this.u.sheet.noOffer;
      this.u.sheet = null;
      Object.assign(this.s.plan, { st: 'active', product: k, noOffer, renew: k === 'yearly' ? '2027-10-12' : '2026-11-12' });
      this.u.p.phase = 'ready'; this.u.dialog = { type: 'subDone' }; this.render();
    },
    gpPending() { const k = this.u.sheet.product; this.u.sheet = null; Object.assign(this.s.plan, { st: 'pending', product: k }); this.u.p.phase = 'ready'; this.render(); this.log('Pending (for example UPI waiting for approval): TakeTray unlocks when Google Play confirms.'); },
    gpCancel() { this.u.sheet = null; this.u.p.phase = 'ready'; this.render(); this.log('Cancelled in Google Play: back to the plans with nothing changed and no message.'); },
    gpFail() { this.u.sheet = null; this.u.p.phase = 'ready'; this.u.p.buyErr = true; this.render(); },
    subDoneOk() { this.u.dialog = null; if (this.hist.length) this.back(); else this.tab('home'); },
    subRestore() {
      if (['active', 'cancelled'].includes(this.s.plan.st)) { this.u.snack = { text: 'Your subscription is active', ic: 'check_circle' }; this.render(); return; }
      this.u.snack = { text: 'Checking Google Play…' }; this.render();
      later(this, 700, () => { this.u.snack = null; this.u.dialog = { type: 'restoreNone' }; this.render(); });
    },
    manageGP() { this.log('Opens Google Play › Payments & subscriptions › TakeTray (outside the app). Changing plan, cancelling and fixing payment all happen there.'); },
    trialPlans() { this.u.sheet = null; A.openPlans.call(this, { from: 'offer' }); },
    lockedPlans() { this.u.sheet = null; A.openPlans.call(this, { from: 'locked' }); },
    notifTrial() { this.u.shade = null; A.openPlans.call(this, { from: 'reminder' }); },
  });

  /* Read-only: these need a plan. */
  const GATED = { startTagging: 'tag', playFrom: 'tag', tagScene: 'tag', askSkipAll: 'tag', newReel: 'reel', newReelPlayer: 'reel', addVideos: 'add', openEarlier: 'add', editVideo: 'send' };
  Object.entries(GATED).forEach(([k, ctx]) => {
    const base = A[k];
    if (!base) return;
    A[k] = function (...args) {
      if (this.s && locked(this.s)) { this.u.menu = null; this.u.sheet = { type: 'locked', ctx, fresh: true }; this.render(); this.u.sheet.fresh = false; return; }
      return base.apply(this, args);
    };
  });

  /* The free-week sheet: once, when the first tagging session closes with something tagged. */
  const baseChip = A.chip;
  A.chip = function (...args) { if (this.s && this.s.plan) this.s.plan.tagged = true; return baseChip.apply(this, args); };
  const baseClose = A.closePlayer;
  A.closePlayer = function (...args) {
    const r = baseClose.apply(this, args);
    const pl = this.s && this.s.plan;
    if (pl && pl.st === 'trial' && pl.tagged && !pl.offerSeen) {
      pl.offerSeen = true;
      this.u.sheet = { type: 'trialOffer', fresh: true }; this.render(); this.u.sheet.fresh = false;
      this.log('Shown once, after the first tagging session. Got it closes it; See plans opens the plans.');
    }
    return r;
  };

  /* Prototype flow and Simulate buttons. */
  const baseLoad = RH.App.load;
  RH.App.load = function (flow, preset) {
    if (flow !== 'subscription') return baseLoad.call(this, flow, preset);
    baseLoad.call(this, 'tagging', preset);
    this.flow = 'subscription';
    this.syncPanel();
    this.log('Day 4 of the free week. Tag a few clips, then close the player.');
  };
  RH.simExtra = (k, app) => {
    const s = app.s;
    if (k === 'trialTomorrow') {
      Object.assign(s.plan, { st: 'trial', start: '2026-10-06', end: '2026-10-13' });
      app.tab('home'); app.u.shade = { items: ['trial'] }; app.render();
      app.log('The day before the free week ends: one notification at 10 am, and a banner on Reels until it ends.');
      return true;
    }
    if (k === 'trialEnd') {
      Object.assign(s.plan, { st: 'ended', start: '2026-10-05', end: '2026-10-12' });
      app.u.sheet = null; app.u.dialog = null; app.u.shade = null; app.u.player = null;
      app.hist = [{ route: 'home', p: {} }];
      app.u.route = 'plans'; app.u.p = { from: 'ended', pick: 'yearly', phase: 'loading' }; app.render(); ready(app);
      app.log('The free week has ended: the next time TakeTray opens, the plans screen shows once. Continue read-only to look around.');
      return true;
    }
    return false;
  };

  /* --------------------------------------------------- Gallery: 41–45 */
  const go = (u, route, p = {}) => { u.route = route; u.p = p; };
  const set = (s, o) => Object.assign(s.plan, o);
  const ENDED = { st: 'ended', start: '2026-10-05', end: '2026-10-12' };
  const plans = (u, o = {}) => go(u, 'plans', { from: 'settings', pick: 'yearly', phase: 'ready', ...o });
  RH.SCREENS.push(
    {
      n: 41, id: 'plans', title: 'Plans', group: 'Subscription',
      notes: [
        'One screen for every way in: Settings › Subscription, the free-week sheet, the Reels banner, the reminder notification, a locked action, and once when the free week ends.',
        'Launch offer (Google Play offers on the base plans): Monthly ₹149, ₹129 for the first 12 months; Yearly ₹1,199, ₹899 for the first year. The regular price shows crossed out because people really pay it afterwards, and the line under the button says when it changes. Yearly is picked by default and marked "Best value". Prices come from Google Play at run time.',
        'Someone who had the offer before (Play says they are not eligible) sees the regular prices, with no cross-out and no "Launch offer" tag.',
        '"Cancel anytime" sits right above the button, in plain words, not only in the small print. The button states the outcome and the price ("Subscribe for ₹899 for the first year"); the line under it gives the full terms and that it renews, as Google Play policy asks.',
        'During the free week the screen says honestly that subscribing starts the plan today, so nobody feels tricked into losing free days.',
        'After the free week, Close and "Continue read-only" both go on in read-only. Nothing is deleted.',
        'Prices load from Google Play (skeleton). With no connection: "Couldn\'t reach Google Play" and Try again; the plans stay off.',
      ],
      spec: { Plan: 'Radio cards; 72 dp min height; the whole card is the target.', Subscribe: 'Opens Google Play\'s purchase sheet for that plan.', 'Restore purchase': 'Asks Google Play for this account\'s purchases.', 'Close, Back': 'Back where they came from (read-only after the free week).' },
      states: [
        { id: 'trial', label: 'During the free week', setup: (s, u) => plans(u) },
        { id: 'monthly', label: 'Monthly picked', setup: (s, u) => plans(u, { pick: 'monthly' }) },
        { id: 'no-offer', label: 'No launch offer (subscribed before)', setup: (s, u) => { set(s, { st: 'lapsed', product: 'monthly' }); plans(u, { noOffer: true }); } },
        { id: 'ended', label: 'Free week ended (shown once)', setup: (s, u) => { set(s, ENDED); plans(u, { from: 'ended' }); } },
        { id: 'loading', label: 'Loading prices', setup: (s, u) => plans(u, { phase: 'loading' }) },
        { id: 'error', label: "Couldn't reach Google Play", setup: (s, u) => plans(u, { phase: 'error' }) },
        { id: 'buying', label: 'Opening Google Play', setup: (s, u) => plans(u, { phase: 'buying' }) },
        { id: 'pending', label: 'Payment pending', setup: (s, u) => { set(s, { st: 'pending', product: 'yearly' }); plans(u); } },
        { id: 'big', label: '2× text', setup: (s, u) => { plans(u); u.fs2 = true; } },
        { id: 'big-ended', label: '2× text: free week ended', setup: (s, u) => { set(s, ENDED); plans(u, { from: 'ended' }); u.fs2 = true; } },
      ],
    },
    {
      n: 42, id: 'free-week', title: 'Free week', group: 'Subscription',
      notes: [
        'The free week starts when TakeTray is first opened: 7 days, no card, nothing to sign up for. The dates are kept on the phone (reinstalling starts again, which the owner accepted: the reels go with it).',
        'Nothing about it shows until the first tagging session ends with at least one clip tagged. Then this sheet, once: how long is left, that a reminder will come, and the prices. Got it is the main button; See plans is there but not pushed.',
        'The day before it ends: one notification at 10 am (channel Reminders) and a banner on Reels. No countdowns, no badges, no repeats.',
        'Settings › Subscription always shows the days left.',
      ],
      spec: { 'Got it': 'Closes the sheet.', 'See plans': 'Plans (screen 41).', Banner: 'Plans.', Notification: 'Opens TakeTray on Plans.' },
      states: [
        { id: 'sheet', label: 'After the first tagging session', setup: (s, u) => { go(u, 'totag'); u.sheet = { type: 'trialOffer' }; } },
        { id: 'banner', label: 'Reels: ends tomorrow', setup: (s) => { set(s, { start: '2026-10-06', end: '2026-10-13' }); } },
        { id: 'notif', label: 'Reminder notification', setup: (s, u) => { set(s, { start: '2026-10-06', end: '2026-10-13' }); u.shade = { items: ['trial'] }; } },
        { id: 'settings', label: 'Settings row', setup: (s, u) => go(u, 'settings') },
        { id: 'big', label: '2× text: sheet', setup: (s, u) => { go(u, 'totag'); u.sheet = { type: 'trialOffer' }; u.fs2 = true; } },
        { id: 'big-banner', label: '2× text: banner', setup: (s, u) => { set(s, { start: '2026-10-06', end: '2026-10-13' }); u.fs2 = true; } },
      ],
    },
    {
      n: 43, id: 'read-only', title: 'Read-only after the free week', group: 'Subscription',
      notes: [
        'Still works: Reels and every reel page, watching clips, Shooting mode (it keeps collecting, so no clip is missed), To tag as a list, references, status changes, Done editing (so VN copies can always be cleaned up), deleting, Settings, export and import.',
        'Needs a plan: tagging (Start tagging, Tag scene, the tag player, Skip all), Edit video (sending to editors), Add videos, Add earlier videos, and New reel.',
        'A locked action opens one sheet that names what needs the plan and repeats that nothing is lost. See plans is the main button, Not now closes it.',
        'Reels and To tag show a quiet read-only banner (info colours, not an error) with See plans.',
      ],
      spec: { 'See plans': 'Plans (screen 41).', 'Not now, Back': 'Closes the sheet.' },
      states: [
        { id: 'home', label: 'Reels', setup: (s) => set(s, ENDED) },
        { id: 'totag', label: 'To tag', setup: (s, u) => { set(s, ENDED); go(u, 'totag'); } },
        { id: 'tag', label: 'Locked: tagging', setup: (s, u) => { set(s, ENDED); go(u, 'totag'); u.sheet = { type: 'locked', ctx: 'tag' }; } },
        { id: 'send', label: 'Locked: Edit video', setup: (s, u) => { set(s, ENDED); go(u, 'reel', { id: 'r1' }); u.sheet = { type: 'locked', ctx: 'send' }; } },
        { id: 'reel', label: 'Locked: New reel', setup: (s, u) => { set(s, ENDED); u.sheet = { type: 'locked', ctx: 'reel' }; } },
        { id: 'add', label: 'Locked: Add videos', setup: (s, u) => { set(s, ENDED); go(u, 'reel', { id: 'r1' }); u.sheet = { type: 'locked', ctx: 'add' }; } },
        { id: 'big', label: '2× text: locked sheet', setup: (s, u) => { set(s, ENDED); go(u, 'totag'); u.sheet = { type: 'locked', ctx: 'tag' }; u.fs2 = true; } },
      ],
    },
    {
      n: 44, id: 'subscription', title: 'Settings: Subscription', group: 'Subscription',
      notes: [
        'A new first group in Settings. The page shows where the person stands, in words, and what to do next.',
        'Changing plan, cancelling and fixing a payment happen in Google Play (Manage in Google Play), as Play requires for subscriptions; TakeTray does not rebuild them.',
        'With no server, the app only knows what Google Play tells it on the phone: which plan is active, whether it will renew, or that a payment is pending. So it says "renews automatically" and leaves dates to Google Play.',
        'Payment problems: during Google Play\'s grace period everything keeps working and Google Play shows its own message in the app (in-app messaging). If the plan then lapses, TakeTray shows "Your plan has ended", read-only, with Fix in Google Play.',
      ],
      spec: { 'Restore purchase': 'Asks Google Play again.', 'Manage in Google Play': 'Opens Play › Payments & subscriptions for TakeTray.' },
      states: [
        { id: 'trial', label: 'Free week', setup: (s, u) => go(u, 'subscription') },
        { id: 'yearly', label: 'Yearly plan', setup: (s, u) => { set(s, { st: 'active', product: 'yearly', renew: '2027-10-12' }); go(u, 'subscription'); } },
        { id: 'monthly', label: 'Monthly plan', setup: (s, u) => { set(s, { st: 'active', product: 'monthly', renew: '2026-11-12' }); go(u, 'subscription'); } },
        { id: 'cancelled', label: 'Cancelled, still active', setup: (s, u) => { set(s, { st: 'cancelled', product: 'monthly', renew: '2026-11-12' }); go(u, 'subscription'); } },
        { id: 'lapsed', label: 'Plan ended (read-only)', setup: (s, u) => { set(s, { st: 'lapsed', product: 'monthly' }); go(u, 'subscription'); } },
        { id: 'ended', label: 'Free week ended', setup: (s, u) => { set(s, ENDED); go(u, 'subscription'); } },
        { id: 'pending', label: 'Payment pending', setup: (s, u) => { set(s, { st: 'pending', product: 'yearly' }); go(u, 'subscription'); } },
        { id: 'settings', label: 'Settings row, subscribed', setup: (s, u) => { set(s, { st: 'active', product: 'yearly', renew: '2027-10-12' }); go(u, 'settings'); } },
        { id: 'lapsed-home', label: 'Reels: plan ended', setup: (s) => set(s, { st: 'lapsed', product: 'monthly' }) },
        { id: 'big', label: '2× text', setup: (s, u) => { set(s, { st: 'active', product: 'yearly', renew: '2027-10-12' }); go(u, 'subscription'); u.fs2 = true; } },
      ],
    },
    {
      n: 45, id: 'purchase', title: 'Buying and restoring', group: 'Subscription',
      notes: [
        'Subscribe opens Google Play\'s own purchase sheet (drawn here as a stand-in; the real one is system UI with the person\'s payment methods, including UPI Autopay).',
        'Success: a short dialog with the plan and renewal date, then back where they were, with everything unlocked.',
        'Cancelled in Play: back to Plans, nothing said. Pending (for example UPI waiting for approval): read-only stays, with "Payment pending" until Play confirms. Error: a banner on Plans that says nobody was charged.',
        'Restore purchase: asks Play; if nothing is found, a dialog explains the Google account point.',
      ],
      spec: { Subscribe: 'Google Play decides; TakeTray waits for its answer.', Done: 'Closes the dialog.' },
      states: [
        { id: 'play', label: "Google Play's purchase sheet", setup: (s, u) => { plans(u, { phase: 'buying' }); u.sheet = { type: 'gplay', product: 'yearly' }; } },
        { id: 'done', label: 'Subscribed', setup: (s, u) => { set(s, { st: 'active', product: 'yearly', renew: '2027-10-12' }); plans(u); u.dialog = { type: 'subDone' }; } },
        { id: 'fail', label: "Error: couldn't finish", setup: (s, u) => plans(u, { buyErr: true }) },
        { id: 'restore-none', label: 'Restore: nothing found', setup: (s, u) => { go(u, 'subscription'); u.dialog = { type: 'restoreNone' }; } },
        { id: 'restored', label: 'Restore: found', setup: (s, u) => { set(s, { st: 'active', product: 'yearly', renew: '2027-10-12' }); go(u, 'subscription'); u.snack = { text: 'Your subscription is active', ic: 'check_circle' }; } },
        { id: 'big', label: '2× text: subscribed', setup: (s, u) => { set(s, { st: 'active', product: 'yearly', renew: '2027-10-12' }); plans(u); u.dialog = { type: 'subDone' }; u.fs2 = true; } },
      ],
    },
  );
})();
