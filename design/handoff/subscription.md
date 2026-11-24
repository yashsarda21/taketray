# Free week and subscription: handoff

Owner-approved design change of 22 Nov 2026 (D-150). It replaces D-11 ("Version 1 is free, no payments").

- **Hub:** screens 41–45, group "Subscription".
- **Prototype:** Start from: "Free week and subscription". The panel's Simulate buttons "Free week ends tomorrow" and "Free week ends" step through the end of the week.
- **Source:** `design/prototype/assets/subs.js` and the "Free week and subscription" section at the end of `assets/proto.css`.

## The owner's rules

| Rule | Decision |
|---|---|
| Free week | 7 days from the first launch. **No card, nothing to sign up for.** TakeTray keeps the dates on the phone. Reinstalling starts a new week; the owner accepted that, since the reels are lost with a reinstall anyway. |
| Prices | Regular: monthly **₹149**, yearly **₹1,199**. **First-year launch offer:** ₹129 a month for the first 12 months, ₹899 for the first year, then the regular price. The regular price shows crossed out only because people really pay it afterwards. Set in Play Console; the app shows Google Play's localized prices and never hard-codes them. |
| Cancel | **Cancel anytime** is said plainly: above the Subscribe button, in the free-week sheet, in the success dialog and on the Subscription page. |
| After the free week, without a plan | **Read-only**. Nothing is deleted or hidden. |
| First mention | After the first tagging session that tags at least one clip, once. Not at onboarding. |

## What read-only allows

**Still works:**
- Reels and every reel page.
- Watching clips.
- **Shooting mode, which keeps collecting**, so no clip is missed.
- To tag as a list.
- References.
- Status changes.
- **Done editing**, so VN copies can always be cleaned up.
- Deleting reels and clips.
- Settings.
- Export and import.

**Needs a plan:**

| Action | Locked sheet text (`ctx`) |
|---|---|
| Start tagging, playing a clip into the tag player, Tag scene, Skip all | `tag`: "Subscribe to tag clips" (the text includes the To tag count) |
| Edit video (sending to CapCut / Edits / VN / share) | `send`: "Subscribe to send reels" |
| Add videos, Add earlier videos | `add`: "Subscribe to add videos" |
| New reel (on Reels and in the tag player) | `reel`: "Subscribe to plan new reels" |

A locked action opens **one sheet** (screen 43):
- It says what needs the plan.
- It repeats that the person's reels and clips are safe.
- See plans is the filled button; Not now closes the sheet.

While a payment is pending, the sheet says "Payment pending" and offers only OK.

Reels and To tag show a quiet read-only banner (`TtBanner` info) with See plans (tonal, small).

## Screens

| # | Screen | Notes |
|---|---|---|
| 41 | **Plans** | Full-screen route. Close (✕) at the top left. |
| 42 | **Free week** | The once-only sheet, the "ends tomorrow" banner on Reels, the reminder notification, and the Settings row. |
| 43 | **Read-only** | The banners and the locked sheet in all four contexts. |
| 44 | **Settings › Subscription** | A new first group in Settings, plus the Subscription page in every state. |
| 45 | **Buying and restoring** | Google Play's purchase sheet (system UI, drawn as a stand-in), success, error, and restore. |

### Plans (41)

**Order** (the plans are above the fold at 360 × 800):
1. Title and one line.
2. The error or pending banner, when there is one.
3. **Choose a plan**: radio cards.
4. **Your subscription includes**: four lines, then the "Always free" note.
5. Restore purchase · Terms · Privacy.
6. A sticky bottom bar.

**Titles:**
- During the free week: "Keep sorting after your free week", with the line "Free until {Fri 16 Oct}. If you subscribe now, your plan starts today."
- After the free week: "Your free week has ended", with the line "Your reels and clips are safe. Subscribe to keep tagging new clips and sending reels to your editor."
- After a plan lapses: "Your plan has ended".

**Plan cards** (`role="radio"` inside a `radiogroup`, 72 dp min):
- "Choose a plan" carries a **Launch offer** tag (tertiaryContainer) when Play returns the offer.
- **Yearly** is picked by default and marked "Best value". Price: ~~₹1,199~~ **₹899**, first year. Sub-line: "About ₹75 a month in your first year. Then ₹1,199 a year."
- **Monthly**. Price: ~~₹149~~ **₹129**, a month. Sub-line: "For your first 12 months. Then ₹149 a month."
- **No offer** (Play says the account isn't eligible because it subscribed before): the regular prices only, no cross-out, no tag. Sub-lines "About ₹100 a month, billed once a year" and "Billed every month".
- **Screen readers:** a `<s>` isn't announced, so each card has a full label, for example "Yearly, best value, launch offer ₹899 first year, regular price ₹1,199. About ₹75 a month in your first year. Then ₹1,199 a year."

**Bottom bar:**
- Above the button: **"Cancel anytime** in Google Play. You keep everything until the end of the time you paid for." (a check icon in primary).
- **Subscribe for {₹899 for the first year}** (monthly: "₹129 a month"), a large filled button.
- Under it, the full terms: "Launch offer: ₹899 for your first year, then ₹1,199 a year. Renews automatically through Google Play." This is Play's subscription-disclosure rule: price, period, what it changes to, renewal and how to cancel.
- After the free week only: **Continue read-only** (a text button).
- At large text (font scale ≥ 1.5) the bar scrolls with the page instead of staying fixed.

**Other states:**
- **Loading:** the prices are skeleton cards, and the button reads "Subscribe" and is off.
- **Error:** banner "Couldn't reach Google Play / Check your connection and try again." with Try again.
- **Buying:** the button reads "Opening Google Play…" with a spinner.
- **Couldn't finish:** banner "Couldn't finish the purchase / You weren't charged. Try again."
- **Pending:** callout "Payment pending…", and the button is off.

### Free week (42)

**The once-only sheet**, shown after the first tagging session (on leaving the tag player with ≥ 1 clip tagged):
- Title "You're on your free week".
- Then "Nice, your first clips are in their reels. TakeTray is free until {date}, with no card needed."
- Seven-segment day bar, labelled "Day 4 of 7 · 4 days left".
- Three lines: the reminder, the prices, and "stays yours".
- **Got it** (filled) and See plans (text).

**The day before the free week ends:**
- **One notification at 10:00**, channel Reminders, only if notifications are allowed. "Your free week ends tomorrow / Choose a plan to keep tagging. Your reels stay safe either way." Its action is "See plans".
- A **banner on Reels** (attn), from then until the week ends.

**When the week ends:** the next time TakeTray comes to the front, Plans opens once (`from: ended`). Store a flag so it isn't shown again.

### Settings › Subscription (44)

The first group in Settings is "Subscription". The row reads:
- during the free week: "Free week and plans · {n days left}";
- with a plan: "TakeTray subscription · Yearly · renews automatically".

**Page states:**

| State | What the page shows |
|---|---|
| Free week | Days left, the day bar, See plans. |
| Read-only | See plans. |
| Monthly / Yearly | "renews automatically"; **Manage in Google Play**. |
| Cancelled (won't renew) | **Keep my plan**, which opens Play. |
| Plan ended (lapsed) | See plans and **Fix in Google Play**. |
| Pending | — |

**Purchases group:**
- Restore purchase.
- Google Play subscriptions (shown when there is no plan).
- The note "Cancel any time in Google Play. You keep everything until the end of the time you paid for, and your reels and clips are never deleted."

Changing plan, cancelling and fixing a payment happen in Google Play. Use the deep link `https://play.google.com/store/account/subscriptions?sku=<productId>&package=app.taketray`.

### Buying and restoring (45)

- **Success:** dialog "You're subscribed / {Yearly} plan: {₹899 for your first year, then ₹1,199 a year}. Next payment on {date}. You can cancel anytime in Google Play. / Thanks for supporting TakeTray." The terms come from the offer that was bought, and the date is the purchase time plus the period, both known at that moment. Done returns the person to where they were, now unlocked.
- **Cancelled in Play:** back to Plans, with no message.
- **Restore:**
  - With a plan: the snack "Your subscription is active".
  - Without: dialog "No subscription found / There's no TakeTray subscription on the Google account signed in to Play. If you subscribed with another account, switch to it in the Play Store, then try again."

## Google Play setup

**Two subscription products**, each with one auto-renewing base plan and one launch offer:

| Product | Base plan | Launch offer (`launch`) |
|---|---|---|
| `taketray_monthly` | P1M, ₹149 | Discounted recurring phase: ₹129 a month for 12 cycles, then the base plan. |
| `taketray_yearly` | P1Y, ₹1,199 | Discounted phase: ₹899 for 1 cycle (the first year), then the base plan. |

**Offer eligibility:** new customer acquisition (never had that subscription). Play then hides the offer from returning subscribers, and the app shows the regular prices.

**Buying:** pass the offer's `offerToken` when it exists, otherwise the base plan's.

**Why two products and not one product with two base plans:** with no server, the app only sees a purchase's product ID. It cannot see which base plan was bought.

**Other settings:**
- **No Play free-trial phase.** The free week is TakeTray's own.
- **Keep Play's grace period and account hold on** (the defaults).

## Building it (no server)

- **Library:** Flutter `in_app_purchase` (the official plugin). It wraps Play Billing Library.
  - On start and on resume: query purchases (restore), then call `showInAppMessages` (TRANSACTIONAL). During a grace period, **Google Play itself** shows the "payment declined" message in the app; TakeTray draws nothing for it.
  - **Acknowledge** every purchase (`completePurchase`) within 3 days, or Play refunds it.
- **Entitlement**, computed on the phone:

  | State | When |
  |---|---|
  | `trial` | No purchase, and `now < trialStart + 7 days`. |
  | `active` | A `PURCHASED` purchase of either product with `autoRenewing` true. |
  | `cancelled` | A `PURCHASED` purchase with `autoRenewing` false. It still unlocks; Play drops the purchase from the query when it expires. |
  | `pending` | `PENDING` (for example UPI Autopay waiting for approval). It stays locked. |
  | `lapsed` | A purchase was seen before, and none is now. |
  | `ended` | The free week is over, and no purchase was ever seen. |

  `pending`, `lapsed` and `ended` are read-only.
- **Offline:** Play answers purchase queries from the Play Store's cache. If Play can't be reached at all (billing unavailable), keep the **last known entitlement**, stored with the time of the last successful check, for up to 7 days.
- **Free week clock:**
  - Store `trialStartedAt` at the first launch, with the onboarding state.
  - Store `latestSeenAt` as the largest "now" ever seen, and use `max(now, latestSeenAt)`, so moving the phone's clock back doesn't extend the week.
- **Purchase check:** verify each purchase's signature on the phone with the app's Play licence public key (from Play Console). Without a server, a determined person can get around client-side checks; that's accepted for v1.
- **Internet permission:**
  - I couldn't confirm whether Play Billing Library merges `android.permission.INTERNET` into the app. Billing itself runs through the Play Store app.
  - After adding the plugin, **check the merged manifest** (`app/build/intermediates/merged_manifests/`).
  - If INTERNET appears, test whether billing still works with it removed (`tools:node="remove"`). Either way, record the result in D-150 and keep every privacy claim true.
- **Wording that must change when this ships:** "free / no in-app purchases" appears in
  - README.md ("v1 is free"),
  - the Play listing,
  - the website design's FAQ and hero tags,
  - the privacy policy (add: "Payments are handled by Google Play under Google's privacy policy; TakeTray never sees your payment details").

## Screen reader labels

- **Plan card:** "Yearly, ₹899 a year, save 41%, about ₹75 a month, billed once a year", radio, selected.
- **Day bar:** "Day 4 of 7".
- **Spinner:** "Opening Google Play".
- **Locked sheet:** the title is the dialog's label.
- **Read-only banner:** a region labelled "Read-only".

## Tests to write

- **Unit:** the entitlement table above; the clock rollback; the 7-day last-known window.
- **Widget:**
  - each locked action opens the right sheet;
  - read-only still allows Shooting mode, Done editing and export;
  - the once-only sheet and the once-only Plans screen;
  - Plans in every state.
- **Goldens:** screens 41–45, light and dark, at 1× and 2×.
- **On the S24:** a real test purchase with a licence tester, both products, restore, cancel, and pending (a slow test card).
