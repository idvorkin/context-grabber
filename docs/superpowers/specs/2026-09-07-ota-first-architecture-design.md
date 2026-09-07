# OTA-first: how much of the app can ship over the air — a review

> **Status:** Review and decisions, 2026-09-07. Igor: *"Review code to see if
> we can make more of it OTA deployable, that's the goal of this
> architecture."* Three changes are made in the same commit; two larger ones
> are proposed with their trade-offs.

## What "OTA-deployable" means here

An over-the-air update replaces the JavaScript bundle and its assets (sounds,
images) on a phone that already has a binary. It cannot add a native module,
change Swift, change a pod, or change a patch. So the goal has two halves:

1. **Keep as much as possible in JavaScript.** Native code should be a small
   set of *capabilities* (play a file, read a sensor, write to the App Group,
   draw a widget from data); what the app *does* with them is JavaScript.
2. **Never let a bundle land on a binary it does not fit.** A bundle that
   imports a module the binary lacks crashes at launch. Two guards: the
   runtime version, and defensive imports.

## Today's work, sorted

| Shipped | Native or OTA | Why |
|---|---|---|
| The memdeck deal, the card tab, the deep link, "Think of a card" | OTA | JavaScript |
| The LED timer face, the turn classifier, the duck window, the log | OTA | JavaScript |
| The cues as sound files, and the words in Igor's voice | OTA | assets ride in the bundle |
| The widgets (card on Today, the lock-screen card) | native | WidgetKit is Swift; no JS runs in a widget |
| The tap-to-deal intent | native | App Intents are Swift |
| The deal bridge methods on `WidgetBridge` | native | a new bridge method is Swift |
| The accelerometer package | native | a new pod |
| The notify-on-deactivation hunk in the audio-library patch | native | a patch |

Of eight things, four needed a native build. Two of those four could have
been avoided with the proposals below; the pod and the patch could not.

## Changes made now

**1. A date-based runtime version, bumped with every native change.** Every
binary so far carried runtime version `1.0.0`, so a bundle published today
would have reached a binary from May — one without the sensor package, and
the timer screen would have failed to load. The runtime version is now the
build date (`scripts/bump-runtime-version.sh`, one command, both files),
and an OTA bundle only reaches binaries with the same one. Rule: **any
change under `ios/`, `modules/`, `patches/`, `package.json`, or `app.json`
bumps the version.** `just deploy` refuses to build when `app.json` and
`Expo.plist` disagree.

**2. `just ota` refuses to ship a bundle whose native surface changed.**
`just deploy` records the commit it installed (`.native-build-sha`, local to
the Mac); `just ota` diffs the native surface from that commit to `HEAD` and
stops with the file list when anything moved. The two guards overlap on
purpose: the first protects other phones, the second protects this one from
a forgotten deploy.

**3. Optional natives are required lazily, behind a guard.** The pattern
was already in the repo (`lib/gistToken.ts` for the Keychain,
`modules/audio-route` for the call): `require` inside a function, in a
`try`, returning `null` when the binary lacks the module, and every caller
degrading — the token reads as absent, the route list is empty. The
accelerometer joins it: on a binary without the sensor package the timer
simply never turns. A module imported at the top of a file that the binary
lacks is a crash at launch; the rule is **no top-level import of a module
that any supported binary might lack.** (With rule 1 in force this is a
belt for the braces; it is cheap.)

## Proposed — the two that would have saved native builds today

**A. Widgets that render what JavaScript wrote.** Today's Today widget reads
ten fixed keys from the App Group; the card widgets deal their own card in
Swift. The alternative: JavaScript writes a *timeline* to the App Group —
a list of `(date, text, colour, link)` entries covering twelve hours — and
one generic Swift widget renders whichever entry is current. Then a new
prompt (a word of the day, an affirmation, the next role, a quote) is a
JavaScript change and an OTA, never Swift. The memdeck deal would move to
TypeScript (with its no-repeat and fairness promises tested in jest rather
than under `swiftc`); the card widget becomes the generic widget with a
card-shaped renderer, chosen by a `kind` field in the entry.
*Cost:* the widget no longer computes anything on its own, so it shows
what the app last wrote; a phone that has not opened the app in twelve
hours wraps around the list rather than dealing fresh. For a prompt that
is acceptable. *Gain:* every future widget-content idea ships OTA.

**B. A generic App Group bridge, and a generic intent.** `WidgetBridge`
grew three card-specific methods today; the next widget would grow three
more. Replace with `writeShared(key, json)`, `readShared(key)`,
`reloadWidgets(kinds)`. The tap-to-deal intent likewise becomes
`AdvanceCursorIntent`: bump one shared counter, reload the widgets; what
the counter *means* is JavaScript's business (which entry of the list is
"current"). With A and B in place, today's card feature would have been:
JavaScript writes the list, the generic widget renders it, the generic
intent advances it — zero Swift after the first time.

Both are a medium change (a day) and are worth doing before the *next*
widget, not retroactively for this one: the card widget works, and
rewriting it now spends a native build to arrive where we are.

## What stays native, honestly

- Drawing a widget (SwiftUI), and any in-widget action (an intent).
- Anything that needs a new pod: sensors, secure storage, audio session
  details the JavaScript APIs do not expose.
- Patches to native libraries (the echo-cancellation and notify-others
  hunks).
- The App Group entitlement, URL schemes, background modes, Info.plist.

Everything else — screens, logic, timing, files, wording, colours, deep
links, what the widgets *say* once A and B exist — is JavaScript, and
should stay that way.

## Acceptance criteria

1. A JavaScript-only change (say, a different cue voice) ships with
   `just ota` and is on the phone in minutes; `just deploy` is not needed.
2. After any commit touching `ios/`, `modules/`, `patches/`,
   `package.json` or `app.json`, `just ota` refuses with the list of files,
   until `just deploy` has run.
3. `just deploy` refuses when `app.json` and `Expo.plist` name different
   runtime versions; `scripts/bump-runtime-version.sh` makes them agree.
4. A bundle built for today's runtime version is never offered to a binary
   with an older one (EAS honours the version; nothing to check by hand).
5. On a binary without the sensor package, the timer screen opens and
   simply never turns; on one without the Keychain package, the token reads
   as absent; nothing crashes at launch.
