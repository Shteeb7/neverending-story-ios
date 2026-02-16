# QIS Phase 1 + Checkpoint UX Fix

Two tasks in one prompt. Read fully before starting.

---

## TASK A: Checkpoint UX — Prevent Re-Interviews + Smart Post-Interview Routing

### Problem 1: Re-interview on view recreation

`BookReaderView.swift` uses `@State private var checkedCheckpoints: Set<String> = []` to prevent re-checking checkpoints within a session. But SwiftUI can destroy and recreate views at any time, resetting this `@State`. When the view rebuilds, the app re-checks the server — and if the network call fails or is slow, users could see the interview again.

### Fix 1: Persist completed checkpoints in UserDefaults

After successfully submitting checkpoint feedback in `handleProsperoCheckInComplete()` (line 543-558 in `BookReaderView.swift`), save the completed checkpoint locally:

```swift
private func handleProsperoCheckInComplete(pacing: String, tone: String, character: String) {
    Task {
        do {
            let _ = try await APIManager.shared.submitCheckpointFeedbackWithDimensions(
                storyId: story.id,
                checkpoint: currentCheckpoint,
                pacing: pacing,
                tone: tone,
                character: character,
                protagonistName: protagonistName
            )
            NSLog("✅ Submitted dimension feedback: pacing=\(pacing), tone=\(tone), character=\(character)")

            // Persist that this checkpoint is complete so it never re-triggers
            markCheckpointComplete(storyId: story.id, checkpoint: currentCheckpoint)

            // Smart routing: go to library if no next chapter available
            await MainActor.run {
                if !readingState.canGoToNextChapter {
                    // No next chapter yet — return to library where they'll see generation status
                    dismiss()
                }
                // If next chapter exists, stay in reader (default behavior)
            }
        } catch {
            NSLog("❌ Failed to submit dimension feedback: \(error)")
        }
    }
}
```

Add these two helper functions to `BookReaderView`:

```swift
private func markCheckpointComplete(storyId: String, checkpoint: String) {
    let key = "completedCheckpoints_\(storyId)"
    var completed = UserDefaults.standard.stringArray(forKey: key) ?? []
    if !completed.contains(checkpoint) {
        completed.append(checkpoint)
        UserDefaults.standard.set(completed, forKey: key)
    }
}

private func isCheckpointComplete(storyId: String, checkpoint: String) -> Bool {
    let key = "completedCheckpoints_\(storyId)"
    let completed = UserDefaults.standard.stringArray(forKey: key) ?? []
    return completed.contains(checkpoint)
}
```

### Fix 2: Check UserDefaults BEFORE calling the server

In `checkForFeedbackCheckpoint()` (line 484), add a UserDefaults check right after the `checkedCheckpoints` guard (line 515):

```swift
// Don't show if already checked this session
guard !checkedCheckpoints.contains(checkpoint) else { return }
checkedCheckpoints.insert(checkpoint)

// Don't show if already completed (persisted across sessions)
guard !isCheckpointComplete(storyId: story.id, checkpoint: checkpoint) else { return }

// Check if feedback already submitted (server check as backup)
Task { ... }
```

Same pattern in `handleNextChapterTap()` (line 446) — add the UserDefaults check before the server call:

```swift
if let checkpoint = checkpointMap[currentNum] {
    // Skip if already completed locally
    if isCheckpointComplete(storyId: story.id, checkpoint: checkpoint) {
        // Feedback already done — show generating view
        await MainActor.run {
            generatingChapterNumber = currentNum + 1
            showGeneratingChapters = true
        }
        return
    }

    // Otherwise check server...
    Task { ... existing code ... }
}
```

### Problem 2: Post-interview dumps user back to reading with nothing to read

After completing a checkpoint interview, the user is returned to the same chapter. If the next batch hasn't generated yet, they scroll down, hit the end, and see a generating spinner. Unnecessary friction.

### Fix 2: Smart post-interview routing

Already handled above in the `handleProsperoCheckInComplete` changes: if `!readingState.canGoToNextChapter`, dismiss the reader view and return to library. The library already shows generation status for in-progress stories.

If the next chapter IS available (e.g., legacy stories with pre-generated chapters), stay in the reader. Best of both worlds.

### Files to modify for Task A

| File | Change |
|------|--------|
| `NeverendingStory/NeverendingStory/Views/Reader/BookReaderView.swift` | Add `markCheckpointComplete()`, `isCheckpointComplete()`, modify `handleProsperoCheckInComplete()`, `checkForFeedbackCheckpoint()`, `handleNextChapterTap()` |

---

## TASK B: Quality Intelligence System Phase 1

Read `QUALITY_INTELLIGENCE_SYSTEM.md` for the full 4-phase master plan. This implements Phase 1 only.

### Part 1: Database Migration — `quality_snapshots` Table + `generation_config` Column

#### 1A: Add `generation_config` to `stories` table

```sql
ALTER TABLE stories ADD COLUMN generation_config JSONB DEFAULT '{
  "character_ledger": true,
  "voice_review": true,
  "adaptive_preferences": true,
  "course_corrections": true
}'::jsonb;
```

This column controls which generation systems are active for each story. Default is all systems ON (existing behavior). Future experiments will create stories with specific systems disabled.

#### 1B: Create `quality_snapshots` table

```sql
CREATE TABLE quality_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_date DATE NOT NULL,
  story_id UUID REFERENCES stories(id) ON DELETE CASCADE,

  -- AI quality signals (averaged across all chapters in the story)
  ai_quality_avg NUMERIC,
  voice_authenticity_avg NUMERIC,
  revision_rate NUMERIC,
  callback_utilization NUMERIC,

  -- Reader signals
  reader_pacing_satisfaction TEXT,
  reader_tone_satisfaction TEXT,
  reader_character_satisfaction TEXT,
  completion_rate NUMERIC,
  avg_reading_time_per_chapter INTEGER,
  abandonment_chapter NUMERIC,

  -- Generation config snapshot (what systems were active)
  generation_config JSONB,

  -- Cost
  total_generation_cost NUMERIC,
  cost_per_chapter NUMERIC,

  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_quality_snapshots_story ON quality_snapshots(story_id);
CREATE INDEX idx_quality_snapshots_date ON quality_snapshots(snapshot_date);

ALTER TABLE quality_snapshots ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admin access to quality snapshots" ON quality_snapshots
  FOR ALL USING (true);
```

Apply both migrations via Supabase MCP `apply_migration`.

### Part 2: Quality Dashboard Service

Create a new file: `neverending-story-api/src/services/quality-intelligence.js`

This service computes quality metrics from existing data across multiple tables. It does NOT make any AI calls — it's pure database aggregation.

#### Function 1: `computeStoryQualitySnapshot(storyId)`

Computes a quality snapshot for a single story by aggregating data from these tables:

**From `chapters` table (where story_id = storyId):**
- `ai_quality_avg`: Average of `quality_score` across all chapters
- Per-dimension averages: Extract from `quality_review` JSONB → `criteria_scores` → average each dimension (show_dont_tell, dialogue_quality, pacing_engagement, age_appropriateness, character_consistency, prose_quality) across all chapters
- `regeneration_count`: Average regeneration count (higher = more quality issues during generation)

**From `character_voice_reviews` table (where story_id = storyId):**
- `voice_authenticity_avg`: Extract each character's `authenticity_score` from `review_data` JSONB → `voice_checks` array → average all scores across all chapters
- `revision_rate`: Count where `revision_applied = true` / total rows

**From `character_ledger_entries` table (where story_id = storyId):**
- `callback_utilization`: For each entry's `callback_bank` JSONB array, count items with `status = 'used'` vs total items. Compute overall utilization rate across all chapters.

**From `story_feedback` table (where story_id = storyId):**
- `reader_pacing_satisfaction`: Aggregate `pacing_feedback` values (return a distribution object like `{"hooked": 2, "slow": 1}`)
- `reader_tone_satisfaction`: Same aggregation for `tone_feedback`
- `reader_character_satisfaction`: Same aggregation for `character_feedback`
- Count of feedback entries where `follow_up_action` is not null

**From `chapter_reading_stats` table (where story_id = storyId):**
- `completion_rate`: Count where `completed = true` / total rows
- `avg_reading_time_per_chapter`: Average of `total_reading_time_seconds`

**From `reading_sessions` table (where story_id = storyId):**
- `abandonment_chapter`: Find chapters where `abandoned = true`. If any exist, return the lowest chapter_number. If none, return null.

**From `api_costs` table (where story_id = storyId):**
- `total_generation_cost`: Sum of `cost`
- `cost_per_chapter`: `total_generation_cost` / number of chapters
- Cost breakdown by operation: Group by `operation` and sum costs

**From `stories` table:**
- `generation_config`: The story's feature flag configuration

Return all of the above as a structured object. Also INSERT a row into `quality_snapshots` with the computed data and today's date.

#### Function 2: `computeDashboard(options = {})`

Accepts optional filters:
- `options.storyIds` — array of specific story IDs
- `options.since` — date string, only include stories created after this date
- `options.limit` — max stories to include (default 20, most recent first)

Steps:
1. Fetch qualifying stories from `stories` table (where status is not 'error' and at least 1 chapter exists)
2. For each story, call `computeStoryQualitySnapshot(storyId)`
3. Aggregate across all stories for fleet-level metrics:

**Fleet-level aggregations:**
- `fleet_quality_avg`: Average ai_quality_avg across all stories
- `fleet_voice_avg`: Average voice_authenticity_avg
- `fleet_revision_rate`: Average revision rate
- `fleet_callback_utilization`: Average callback utilization
- `fleet_completion_rate`: Average reader completion rate
- `fleet_cost_per_chapter`: Average cost per chapter
- `total_stories_analyzed`: Count
- `total_chapters_analyzed`: Count

**Per-dimension breakdown:**
- Average score for each quality dimension across all stories
- Identify the weakest dimension (lowest average) — this becomes the improvement target

**Per-system cost breakdown:**
- Average cost per system per chapter

**Feature flag distribution:**
- How many stories have each system enabled vs disabled

Return everything in clean JSON.

#### Function 3: `getStoryQualityDetail(storyId)`

Deep-dive into a single story's quality. Returns:
- The full snapshot data from `computeStoryQualitySnapshot`
- Per-chapter quality scores (array of {chapter_number, quality_score, voice_authenticity, had_revision, has_ledger_entry})
- Quality trend: Are scores improving, declining, or stable across chapters? (compare first half vs second half averages)

Export all three functions.

### Part 3: Feature Flag Integration in `generation.js`

Wire the `generation_config` column into `generateChapter()` so each system can be toggled per-story.

**IMPORTANT:** The story object is fetched at line 1909-1913 via `select('*')`, so `story.generation_config` will be available after the column is added. Define `const config = story.generation_config || {};` once, early in the function (around line 1978), and reuse it for all checks below.

#### 3A: Learned Preferences Block (line ~1979)

Wrap the existing `getUserWritingPreferences` call:
```javascript
const config = story.generation_config || {};
let learnedPreferencesBlock = '';
if (config.adaptive_preferences !== false) {
  const writingPrefs = await getUserWritingPreferences(userId);
  if (writingPrefs && writingPrefs.stories_analyzed >= 2 && writingPrefs.confidence_score >= 0.5) {
    // ... existing block-building logic unchanged
  }
} else {
  console.log(`⚙️ [${storyTitle}] Adaptive preferences DISABLED by generation_config`);
}
```

#### 3B: Course Corrections Block (line ~2001)

```javascript
let courseCorrectionsBlock = '';
if (courseCorrections && config.course_corrections !== false) {
  courseCorrectionsBlock = `...`; // existing logic
} else if (courseCorrections && config.course_corrections === false) {
  console.log(`⚙️ [${storyTitle}] Course corrections DISABLED by generation_config (feedback ignored)`);
}
```

#### 3C: Character Continuity Block (line ~2011)

```javascript
const characterContinuityBlock = config.character_ledger !== false
  ? await buildCharacterContinuityBlock(storyId, chapterNumber)
  : '';

if (config.character_ledger === false) {
  console.log(`⚙️ [${storyTitle}] Character ledger DISABLED by generation_config`);
}
```

#### 3D: Post-Generation Systems (lines ~2425-2449)

Wrap character ledger extraction:
```javascript
if (config.character_ledger !== false) {
  // existing extractCharacterLedger call
} else {
  console.log(`⚙️ [${storyTitle}] Skipping ledger extraction (character_ledger disabled)`);
}
```

Wrap voice review:
```javascript
if (config.voice_review !== false) {
  // existing reviewCharacterVoices + applyVoiceRevisions calls
} else {
  console.log(`⚙️ [${storyTitle}] Skipping voice review (voice_review disabled)`);
}
```

**CRITICAL:** Make sure `config` is NOT redefined or shadowed anywhere between its definition and use in the post-generation section.

### Part 4: Admin Endpoints

Add to `neverending-story-api/src/routes/admin.js`, after the existing endpoints:

#### `GET /admin/quality/dashboard`
Query params: `since` (optional ISO date), `limit` (optional, default 20)
Calls `computeDashboard({ since, limit })` and returns the result.

#### `GET /admin/quality/story/:storyId`
Calls `getStoryQualityDetail(storyId)` and returns the result.

#### `POST /admin/quality/snapshot`
Body: `{ storyId }` (required)
Calls `computeStoryQualitySnapshot(storyId)` to force-compute and store a snapshot.

All three endpoints: `authenticateUser` middleware, `asyncHandler` wrapper, check `req.user.role === 'admin'` (403 if not).

### Part 5: Logging

- `⚙️` for feature flag messages
- `📊` for quality intelligence events:
  - `📊 [Title] Quality snapshot computed: quality=X.X, voice=X.XX, completion=XX%`
  - `📊 Fleet dashboard: X stories analyzed, avg quality=X.X, weakest dimension=XXX`

### Part 6: Quality Intelligence Dashboard Section in `mythweaver-dashboard.html`

**Do NOT create a separate admin UI.** Add a new "Quality Intelligence" section to the existing Mythweaver Command Center dashboard at the workspace root: `mythweaver-dashboard.html`.

#### Dashboard architecture

The dashboard is a single HTML file with:
- CSS variables for theming: `--bg-card`, `--border`, `--accent-purple`, `--accent-amber`, `--accent-green`, `--accent-blue`, `--accent-cyan`, `--text-primary`, `--text-secondary`, `--text-dim`
- A `Dashboard` class with render methods (`renderKPIs()`, `renderJourney()`, `renderErrorFeed()`, `renderTables()`, etc.)
- Chart.js for visualizations (already imported via CDN)
- Card patterns: `.chart-card` for chart sections, `.table-card` for data tables, `.kpi-card` for KPI tiles
- Layout: `.chart-grid` (2-col), `.three-col` (3-col), or `grid-template-columns:1fr` (full-width)
- All data is currently hardcoded in JS arrays at the top of the `<script>` section (e.g. `DAILY`, `USERS`, `STORIES`, `COST_OPS`, etc.)

#### What to add

**1. New HTML section** — Insert a new section BETWEEN the existing "Quality Score Trend" chart section and the "Reader Journey" section (between lines ~404 and ~406). This is where quality data naturally belongs — after the overview charts, before the per-user deep dives.

Add:

```html
<!-- Quality Intelligence -->
<section class="chart-grid" style="grid-template-columns:1fr">
    <div class="chart-card" style="border-left:3px solid var(--accent-purple)">
        <h3>🧠 Quality Intelligence — Generation System Performance</h3>
        <div id="qi-summary" style="margin-bottom:16px"></div>
    </div>
</section>
<section class="kpi-row" id="qi-kpis" style="grid-template-columns:repeat(5,1fr)"></section>
<section class="chart-grid">
    <div class="chart-card"><h3>Quality by Dimension</h3><div class="chart-wrap"><canvas id="chart-qi-dimensions"></canvas></div></div>
    <div class="chart-card"><h3>System Cost per Chapter</h3><div class="chart-wrap"><canvas id="chart-qi-system-cost"></canvas></div></div>
</section>
<section class="chart-grid" style="grid-template-columns:1fr">
    <div class="table-card"><h3>Per-Story Quality Breakdown</h3><div id="qi-story-table"></div></div>
</section>
```

**2. Hardcoded `QI_DATA` array** — Add a new data constant alongside the existing ones (near `QUALITY`, `STORIES`, etc.). This will be replaced with live API data later:

```javascript
const QI_DATA = {
    fleet: {
        quality_avg: 8.15,
        voice_avg: 8.42,
        revision_rate: 0.23,
        callback_utilization: 0.31,
        completion_rate: 0.45,
        cost_per_chapter: 0.43,
        stories_analyzed: 14,
        chapters_analyzed: 92,
        weakest_dimension: 'pacing_engagement'
    },
    dimensions: {
        show_dont_tell: 8.3,
        dialogue_quality: 8.5,
        pacing_engagement: 7.6,
        age_appropriateness: 8.8,
        character_consistency: 8.1,
        prose_quality: 8.2
    },
    system_costs: {
        generate_chapter: 0.18,
        quality_review: 0.08,
        character_ledger: 0.03,
        voice_review: 0.06,
        voice_revision: 0.02
    },
    feature_flags: {
        character_ledger: { enabled: 14, disabled: 0 },
        voice_review: { enabled: 14, disabled: 0 },
        adaptive_preferences: { enabled: 14, disabled: 0 },
        course_corrections: { enabled: 14, disabled: 0 }
    },
    stories: [] // Will be populated from computeDashboard - for now, reuse STORIES array
};
```

**3. New render method** — Add `renderQualityIntelligence()` to the Dashboard class, following the same patterns as existing methods. Call it from `init()`.

The method should render:

**KPI row (5 tiles, same `.kpi-card` pattern):**
- Avg Quality (purple) — `QI_DATA.fleet.quality_avg` with "/10"
- Voice Auth (blue) — `QI_DATA.fleet.voice_avg` with "/10"
- Revision Rate (amber) — `QI_DATA.fleet.revision_rate` as percentage
- Callback Use (cyan) — `QI_DATA.fleet.callback_utilization` as percentage
- Cost/Chapter (green) — `QI_DATA.fleet.cost_per_chapter` as "$X.XX"

**Summary text** in `#qi-summary` (same style as `.synopsis-body`):
- "Analyzed X stories (Y chapters). Weakest dimension: **Z**. All 4 generation systems active."
- Use the accent color spans like the synopsis does

**Dimension chart** — Horizontal bar chart (same pattern as `chart-quality-dist`) showing the 6 quality dimensions. Color the weakest bar amber, rest blue/green.

**System cost chart** — Horizontal bar or doughnut chart showing per-system cost breakdown. Same Chart.js patterns as existing charts.

**Per-story quality table** — Same `.data-table` pattern as existing story table. Columns: Title, Quality, Voice, Revision, Callback, Cost/Ch, Completion. Reuse the STORIES array data for now, augmented with QI_DATA fields where available.

**4. CSS** — You should NOT need new CSS classes. Reuse existing `.kpi-card`, `.chart-card`, `.table-card`, `.data-table`, `.synopsis-body` patterns. If you absolutely need a new style, use inline styles or add minimal additions that match the dark theme.

#### Future: Wiring to live API data

Leave a `// TODO: Replace QI_DATA with fetch('/admin/quality/dashboard')` comment. The dashboard will eventually call the API endpoints from Part 4 to populate QI_DATA with real data. For now, hardcoded placeholder data is fine — it proves the UI works and establishes the layout.

---

## What NOT to Do

1. Do NOT make any AI API calls — QIS Phase 1 is pure database aggregation
2. Do NOT change default generation behavior — all feature flags default to ON
3. Do NOT modify the quality review loop (lines ~2195-2385 in generation.js)
4. Do NOT create scheduled jobs — the dashboard is on-demand only
5. Do NOT modify tables other than `stories` (adding generation_config) and creating `quality_snapshots`
6. Do NOT use `.single()` for queries that might return no rows — use `.maybeSingle()` or handle empty results
7. Do NOT assume `quality_review` JSONB exists on every chapter — guard with null checks
8. For Task A: Do NOT change the ProsperoCheckInView itself — only modify BookReaderView's handling of completion and triggering

---

## Files Summary

| File | Action |
|------|--------|
| Database | Migration: `generation_config` on stories + `quality_snapshots` table |
| `NeverendingStory/Views/Reader/BookReaderView.swift` | Add UserDefaults checkpoint persistence + smart post-interview routing |
| `neverending-story-api/src/services/quality-intelligence.js` | CREATE — three functions |
| `neverending-story-api/src/services/generation.js` | MODIFY — feature flag checks on 4 systems |
| `neverending-story-api/src/routes/admin.js` | MODIFY — 3 new quality endpoints |
| `mythweaver-dashboard.html` (workspace root) | MODIFY — add Quality Intelligence section with KPIs, charts, table |

---

## Verification

1. iOS: Build succeeds. Completing a checkpoint interview when no next chapter exists dismisses back to library.
2. Server: `npm test` passes. `GET /admin/quality/dashboard` returns data. Feature flags don't change default behavior.
3. Database: `generation_config` exists on stories. `quality_snapshots` table exists.
4. Dashboard: Open `mythweaver-dashboard.html` in browser. New Quality Intelligence section appears with KPI tiles, dimension chart, system cost chart, and per-story table. Styling matches existing dark theme.
