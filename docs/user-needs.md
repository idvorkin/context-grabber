# Context Grabber — User Needs & Stories

## Philosophy: Humane Tracking

Context Grabber implements the "Capture Implicitly" pillar from [Humane Structure](https://idvork.in/structure). The core idea: let technology handle data collection silently, so the human focuses on context and insights. No streaks, no judgments, no red X's — just observation.

> "Apple Watch shows I walked 8,000 steps, but what it doesn't show is that I felt anxious and walking helped me think through the work problem."

The app serves two consumers with different needs: an AI life coach (Larry) who needs structured data, and the user (Igor) who needs a quick glance.

---

## Two Value Props

### 1. AI Life Coach Context ("Feed Larry")

**User:** Larry (AI life coach, runs in Claude/ChatGPT)
**Trigger:** Start of coaching session, or when Igor pastes context
**Need:** Structured JSON with this week's health + location data

**What Larry actually uses (ranked by coaching value):**

| Data | What Larry Does With It |
|------|------------------------|
| Exercise minutes + HR max | Confirms gym days and workout intensity |
| Steps | Activity level, rest day detection |
| Weight trend | Tracking toward 180 lb goal |
| Meditation minutes | Early warning signal #1 — "flatline detection" when it drops to zero |
| Location clusters + timeline | Where Igor spent time, gym visits confirmed, "home by 6pm" goal check |
| Sleep hours | Flagging short nights (with caveat about HealthKit over-reporting) |

**What Larry wishes he had (gaps):**

| Missing Data | Why It Matters |
|-------------|----------------|
| HRV + resting heart rate | Recovery/stress signal (currently always null) |
| Actual sleep vs time-in-bed | HealthKit reports 12-14h which is clearly wrong; need real sleep quality |
| Eight Sleep data | Igor has Eight Sleep; would give real sleep stages |
| Mood/energy self-report | Even a 1-5 daily score would correlate with activity patterns |
| Food/calories | Igor tracks diet elsewhere but it's not in the export |
| Screen time / phone pickups | Distraction pattern tracking |

**Ideal cadence:** Automatic daily export or sessionStart hook. Currently manual 1-2x per session.

**History window:** 7-day default is right (matches weekly coaching cadence). Also wants week-over-week comparison and 30-day trends for weight/meditation/exercise frequency.

### 2. Quick Personal Dashboard ("Igor's Glance")

**User:** Igor (engineer, quantified self enthusiast)
**Trigger:** Curiosity, end of day, noticing energy level
**Need:** At-a-glance today + this week, tap for details

**What matters for the glance:**
- Did I exercise today? How intense?
- How much sleep did I actually get?
- Am I on track for the week (steps, meditation, weight)?
- Where have I been? (confirms daily routine adherence)

---

## User Stories

> Superseded 2026-09-12 by [docs/stories/](stories/README.md) — Cohn + Gherkin stories per journey, each with its
> status and commits. The CC-* and DB-* stories below are kept as the original framing of the two consumers; the
> stories directory is the spec.


### Coach Context Stories

**CC-1: Session Context Grab**
> As Larry, I need this week's health and location data in structured JSON so I can reference specific metrics during coaching.

Acceptance: One tap → JSON in clipboard with 7 daily entries + weekly stats + location summary.

**CC-2: Gym Day Confirmation**
> As Larry, I need to see exercise minutes with heart rate data so I can confirm gym attendance and workout intensity.

Acceptance: Exercise entries show duration, and heart rate shows elevated max on gym days.

**CC-3: Meditation Flatline Detection**
> As Larry, I need to see meditation minutes per day so I can notice when Igor's practice drops to zero (early warning of stress/avoidance).

Acceptance: 7-day meditation data with daily granularity, zeros visible.

**CC-4: Weight Trajectory**
> As Larry, I need weight trend over 7-30 days so I can track progress toward the 180 lb goal.

Acceptance: Weekly stats with min/max/median. Days with readings counted.

**CC-5: Location-Based Goal Check**
> As Larry, I need the location timeline so I can check "home by 6pm" goal and see where time was spent.

Acceptance: Location summary shows place names with arrival/departure times.

**CC-6: Week-Over-Week Comparison**
> As Larry, I need this week vs last week for key metrics so I can spot trends and regressions.

Acceptance: Weekly stats export includes current + previous week.

**CC-7: Sleep Quality (Not Just Duration)**
> As Larry, I need actual sleep time (not time-in-bed) so I can give accurate sleep feedback.

Acceptance: Sleep hours reflect merged actual-sleep stages, not InBed. Per-source breakdown available.

### Dashboard Stories

**DB-1: Today at a Glance**
> As Igor, I want to see today's key metrics in 2 seconds so I know where I stand.

Acceptance: Main screen shows steps, exercise, sleep, heart rate, weight, meditation with current values.

**DB-2: Weekly Trend Drill-Down**
> As Igor, I want to tap any metric and see the 7-day chart so I can spot patterns.

Acceptance: Tapping a card opens detail sheet with chart + daily breakdown.

**DB-3: Location Where-Was-I**
> As Igor, I want to tap Location and see a timeline of where I've been so I can confirm my routine.

Acceptance: Location card opens sheet with recent timeline + weekly place rollup.

**DB-4: Database Export for Analysis**
> As Igor, I want to export the raw SQLite database so I can run custom queries or share with other tools.

Acceptance: "Export Database" button shares the .db file via iOS share sheet.

**DB-5: Known Places Management**
> As Igor, I want to name places (Home, Office, Gym) so the location timeline uses meaningful labels.

Acceptance: Add/delete/import known places with name, coordinates, radius.

---

## Data Layer Requirements

### Must Have (Current)
- [x] Steps (daily sum)
- [x] Heart rate (latest + daily min/max/avg/q1/median/q3)
- [x] Sleep hours (interval-merged, noon-to-noon window)
- [x] Sleep per-source breakdown (Watch vs iPhone vs Eight Sleep)
- [x] Active energy (kcal)
- [x] Walking distance (km)
- [x] Weight (latest, in kg)
- [x] Meditation minutes (daily sum)
- [x] HRV (latest)
- [x] Resting heart rate (latest)
- [x] Exercise minutes (daily sum from individual samples)
- [x] GPS current location
- [x] Background location trail (SQLite, 30-day retention)
- [x] Location clustering with known places
- [x] 7-day weekly aggregation with caching
- [x] Box plot statistics per metric

### Should Have (Gaps Identified by Larry)
- [ ] HRV trend (7-day, not just latest) — currently null too often
- [ ] Actual sleep vs time-in-bed distinction — HealthKit over-reports
- [ ] Week-over-week comparison in export (this week vs last week)
- [ ] 30-day weight/meditation/exercise trends

### Nice to Have (Future)
- [ ] Eight Sleep integration (sleep quality, temperature, HRV)
- [ ] Mood/energy self-report (1-5 daily score)
- [ ] Screen time / phone pickup count
- [ ] Food/calorie data integration
- [ ] Automatic daily export (background grab + push to cloud/coach)
- [ ] sessionStart hook for automatic context delivery

---

## UX Layer Requirements

### Main Screen
- 10 metric cards in 2-column grid (current)
- Location card (full width, tappable)
- Summary banner (one-liner)
- Share buttons (Summary JSON, Raw JSON)

### Metric Detail Sheet
- 7-day chart (bar or line/whisker)
- Daily breakdown with values
- Box plot stats
- Sleep: per-source tabs with stage breakdown

### Location Detail Sheet
- Current coordinates
- Clustering summary (recent 3-day timeline + weekly rollup)
- Export Database button
- Known Places CRUD

### Settings
- Background tracking toggle
- Retention days
- Debug tools

### Design Principles (from Humane Structure)
1. **Observe, don't judge** — show "5.2h sleep" not "BAD SLEEP"
2. **Capture implicitly** — HealthKit + GPS do the work, not the user
3. **Design for comeback** — app works after weeks of not opening it
4. **Partial wins count** — 5 min meditation is shown, not hidden
5. **Patterns over streaks** — "3 of 7 days" not "streak broken"
6. **Time-since over compliance** — "last meditated 4 days ago" over "missed 4 days"

---

## Export Contract (API for AI Consumers)

The JSON export is a contract. AI consumers (Larry) depend on this shape.

```json
{
  "days": [
    {
      "date": "2026-03-28",
      "dayOfWeek": "Saturday",
      "steps": 8432,
      "heartRate": { "avg": 72, "min": 55, "max": 120 },
      "sleepHours": 7.5,
      "activeEnergy": 350,
      "walkingDistanceKm": 5.2,
      "weightKg": 82.1,
      "meditationMinutes": 15,
      "hrvMs": 45,
      "restingHeartRate": 62,
      "exerciseMinutes": 30
    }
  ],
  "weeklyStats": {
    "steps": { "min": 5000, "p25": 6500, "p50": 8000, "p75": 9500, "max": 12000 }
  },
  "locationSummary": {
    "summary": "Home Mon 10pm–Tue 8am (10h), Office Tue 9am–5pm (8h)"
  }
}
```

Field names, units, and structure must remain stable across the Swift port.
