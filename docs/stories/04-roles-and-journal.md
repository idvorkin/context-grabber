# Roles and the journal: who I have been

Living the eulogy on a seven-day horizon: which of the eleven roles showed up, what I noticed and wrote down, and how a role becomes evidence rather than a label.

Part of the [user stories](README.md); persona and format are described there.

---

### User Story 060:

- **Summary:** See at a glance whether I am living my eulogy this week
- **Status:** implemented in [54861c5](https://github.com/idvorkin/context-grabber/commit/54861c5); verified by `roles.test.ts` and on the phone (daily use)

#### Use Case:
- **As a** Sunday-morning self about to review the week
- **I want to** open the Roles tab and see all eleven eulogy roles with how much each one showed up in the last seven days
- **so that** "who have I been being" is answered in one glance, in eulogy order, without a single judgment

#### Acceptance Criteria:
- **Scenario:** The week, read as roles
- **Given:** the app has grabbed context this week and a few moments have been tagged
- **When:** I open the Roles tab
- **Then:** every one of the eleven roles is listed with its raccoon avatar, its short name, an activity line ("3 gym · 6 days weighed") and a 0–100 score pill that is dimmed below 25 — and nowhere does the tab say "good week", "bad week", "streak" or "missed"

---

### User Story 061:

- **Summary:** Know where I have gone quiet, warmly
- **Status:** implemented in [54861c5](https://github.com/idvorkin/context-grabber/commit/54861c5); verified by `roles.test.ts` (attention thresholds) and on the phone

#### Use Case:
- **As a** husband who has not shown up as Husband to Tori in eleven days
- **I want to** have the Roles tab surface that role, with how long it has been, before I have to hunt for it
- **so that** the dimmest thread of the week becomes today's gentle nudge instead of a surprise in the Larry call

#### Acceptance Criteria:
- **Scenario:** A role past its threshold
- **Given:** no moment has been tagged to *Tori* for longer than that role's threshold (seven days)
- **When:** I open the Roles tab
- **Then:** a *Needs attention* card above the list names Tori with "Last shown 11 days ago" (up to three such roles), in the role's own colour, with no red badge and no count of days missed

---

### User Story 062:

- **Summary:** Tag a moment to one or more roles in about three seconds
- **Status:** implemented in [54861c5](https://github.com/idvorkin/context-grabber/commit/54861c5), [4afbfd5](https://github.com/idvorkin/context-grabber/commit/4afbfd5); verified by `roleMoments.test.ts` and on the phone

#### Use Case:
- **As a** father who just took Amelia to the arboretum
- **I want to** long-press the Amelia row (or tap *+ Tag moment*), add a one-line caption, and pick a second role if it fits
- **so that** the moment counts for every role it belonged to without me opening a journal

#### Acceptance Criteria:
- **Scenario:** One moment, two roles
- **Given:** the Roles tab is open
- **When:** I long-press *Amelia*, also select *Family* in the sheet, type "arboretum walk" and save
- **Then:** both Amelia's and Family's activity scores include the moment, it appears under each role's recent moments, and the sheet needed no more than the long-press, one extra chip and the caption

---

### User Story 063:

- **Summary:** Credit the roles I lived without tagging anything
- **Status:** implemented in [54861c5](https://github.com/idvorkin/context-grabber/commit/54861c5); verified by `autoDetect.test.ts` and on the phone

#### Use Case:
- **As a** lifter who went to the gym and meditated but never opened the Roles tab
- **I want to** have workouts count for *Fit* and meditation and journal entries count for *Emo* on their own
- **so that** capture stays implicit and the mirror is truthful even in a week I never tag a thing

#### Acceptance Criteria:
- **Scenario:** A gym day with no manual tagging
- **Given:** HealthKit holds a workout and a mindful session from today
- **When:** I press Grab Context
- **Then:** *Fit* shows a workout moment with the source chip `auto-workout` and *Emo* a mindful moment with `auto-mindful`, each recorded once even if I grab again

---

### User Story 064:

- **Summary:** Read what a role means and what it has looked like lately
- **Status:** implemented in [84e0943](https://github.com/idvorkin/context-grabber/commit/84e0943), [846af77](https://github.com/idvorkin/context-grabber/commit/846af77); verified on the phone

#### Use Case:
- **As a** man rereading his own eulogy
- **I want to** tap any role and see its eulogy passage, its week, and its recent moments in one sheet
- **so that** a role is a paragraph I wrote about who I want to be, not a score

#### Acceptance Criteria:
- **Scenario:** Opening a role
- **Given:** the Roles tab is open, its sub-header reading "Tap a role to see details · long-press to log a moment"
- **When:** I tap *Emotionally healthy human*
- **Then:** a sheet slides up with the avatar and full name, the verbatim eulogy passage as a tinted block quote with *Show more ▾* revealing the longer passage and identity-marker chips, this week's score and activity line, a *+ Tag a moment* button in the role colour, and the last twenty moments each with a time-since stamp and source chip (or an empty state inviting the first)

---

### User Story 065:

- **Summary:** Hear how I want to live, and keep hearing it while I do other things
- **Status:** implemented in [4586958](https://github.com/idvorkin/context-grabber/commit/4586958), [f1c252e](https://github.com/idvorkin/context-grabber/commit/f1c252e); verified on the phone

#### Use Case:
- **As a** man starting a Sunday review
- **I want to** play the eulogy song from the Roles tab and have it keep going when I switch tabs or lock the phone
- **so that** the review opens in my own voice instead of a spreadsheet's

#### Acceptance Criteria:
- **Scenario:** Play, then leave the tab
- **Given:** the Roles tab shows the *How I want to live* card with its gold play button
- **When:** I tap play, switch to the Today tab, and lock the phone
- **Then:** the song keeps playing through both, and back on Roles the progress bar and pause button reflect where it is

---

### User Story 066:

- **Summary:** Log an affirmation opportunity or did-it in one tap, by voice or text
- **Status:** implemented in [6e5de74](https://github.com/idvorkin/context-grabber/commit/6e5de74), [cee3c0e](https://github.com/idvorkin/context-grabber/commit/cee3c0e), [1c819cb](https://github.com/idvorkin/context-grabber/commit/1c819cb), [c246fd7](https://github.com/idvorkin/context-grabber/commit/c246fd7); verified by `journal.test.ts`, `VoiceRecorder.test.tsx` and on the phone (many times a day)

#### Use Case:
- **As a** man who just noticed a chance to be *An Essentialist*
- **I want to** open the Affirmation card from the Mind tab, pick Opportunity or Did It, and speak or type what I noticed
- **so that** the noticing is captured on the phone in the moment, not reconstructed at a desk later

#### Acceptance Criteria:
- **Scenario:** A spoken opportunity, saved mid-recording
- **Given:** the Affirmation card is open showing one of the four affirmations with its subtitle, rotated at random from last time, with a picker to swap it for this session only
- **and Given:** the tally at the top reads today's counts ("☀️ 0  ✓ 0  🙏 0")
- **When:** I pick Opportunity, tap the mic, speak for five seconds and tap Save without stopping the recording first
- **Then:** the clip is finalized and attached, the mic stops, the card closes, and the Journal shows the entry under today → Opportunities → *An Essentialist* with a play button and "0:05"

---

### User Story 067:

- **Summary:** Stack a gratitude without choosing anything
- **Status:** implemented in [6e5de74](https://github.com/idvorkin/context-grabber/commit/6e5de74); verified by `journal.test.ts` and on the phone

#### Use Case:
- **As a** man on a sunny morning walk
- **I want to** open the Grateful card and record or type "sunny walk" with no affirmation to pick and no context to choose
- **so that** gratitude is the fastest thing in the app

#### Acceptance Criteria:
- **Scenario:** One gratitude
- **Given:** the Mind tab is open
- **When:** I tap 🙏 Grateful, type "Sunny morning walk" and save
- **Then:** the card closes, the Journal lists it under today → Gratitudes → *Grateful*, and it survives a force-quit

---

### User Story 068:

- **Summary:** Rattle off several voice entries without re-tapping the mic
- **Status:** implemented in [d0cf794](https://github.com/idvorkin/context-grabber/commit/d0cf794); verified by `VoiceRecorder.test.tsx` and on the phone

#### Use Case:
- **As a** man with three reflections on the walk home
- **I want to** speak one, tap *Save & add another*, and find the mic already recording the next
- **so that** a burst of reflections is tap-speak-tap-speak, not tap-record-speak-stop-save-tap-record

#### Acceptance Criteria:
- **Scenario:** A streak by voice
- **Given:** the Affirmation card is open with the compact mic on the same row as Opportunity and Did It
- **When:** I tap the mic, speak, and tap *Save & add another*
- **Then:** the entry saves, the card clears, and the mic is already red and recording for the next one — while a text entry followed by *Save & add another* starts no recording, and plain *Save* while recording saves and closes the card

---

### User Story 069:

- **Summary:** Reread everything I have logged, grouped the way I think
- **Status:** implemented in [6e5de74](https://github.com/idvorkin/context-grabber/commit/6e5de74); verified by `journal.test.ts` and on the phone

#### Use Case:
- **As a** man before a Larry call
- **I want to** open the Journal and fold or unfold days, contexts and affirmations, play a voice note inline, and delete an entry I regret
- **so that** the affirmations stay the lens and I can zoom to today

#### Acceptance Criteria:
- **Scenario:** Browsing the journal
- **Given:** entries exist across several days
- **When:** I open the Journal from the Mind tab
- **Then:** entries are grouped date → context (Opportunities, Did-Its, Gratitudes) → affirmation, every level collapsible, voice entries play inline with their duration, text entries show their text and time, and deleting asks for confirmation and is permanent

---

### User Story 070:

- **Summary:** Tag an entry to the roles it was about, as I write it
- **Status:** implemented in [4afbfd5](https://github.com/idvorkin/context-grabber/commit/4afbfd5), [37f96e4](https://github.com/idvorkin/context-grabber/commit/37f96e4); verified by `roleMoments.test.ts` and on the phone

#### Use Case:
- **As a** father writing a gratitude about Amelia
- **I want to** toggle *Amelia* and *Family* on the chip strip before saving
- **so that** the entry is evidence for both roles and follows me to my other devices

#### Acceptance Criteria:
- **Scenario:** A gratitude tagged to two roles
- **Given:** the Grateful card is open with the eleven role chips under the field
- **When:** I select Amelia and Family and save
- **Then:** one moment is recorded per selected role, both roles' recent moments show it, and an untagged entry would instead have been credited to *Emo* automatically

---

### User Story 071:

- **Summary:** From a role, read what I actually wrote and write more as that role
- **Status:** implemented in [be2359f](https://github.com/idvorkin/context-grabber/commit/be2359f); verified on the phone

#### Use Case:
- **As a** man opening the Amelia role before a family weekend
- **I want to** see the real text or voice of every entry tied to it, and start a new affirmation or gratitude already tagged to Amelia
- **so that** a role shows what I said, not just which affirmation I said it under

#### Acceptance Criteria:
- **Scenario:** The role as a lens on the journal
- **Given:** an affirmation note "Notice when I'm rushing Amelia" was saved tagged to Amelia
- **When:** I open the Amelia role detail
- **Then:** the recent moment shows the note text (not just "Do It Anyways"), a voice entry there has a play button with its duration, an auto-workout moment stays one compact line, and the two buttons *Log an affirmation as Amelia* / *Write a gratitude as Amelia* open the cards with Amelia pre-selected

---

### User Story 072:

- **Summary:** Narrow the Journal to one role
- **Status:** implemented in [be2359f](https://github.com/idvorkin/context-grabber/commit/be2359f); verified by `journal.test.ts` and on the phone

#### Use Case:
- **As a** husband wondering what the last month with Tori looked like
- **I want to** filter the Journal to *Tori*
- **so that** every entry tied to her, across all dates, is in one list

#### Acceptance Criteria:
- **Scenario:** Filter by role
- **Given:** a gratitude tagged to both Tori and Family, and another entry with no tag
- **When:** I tap the Tori chip at the top of the Journal
- **Then:** the tagged gratitude shows (and would under Family too), the untagged entry does not, the date → context → affirmation grouping is kept, and clearing the chip returns the full Journal with each entry once

---

### User Story 073:

- **Summary:** Fix an entry's role tags after the fact, and see the journal by role
- **Status:** implemented in [c3664c8](https://github.com/idvorkin/context-grabber/commit/c3664c8); verified by `journal.test.ts` and on the phone
- **Issues:** [#47](https://github.com/idvorkin/context-grabber/issues/47) — the tagging and the group toggle shipped; smaller tags and better role icons are still open there

#### Use Case:
- **As a** man who forgot to tag yesterday's gratitude to Tori
- **I want to** tap the entry's role avatars in the Journal, toggle Tori on, and switch the Journal to group by role
- **so that** evidence stays correctable and I can see "most of this week was about Amelia" without a new entry type

#### Acceptance Criteria:
- **Scenario:** Retag and regroup
- **Given:** an entry in the Journal shows only the automatic *Emo* avatar
- **When:** I tap its avatars, select Tori, tap Done, and switch the toggle to *By role*
- **Then:** the row shows Emo and Tori, the entry appears under both roles for its day (untagged entries collect under *Untagged*), the tag survives a restart, and *By affirmation* restores the original view

---

### User Story 074:

- **Summary:** Dictate into a card without the card vanishing
- **Status:** implemented in [ca8a230](https://github.com/idvorkin/context-grabber/commit/ca8a230); verified on the phone (a recurrence is tracked in beads as `context-grabber-t1q`, in progress)

#### Use Case:
- **As a** man who writes with the Wispr Flow keyboard
- **I want to** dictate into the Grateful or Affirmation card while its tall "Listening" overlay is up
- **so that** the card stays visible and the words land intact

#### Acceptance Criteria:
- **Scenario:** Dictation over the card
- **Given:** the Wispr Flow keyboard is active and the Grateful card is open
- **When:** I start a dictation and speak a sentence
- **Then:** the card never goes black or collapses while the overlay is up, and the dictated text arrives in the field unscrambled

---

### User Story 075:

- **Summary:** Say how I feel in two taps and have it remembered for the day
- **Status:** implemented in [54861c5](https://github.com/idvorkin/context-grabber/commit/54861c5); verified by `moodLog.test.ts` and on the phone

#### Use Case:
- **As a** man noticing his energy at the end of the day
- **I want to** tap a mood 1–5 and an energy 1–5 on the Mind tab
- **so that** the coach gets the self-report HealthKit cannot give, with no form to fill

#### Acceptance Criteria:
- **Scenario:** Mood and energy for today
- **Given:** the Mind tab is open with the mood and energy rows of five buttons
- **When:** I tap mood 4 and energy 2
- **Then:** the pair saves on the second tap with no Save button, reopening the tab later today shows 4 and 2 still selected, and a new day starts blank

---

### User Story 076:

- **Summary:** See the last day's entries where I log them
- **Status:** implemented in [c48d01b](https://github.com/idvorkin/context-grabber/commit/c48d01b); verified by `JournalRecentList.test.tsx` and on the phone

#### Use Case:
- **As a** man about to log a gratitude who wonders what he already said today
- **I want to** see the last 24 hours of entries on the Mind tab itself
- **so that** I do not open the full Journal for a glance

#### Acceptance Criteria:
- **Scenario:** Recent entries on Mind
- **Given:** two entries were logged this morning and one three days ago
- **When:** I open the Mind tab
- **Then:** a *Recent* list shows the two from today with their role avatars, playable voice and delete, the old one is absent, and a new entry appears in the list as soon as its card closes

---

### User Story 077:

- **Summary:** Larry reads roles and reflections, not just heart rates
- **Status:** implemented in [54861c5](https://github.com/idvorkin/context-grabber/commit/54861c5) (roles section), [b328209](https://github.com/idvorkin/context-grabber/commit/b328209) (journal export); verified by `share.test.ts`, `journal.test.ts` and in Larry calls

#### Use Case:
- **As a** coaching client pasting context into a call
- **I want to** have the export lead with this week's roles — strong and quiet, attention reasons, intentions — and carry today's opportunities, did-its and gratitudes
- **so that** Larry can say "you noticed five Essentialist opportunities and followed through twice" instead of reading step counts

#### Acceptance Criteria:
- **Scenario:** The export after a tagged week
- **Given:** moments and journal entries exist for the week
- **When:** I press Grab Context and share the summary
- **Then:** the JSON carries a roles block with each role's score and strong/quiet label, the attention reasons, and any intentions, plus a journal block with each of today's entries' context, affirmation title, timestamp and text (or "voice note, 0:42")

---

### User Story 078:

- **Summary:** Set a one-line intention for a role this week and see it on Today
- **Status:** not implemented; no issue filed — the export already carries intentions and the store exists, but nothing in the app lets me write one (the composer is deferred in the Roles tab spec)

#### Use Case:
- **As a** man closing a Sunday review
- **I want to** write "one date night" against *Husband to Tori* in the role's sheet
- **so that** the week has a compass, not just a mirror, and Larry sees it in the export

#### Acceptance Criteria:
- **Scenario:** An intention for the week
- **Given:** the Tori role detail is open
- **When:** I type "one date night" into *Set an intention* and save
- **Then:** the Today tab shows it all week and the next Grab Context lists it under intentions

---

### User Story 079:

- **Summary:** See the year, not just the week
- **Status:** not implemented; no issue filed — the constellation, the 11×52 heatmap and the horizon switcher remain the aspirational section of the Roles tab spec

#### Use Case:
- **As a** man asking "in 2026, who was I mostly?"
- **I want to** switch the Roles tab to *This year* and read a heatmap of eleven roles by fifty-two weeks
- **so that** the medium arc between the weekly review and the eulogy is visible

#### Acceptance Criteria:
- **Scenario:** The year view
- **Given:** months of moments and grabs
- **When:** I switch the horizon to *This year*
- **Then:** each role is a row of fifty-two cells shaded by that week's score, with the brightest, dimmest and most variable roles named above it
