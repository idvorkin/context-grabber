# Tabbed App + Roles — Design Spec

**Status:** Proposed
**Date:** 2026-05-25
**Owner:** Igor

---

## Summary

Reshape Context Grabber from a single-screen home into a five-tab app. Today is a glance + Grab Context surface. Body, Move, Mind, Places organize existing data by domain. A new **Roles** tab makes Igor's eulogy a living dashboard — each of the 11 eulogy roles is shown with this-week activity, time-since-last-shown, the eulogy passage, and concrete suggestions for the week ahead.

The redesign is **overlay on existing data**. Almost nothing new is collected — HealthKit, locations, journal, gym timer, and gratitude already produce the signals. Roles aggregates them through Igor's eulogy lens and adds two small new persistence stores: tagged moments and weekly intentions.

## Goals

- **Make the eulogy ambient.** Igor opens the app at 5am and sees, at a glance, who he's been being and who's gone quiet — in his own language, not "heart rate" but "Fit fellow."
- **Replace the single home screen with thoughtful surfaces** for body, places, mind, and movement that don't require Igor to do arithmetic on raw metrics to feel oriented.
- **Surface the eulogy passages inline** so the app talks like Igor talks about himself ("grandmother mind," "$1000 weight pledge," "Tori-light, Igor-heavy").
- **Make Grab Context narrate roles first.** What gets exported to Larry leads with "Husband-to-Tori dim, Father-to-Amelia missing arboretum walks" — not raw metric rows.

## Non-goals

- No streaks, no badges, no red X on missed days. Discipline falls off the wagon, starts again — the UI says "Last shown 11 days ago," never "Broken streak."
- No score, leaderboard, or judgmental ranking of roles. Roles have activity intensity, not pass/fail.
- No new data sources in v1. No calendar, photos, contacts, or messages. Auto-detection works only off data Context Grabber already collects; manual tagging covers the rest.
- No new HealthKit types. v1 ships with current permissions.
- No native nav library (react-navigation). Hand-rolled tab state.

---

## Tone & Philosophy

Following the existing user-needs doc:

- **Capture implicitly.** The app observes; it does not pester. No daily prompts. No notifications unless Igor opts in.
- **Observe, don't judge.** Numbers and time-since stamps; never adjectives like "great" or "poor."
- **Time-since over compliance.** "Last meditated 4 days ago" is more useful than "2 of 7 days."
- **Patterns over streaks.** 5-day rolling averages and 52-week heatmaps; no day-count chains.
- **Grandmother mind in the copy.** Suggestions, not commands. "Sat 7:30pm — bookstore café reopened" not "You should go on a date Saturday."

---

## The five tabs

### Today

The current home, polished. The day's headline in a sentence ("Light start — 6,002 steps in, no workout yet. Slept 7.2h after midnight."). A **Grab Context** card that is the headline action — preview of what's about to be sent, fresh/stale chip, one tap to share. A week-at-a-glance strip. Quick-capture tiles that jump into the relevant tab (Gratitude → Mind; Gym Timer → Move; Where today → Places).

The gear icon top-right opens Settings (today the SettingsModal).

### Body

All HealthKit metrics, organized by Larry's signal priority — exercise + HR up top, sleep with the asleep-vs-in-bed split, meditation as the early-warning signal, weight trend, then the rest. A week strip across the top. Tapping any metric opens the existing MetricDetailSheet behavior.

The sleep card shows asleep hours and in-bed hours as two values (the existing 25.2-hour bug fix), with sleep-efficiency derived. HRV and resting heart rate are surfaced as first-class cards.

### Move

Gym Timer + Workout Analysis + this-week's exercise minutes ring. The 4 timer presets (30s, 1min, 2min, 5-1) are the headline. Recent workouts list below with HR curve, duration, energy, optional note. Surfaces patterns the current app buries.

### Mind

Journal (text + voice), Affirmation, Gratitude, Tally Counter, **meditation flatline card** as the early-warning signal. Plus a new lightweight **mood/energy 1–5 self-report** that takes ~3 seconds to log and stores to SQLite. Recent journal entries thread below with audio playback inline.

### Places

Map + today/yesterday timeline + Known Places CRUD + background tracking toggle + retention stepper + Export DB. Map is a stylized SVG in v1 — no Apple Maps key, no react-native-maps. Same data as today, organized as a real screen instead of a modal.

The map also surfaces **today's path** as a polyline overlay: today's visited places connected in chronological order by a thin tinted line, with a small dot at each breadcrumb. Known-place pins and the current-location pin stay rendered on top. When today's path has 0–1 stays, the map renders exactly as before (pins only) — the overlay is purely additive.

### Roles

The new tab. See its own section below.

---

## Roles — deep dive

### What a Role is

A role is an identity thread from Igor's eulogy. Not a goal (goals end). Not a metric (metrics measure one thing). Not a habit (habits are mechanical). The Roles tab is a *living margin note* on idvork.in/eulogy.

The 11 roles are exactly the ones in the eulogy, in eulogy order:

1. Dealer of smiles & wonder
2. Mostly car-free spirit
3. Disciple of 7 habits
4. Fit fellow
5. Emotionally healthy human
6. Technologist
7. Professional
8. Family man
9. Husband to Tori
10. Father to Amelia
11. Father to Zach

Each has a color, a raccoon illustration (from idvork.in/images/raccoon-*.webp where present, Tabler icon fallback otherwise), and a hardcoded eulogy passage.

### Horizon switcher

A two-state segmented control at the top: **This week** / **This year**.

### This-week view

- A **constellation hero** — 11 colored role dots arranged on a faint ellipse. Dot size encodes this-week activity score; dimmed (50%) when the role needs attention. Tap a dot → role detail.
- **"Living my eulogy"** headline naming the 1–2 brightest and 1–2 quietest roles in Igor's own colors ("Strong as Technologist + Fit fellow. Quiet as Husband & Smiles & wonder.").
- **Needs attention** section — cards for any role flagged as quiet (see Attention rules below). Each card shows the role, eulogy markers, a suggested moment for the week, and links into detail.
- **All 11 roles · this week** — every role as a row with small avatar, name, week activity sentence ("3 gym · 6 days weighed · 7.1h avg"), last-shown timestamp, and a 7-bar week sparkline.
- **Weekly review card** — Sunday 5am promise. Quote the eulogy line about discipline. Schedule / Skip buttons.

### This-year view

- **11 × 52 heatmap** — each row is a role, each cell is a week, color intensity encodes that week's activity score. Tap any row → role detail. This is the answer to "am I living my eulogy?"
- **Year in three numbers** — brightest role, dimmest role, most-variable role, weekly reviews logged.

### Role detail sheet

Opens when Igor taps a role anywhere — constellation, list row, heatmap row, attention card. Slides up over the tab.

- Big avatar + role name + 3 identity-marker chips (e.g. for Tori: "when Igor met Tori · lifelong partner · Tori-light, Igor-heavy")
- **Eulogy passage** as a left-bordered block quote — verbatim from idvork.in/eulogy
- **This week** signals grid (2-up) — each signal shows label, value, trend chip, last-shown
- **52-week strip** with current-week ring, plus three small summary numbers (52-wk avg, best week, quiet weeks)
- **Bring it back this week** — 2–3 suggested moments, each with role-color left bar and an Add button (v1: Add does nothing visible yet; v2: writes to Calendar)
- **Set an intention** composer — textarea prompted in eulogy voice ("What does being husband to Tori look like this week?"). Save persists to SQLite; surfaces on Today next week.
- **Recent moments** log — most recent tagged moments for this role

### Attention rules

A role is flagged "needs attention" when ANY of:

- **Time-since-last-shown** exceeds the role's threshold (e.g. Husband to Tori: 7 days, Fit fellow: 5 days, Emo: 3 days)
- **This week's activity score** is < 25/100 AND last week's was also < 25
- **A flatline signal fires** (meditation: 3+ days since last sit; date night: 14+ days)

Attention shows as a warm chip ("Last shown 11 days ago") and dims the constellation dot. Never red. Never an alarm.

### Auto-detection (v1, signal → role)

| Source | Mapped roles |
|---|---|
| HealthKit workout / exercise minutes | Fit fellow |
| HealthKit weight log | Fit fellow |
| HealthKit sleep ≥ 6h | Emo (via 5am wake), Fit fellow |
| HealthKit mindful sessions | Emo |
| Gratitude entry | Emo |
| Journal entry (no role tag) | Emo |
| GymTimer session completed | Fit fellow |
| Location: walking distance > 2km/day | Car-free |
| Location: matched "Office" known place | Professional |
| Location: matched "Gym" known place | Fit fellow |
| Location: matched "Home" entire weekend | Family man, Husband, Father×2 (light) |
| App install/build commits (future) | Technologist |
| **Manual tag** (long-press journal entry → role picker) | Any |

Anything not covered auto-detects as nothing — the user manually tags. Smiles & wonder, Family man specifics, kids' moments, husband moments all rely on manual tags in v1.

### Manual tagging UX

From any journal entry, gym workout, or Today event, long-press → "Tag as moment for Role…" → role picker → optional one-line caption. Saves to `role_moments` SQLite table. Surfaces in the role detail's Recent moments and contributes to the week's activity score.

### Intentions

An intention is a one-sentence weekly aim, set in the role detail composer. Stored with `role_id`, `week_start_date`, `text`. Surfaces on Today's hero on the week it applies. Does not auto-evaluate or judge.

---

## Larry context export

The `Grab Context` JSON gains a **roles** section at the top. Reads like:

```
ROLES THIS WEEK
- Fit fellow (strong): 3 gym, 6 weighed days, 7.1h sleep avg
- Technologist (strong): 12 commits, 1 pet-project session
- Husband to Tori (quiet, last shown May 14): 0 date nights, 48m 1:1
- Father to Amelia (quiet): no arboretum walk, 1 photo outing
- ... rest, with time-since on any role attention-flagged
ATTENTION
- Husband to Tori: no date night since May 14. Sat 7:30pm bookstore café open.
- Father to Amelia: no arboretum walk this week. Mon afternoon free.
INTENTIONS (set for this week)
- (any saved intentions)
```

This block leads the export, before the raw HealthKit + location summary that exists today. Larry sees the human framing first, the numbers as supporting evidence.

---

## Settings access

Gear icon in Today's nav bar opens the existing SettingsModal. No changes to settings content in this redesign.

---

## Acceptance criteria

A QA-style checklist; testable without seeing the code.

### Tab shell

- [ ] App has a bottom tab bar with 6 tabs in order: Today, Body, Move, Mind, Places, Roles
- [ ] Tab bar is visible on all screens and shows active state with role-thread color
- [ ] Each tab is a separately scrollable view
- [ ] Gear icon top-right of Today opens SettingsModal
- [ ] Tab state persists across foreground/background; cold launch returns to Today

### Today

- [ ] "Day in a sentence" headline references today's actual data (steps, sleep, time-since meditation)
- [ ] Grab Context card shows last grab timestamp and Fresh / Stale chip (stale > 4h)
- [ ] Grab Context button works exactly as it does today; Share Sheet identical
- [ ] Week-at-a-glance strip shows Mon–Sun with today highlighted; each day shows gym/no-gym dot
- [ ] At least one quick-capture tile jumps to the right tab when tapped
- [ ] Steps · last 7 days teaser shows sparkline + WoW delta

### Body

- [ ] All metrics from the current home are present and accurate
- [ ] Sleep card shows asleep hours, in-bed hours, and sleep efficiency separately
- [ ] HRV and resting heart rate are first-class cards (not in the detail sheet only)
- [ ] Tapping any card opens MetricDetailSheet with the existing chart + breakdown behavior
- [ ] Week strip across the top is interactive (taps select a day in the detail sheet)

### Move

- [ ] All 4 Gym Timer presets are visible and start the existing timer flow
- [ ] Recent workouts list shows duration, avg HR, max HR, energy
- [ ] This week's exercise minutes ring matches the existing computation
- [ ] Tap a workout → opens WorkoutAnalysisScreen for that session

### Mind

- [ ] Journal, Affirmation, Gratitude, Tally Counter all reachable from this tab
- [ ] Meditation flatline card shows time-since last mindful session and the eulogy line about meditation
- [ ] Mood/energy self-report tile takes ≤ 3 taps to complete a 1–5 rating
- [ ] Mood entries persist across app restart
- [ ] Voice journal playback works inline on entries

### Places

- [ ] Today + Yesterday timeline shows all clusters with start/end times
- [ ] Known Places CRUD works exactly as the existing LocationDetailSheet
- [ ] Background tracking toggle, retention stepper, Export DB present and functional
- [ ] Map renders as a stylized SVG (no Apple Maps); pins anchor to known places
- [ ] When today has 2+ stays, the map overlays a path polyline (line + dots) connecting them in time order; the current-location and known-place pins still render on top
- [ ] When today has 0 or 1 stays, no path overlay is drawn (map renders as it did before this feature)

### Roles

- [ ] All 11 roles render with avatar + color from the eulogy
- [ ] Horizon switcher toggles between Week and Year views
- [ ] Constellation dots are sized by activity; dim when attention-flagged
- [ ] Tapping any role row opens the role detail sheet
- [ ] Detail sheet shows eulogy passage verbatim
- [ ] Detail sheet's 52-week strip renders with current week ringed
- [ ] At least one auto-detected role has non-zero activity this week (Fit / Tech / Carfree / Emo) based on real data
- [ ] Intention composer saves and surfaces on Today the same week
- [ ] Long-press a journal entry → role picker → tagging works; tagged moment appears in role detail
- [ ] Attention rules fire correctly: meditation flatline at 3+ days; husband at 7+ days no tagged moments
- [ ] Year heatmap renders 11 × 52; tap a row opens detail

### Grab Context export

- [ ] Exported JSON includes a `roles` section at the top
- [ ] Roles section lists all 11 roles with this-week activity + last-shown
- [ ] Attention-flagged roles surface with their reason
- [ ] Saved intentions appear in the export
- [ ] Existing HealthKit + location summary is unchanged below the new section
- [ ] `share.test.ts` updated with snapshot of the new export shape

### Tone & non-goals

- [ ] No streak counters, no flame icons, no red error badges anywhere in Roles or Mind
- [ ] No "you missed X" or "you're behind" copy
- [ ] All errors render via CopyableError
- [ ] No new HealthKit permissions requested in v1

---

## Open decisions (resolve before plan execution)

1. **Tabs order** — Today / Roles / Body / Move / Mind / Places, or move Roles to position 2? Spec assumes Roles last; reorder if Roles should be the lead.
2. **Auto-detection ambition** — start with the minimum table above, or push for git-commit detection (would need an external trigger) in v1?
3. **Role weighting** — should Igor be able to mark roles as "season priority" so attention thresholds tighten? Default no; revisit in v2.
4. **Intentions UX** — surface on Today only, or also a dedicated Intentions list in Roles? Default: Today only.
5. **Raccoon images** — load from idvork.in URLs at runtime, or bundle into `assets/`? Recommend bundle (offline support, faster startup, eulogy may rotate images).

---

## Out of scope

- Calendar / photo / SMS integration for auto-tagging (v2)
- Larry agent endpoint configuration (already future work)
- Push notifications / nudges (out of scope per Capture Implicitly)
- Live Activity surfacing roles (future)
- Multi-user / shared roles (never)
