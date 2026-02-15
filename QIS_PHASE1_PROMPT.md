# Quality Intelligence System — Phase 1: Quality Dashboard & Feature Flags

## Context

We've built four generation systems (quality review, adaptive reading engine, character relationship ledger, voice review) but have no unified way to measure whether they actually improve quality. This phase creates the measurement foundation: a dashboard that aggregates all existing quality signals, and feature flags that let us selectively enable/disable systems for future A/B testing.

**Reference:** Read `QUALITY_INTELLIGENCE_SYSTEM.md` for the full 4-phase master plan. This prompt implements Phase 1 only.

---

## Part 1: Database Migration — `quality_snapshots` Table + `generation_config` Column

### 1A: Add `generation_config` to `stories` table

```sql
ALTER TABLE stories ADD COLUMN generation_config JSONB DEFAULT '{
  "character_ledger": true,
  "voice_review": true,
  "adaptive_preferences": true,
  "course_corrections": true
}'::jsonb;
```

This column controls which generation systems are active for each story. Default is all systems ON (existing behavior). Future experiments will create stories with specific systems disabled.

### 1B: Create `quality_snapshots` table

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

-- Index for efficient querying
CREATE INDEX idx_quality_snapshots_story ON quality_snapshots(story_id);
CREATE INDEX idx_quality_snapshots_date ON quality_snapshots(snapshot_date);

-- RLS policy
ALTER TABLE quality_snapshots ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admin access to quality snapshots" ON quality_snapshots
  FOR ALL USING (true);
```

Apply both migrations via Supabase MCP `apply_migration`.

---

## Part 2: Quality Dashboard Service

Create a new file: `neverending-story-api/src/services/quality-intelligence.js`

This service computes quality metrics from existing data across multiple tables. It does NOT make any AI calls — it's pure database aggregation.

### Function 1: `computeStoryQualitySnapshot(storyId)`

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
- `reader_pacing_satisfaction`: Aggregate `pacing_feedback` values (these are text like "hooked", "slow", "fast" — just return an array of all values or a distribution object like `{"hooked": 2, "slow": 1}`)
- `reader_tone_satisfaction`: Same aggregation for `tone_feedback`
- `reader_character_satisfaction`: Same aggregation for `character_feedback`
- Count of feedback entries where `follow_up_action` is not null (indicates reader requested course corrections)

**From `chapter_reading_stats` table (where story_id = storyId):**
- `completion_rate`: Count where `completed = true` / total rows (% of chapters read to completion)
- `avg_reading_time_per_chapter`: Average of `total_reading_time_seconds`

**From `reading_sessions` table (where story_id = storyId):**
- `abandonment_chapter`: Find chapters where `abandoned = true`. If any exist, return the lowest chapter_number as the abandonment point. If none, return null.

**From `api_costs` table (where story_id = storyId):**
- `total_generation_cost`: Sum of `cost`
- `cost_per_chapter`: `total_generation_cost` / number of chapters
- Cost breakdown by operation: Group by `operation` and sum costs (gives per-system cost like 'generate_chapter', 'quality_review', 'extract_character_ledger', 'voice_review', 'voice_revision')

**From `stories` table:**
- `generation_config`: The story's feature flag configuration

Return all of the above as a structured object. Also INSERT a row into `quality_snapshots` with the computed data and today's date.

### Function 2: `computeDashboard(options = {})`

The main dashboard function. Accepts optional filters:
- `options.storyIds` — array of specific story IDs (if not provided, use all stories)
- `options.since` — date string, only include stories created after this date
- `options.limit` — max stories to include (default 20, most recent first)

**What it does:**

1. Fetch qualifying stories from `stories` table (where status is not 'error' and at least 1 chapter exists)
2. For each story, call `computeStoryQualitySnapshot(storyId)` to get individual metrics
3. Aggregate across all stories to produce fleet-level metrics:

**Fleet-level aggregations:**
- `fleet_quality_avg`: Average ai_quality_avg across all stories
- `fleet_voice_avg`: Average voice_authenticity_avg across all stories
- `fleet_revision_rate`: Average revision rate across all stories
- `fleet_callback_utilization`: Average callback utilization
- `fleet_completion_rate`: Average reader completion rate
- `fleet_cost_per_chapter`: Average cost per chapter
- `total_stories_analyzed`: Count
- `total_chapters_analyzed`: Count

**Per-dimension breakdown:**
- Average score for each quality dimension (show_dont_tell, dialogue_quality, etc.) across all stories
- Identify the weakest dimension (lowest average) — this becomes the improvement target

**Per-system cost breakdown:**
- Average cost per system per chapter (character_ledger, voice_review, quality_review, etc.)

**Feature flag distribution:**
- How many stories have each system enabled vs disabled (for when we start A/B testing)

Return everything in a clean JSON structure that's easy to display.

### Function 3: `getStoryQualityDetail(storyId)`

Deep-dive into a single story's quality. Returns:
- The full snapshot data from `computeStoryQualitySnapshot`
- Per-chapter quality scores (array of {chapter_number, quality_score, voice_authenticity, had_revision, has_ledger_entry})
- Quality trend: Are scores improving, declining, or stable across chapters? (simple linear regression or just compare first half vs second half averages)

Export all three functions.

---

## Part 3: Feature Flag Integration in `generation.js`

Wire the `generation_config` column into `generateChapter()` so each system can be toggled per-story.

### 3A: Character Continuity Block (line 2011-2012)

Currently:
```javascript
const { buildCharacterContinuityBlock } = require('./character-intelligence');
const characterContinuityBlock = await buildCharacterContinuityBlock(storyId, chapterNumber);
```

Change to:
```javascript
const { buildCharacterContinuityBlock } = require('./character-intelligence');
const config = story.generation_config || {};
const characterContinuityBlock = config.character_ledger !== false
  ? await buildCharacterContinuityBlock(storyId, chapterNumber)
  : '';

if (config.character_ledger === false) {
  console.log(`⚙️ [${storyTitle}] Character ledger DISABLED by generation_config`);
}
```

### 3B: Learned Preferences Block (line 1979-2000)

Currently:
```javascript
const writingPrefs = await getUserWritingPreferences(userId);
let learnedPreferencesBlock = '';
if (writingPrefs && writingPrefs.stories_analyzed >= 2 && writingPrefs.confidence_score >= 0.5) {
  // ... builds the block
}
```

Change to:
```javascript
const config = story.generation_config || {};
let learnedPreferencesBlock = '';
if (config.adaptive_preferences !== false) {
  const writingPrefs = await getUserWritingPreferences(userId);
  if (writingPrefs && writingPrefs.stories_analyzed >= 2 && writingPrefs.confidence_score >= 0.5) {
    // ... builds the block (existing logic unchanged)
  }
} else {
  console.log(`⚙️ [${storyTitle}] Adaptive preferences DISABLED by generation_config`);
}
```

**IMPORTANT:** The story object is fetched at line 1909-1913 via `select('*')`, so `story.generation_config` will be available after the column is added. But the `config` variable needs to be defined BEFORE the learned preferences block (around line 1978). Then reuse the same `config` variable at line 2011 for the character ledger check.

### 3C: Course Corrections Block (line 2001-2008)

Currently:
```javascript
let courseCorrectionsBlock = '';
if (courseCorrections) {
  courseCorrectionsBlock = `...`;
}
```

Change to:
```javascript
let courseCorrectionsBlock = '';
if (courseCorrections && config.course_corrections !== false) {
  courseCorrectionsBlock = `...`;
} else if (courseCorrections && config.course_corrections === false) {
  console.log(`⚙️ [${storyTitle}] Course corrections DISABLED by generation_config (feedback ignored)`);
}
```

### 3D: Post-Generation Systems (lines 2425-2449)

Currently the ledger extraction and voice review run unconditionally.

Change the character ledger extraction (line 2425-2431):
```javascript
if (config.character_ledger !== false) {
  try {
    await extractCharacterLedger(storyId, chapterNumber, chapter.content, userId);
    console.log(`📚 [${storyTitle}] Character ledger extracted for chapter ${chapterNumber}`);
  } catch (err) {
    console.error(`⚠️ [${storyTitle}] Character ledger extraction failed for chapter ${chapterNumber}: ${err.message}`);
  }
} else {
  console.log(`⚙️ [${storyTitle}] Skipping ledger extraction (character_ledger disabled)`);
}
```

Change the voice review block (lines 2433-2449):
```javascript
if (config.voice_review !== false) {
  try {
    const voiceReview = await reviewCharacterVoices(storyId, chapterNumber, chapter.content, userId);
    // ... existing logic unchanged
  } catch (err) {
    console.error(`⚠️ [${storyTitle}] Voice review failed for chapter ${chapterNumber}: ${err.message}`);
  }
} else {
  console.log(`⚙️ [${storyTitle}] Skipping voice review (voice_review disabled)`);
}
```

**CRITICAL:** The `config` variable must be accessible in the post-generation section. Since it's defined earlier in the function (around line 1978), it will be in scope. But double-check that `config` is NOT redefined or shadowed anywhere between definition and use.

---

## Part 4: Admin Endpoints

Add to `neverending-story-api/src/routes/admin.js`, after the existing character-intelligence endpoint (after line 280):

### Endpoint 1: `GET /admin/quality/dashboard`

Query params:
- `since` (optional): ISO date string to filter stories created after this date
- `limit` (optional): Max stories to analyze (default 20)

Calls `computeDashboard({ since, limit })` and returns the result.

### Endpoint 2: `GET /admin/quality/story/:storyId`

Calls `getStoryQualityDetail(storyId)` and returns the result. This is the deep-dive into a single story.

### Endpoint 3: `POST /admin/quality/snapshot`

Body: `{ storyId }` (required)

Calls `computeStoryQualitySnapshot(storyId)` to force-compute and store a snapshot for a specific story. Returns the snapshot.

All three endpoints should use the existing admin pattern: `authenticateUser` middleware, `asyncHandler` wrapper, and check `req.user.role === 'admin'` (returning 403 if not).

---

## Part 5: Logging

Use the ⚙️ emoji prefix for feature flag messages (as shown in the code changes above).

Use 📊 for quality intelligence events:
- `📊 [Title] Quality snapshot computed: quality=X.X, voice=X.XX, completion=XX%`
- `📊 Fleet dashboard: X stories analyzed, avg quality=X.X, weakest dimension=XXX`

---

## What NOT to Do

1. **Do NOT make any AI API calls** — this is pure database aggregation
2. **Do NOT change the default generation behavior** — all systems default to ON. The feature flags only change behavior when explicitly set to `false`
3. **Do NOT modify the quality review loop** (lines 2195-2385 in generation.js) — that stays exactly as-is
4. **Do NOT create any scheduled jobs** — the dashboard is on-demand only for now
5. **Do NOT modify any tables other than `stories`** (adding generation_config) and creating the new `quality_snapshots` table
6. **Do NOT use `.single()` for queries that might return no rows** — use `.maybeSingle()` or handle empty results gracefully
7. **Do NOT assume `quality_review` JSONB exists on every chapter** — some early chapters may not have it. Guard with null checks.

---

## Files to Create/Modify

| File | Action |
|------|--------|
| Database | Migration: add `generation_config` to stories, create `quality_snapshots` table |
| `src/services/quality-intelligence.js` | CREATE — three functions |
| `src/services/generation.js` | MODIFY — wrap 4 systems in feature flag checks |
| `src/routes/admin.js` | MODIFY — add 3 new endpoints |

---

## Verification

After implementation, confirm:
1. `generation_config` column exists on `stories` table with correct default
2. `quality_snapshots` table exists with all columns
3. `GET /admin/quality/dashboard` returns data (even if some metrics are null for stories without reader data)
4. Feature flag checks are in place but do NOT change default behavior (all flags default to true)
5. Generating a chapter with default config produces identical behavior to before (no regressions)
