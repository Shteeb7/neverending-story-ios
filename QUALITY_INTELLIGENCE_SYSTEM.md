# Quality Intelligence System
## Mythweaver — Measuring, Iterating, and Proving Writing Quality

**Date Created:** February 15, 2026
**Status:** MASTER PLAN — Not Yet Implemented
**Goal:** Build the measurement backbone that proves every generation system (Adaptive Reading Engine, Character Relationship Ledger, Voice Review) actually improves writing quality — and provides a structured process for continuous improvement based on real data, not vibes.

---

## Why This Matters

We've built four sophisticated generation systems (quality review, adaptive reading engine, character relationship ledger, voice review). Each adds cost and latency. But right now we can't answer the most basic questions:

- Does the character ledger actually make characters feel more real to readers?
- Is voice review catching issues the quality review misses, or just adding cost?
- Are adaptive reader preferences actually making stories better, or just different?
- When we tweak a prompt, did quality go up or down?

Without measurement, we're optimizing in the dark. With measurement, every system either proves its value or gets cut. This is what separates a research project from a product.

---

## The Three Problems

### Problem 1: No Baseline (We Can't A/B Test)

Every story gets every system. The character ledger, voice review, and adaptive engine all fire on every chapter. If quality is good, we don't know which system deserves credit. If quality is bad, we don't know which system is failing.

**Solution:** Feature flags per story that let us selectively enable/disable individual systems for controlled comparison.

### Problem 2: AI Grading AI (Closed Loop)

Opus writes a chapter, then Opus reviews it and gives it a 7.8. Sonnet does the voice review and scores authenticity at 0.91. These numbers tell us AI thinks AI did a good job. We have no idea if a 7.5 quality score means "a human would enjoy this" or "a human would put this down after two paragraphs."

**Solution:** A calibration loop where human reviewers periodically score chapters on the same rubric. We correlate human scores with AI scores to find where they diverge. That tells us which rubric dimensions to trust and which to recalibrate.

### Problem 3: No Iteration Process (Manual and Ad Hoc)

Writing Intelligence aggregates feedback. The admin endpoints surface data. But there's no structured cycle for: identify weakest dimension → generate prompt fix → test fix → verify improvement → ship. Right now this requires manual investigation every time.

**Solution:** An automated iteration cycle that runs periodically, identifies the weakest quality dimension, recommends a specific prompt adjustment, and tracks whether the adjustment actually helped.

---

## Architecture: Four Layers

### Layer 1: Quality Signal Aggregation

Bring every existing quality signal into a unified view. We already collect all of this — it's just scattered across tables with no central analysis.

**Signals we already have:**

| Signal | Source Table | What It Tells Us |
|--------|-------------|-----------------|
| Quality review scores | chapters.quality_review | AI's assessment of craft quality (show-don't-tell, dialogue, pacing, etc.) |
| Voice review scores | character_voice_reviews.review_data | Character authenticity per chapter |
| Revision rates | character_voice_reviews.revision_applied | How often voice review triggers fixes |
| Callback utilization | character_ledger_entries.callback_bank | How many planted moments get reused |
| Reader feedback | story_feedback (pacing, tone, character) | Direct reader opinion at checkpoints |
| Reading behavior | reading_sessions, chapter_reading_stats | Completion rates, reading time, abandonment |
| Course corrections | story_feedback.follow_up_action | When readers ask for changes (signal of misalignment) |
| Generation cost | api_costs | Cost per book, per system |

**New aggregation: `quality_snapshots` table**

A periodic snapshot (per story, or per batch of stories) that computes composite metrics:

```sql
CREATE TABLE quality_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_date DATE NOT NULL,
  story_id UUID REFERENCES stories(id) ON DELETE CASCADE,

  -- Composite scores
  ai_quality_avg NUMERIC,           -- Average weighted quality score across chapters
  voice_authenticity_avg NUMERIC,    -- Average voice review authenticity across chapters
  revision_rate NUMERIC,             -- % of chapters that needed voice revision
  callback_utilization NUMERIC,      -- % of planted callbacks that got reused

  -- Reader signals
  reader_pacing_satisfaction TEXT,    -- Aggregated pacing feedback (hooked/slow/fast distribution)
  reader_tone_satisfaction TEXT,      -- Aggregated tone feedback
  reader_character_satisfaction TEXT, -- Aggregated character feedback
  completion_rate NUMERIC,           -- % of generated chapters that were read to 90%+
  avg_reading_time_per_chapter INTEGER, -- Seconds
  abandonment_chapter NUMERIC,       -- Average chapter where readers stop (null if completed)

  -- Generation config (what systems were active)
  generation_config JSONB,           -- Feature flags: which systems were on/off

  -- Cost
  total_generation_cost NUMERIC,     -- Total API cost for this book
  cost_per_chapter NUMERIC,          -- Average cost per chapter

  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Layer 2: A/B Feature Attribution

Feature flags that control which generation systems are active per story. This lets us run controlled experiments.

**New column on `stories` table:**

```sql
ALTER TABLE stories ADD COLUMN generation_config JSONB DEFAULT '{
  "character_ledger": true,
  "voice_review": true,
  "adaptive_preferences": true,
  "course_corrections": true
}'::jsonb;
```

**How it works:**

In `generateChapter()`, before calling each system, check the story's `generation_config`:

```javascript
const config = story.generation_config || {};

// Only build continuity block if ledger is enabled
const characterContinuityBlock = config.character_ledger !== false
  ? await buildCharacterContinuityBlock(storyId, chapterNumber)
  : '';

// Only run voice review if enabled
if (config.voice_review !== false) {
  const voiceReview = await reviewCharacterVoices(...);
  // ...
}

// Only inject learned preferences if enabled
const learnedPreferencesBlock = config.adaptive_preferences !== false
  ? await buildLearnedPreferencesBlock(...)
  : '';
```

Default is all systems ON (existing behavior). But we can create stories with specific systems disabled for comparison.

**Experiment management:**

```sql
CREATE TABLE experiments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,                    -- "Character Ledger Impact Study"
  description TEXT,
  status TEXT DEFAULT 'active',          -- active, paused, completed, analyzed

  -- Experiment design
  control_config JSONB NOT NULL,         -- Feature flags for control group
  variant_config JSONB NOT NULL,         -- Feature flags for variant group
  assignment_rate NUMERIC DEFAULT 0.5,   -- % of stories assigned to variant

  -- Results (filled after analysis)
  results JSONB,
  conclusion TEXT,

  started_at TIMESTAMPTZ DEFAULT NOW(),
  ended_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE experiment_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  experiment_id UUID REFERENCES experiments(id),
  story_id UUID REFERENCES stories(id),
  group_name TEXT NOT NULL,              -- 'control' or 'variant'
  assigned_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(experiment_id, story_id)
);
```

**Example experiment:** "Does the Character Ledger improve reader satisfaction?"

- Control: `{ "character_ledger": false, "voice_review": false }` (no ledger, no voice review)
- Variant: `{ "character_ledger": true, "voice_review": true }` (full system)
- Measure: reader character_feedback scores, completion rates, reading time
- Run until N=20 stories per group (enough for signal)

### Layer 3: Human Calibration Loop

The most critical layer. Human scores calibrate the AI scoring system.

**How it works:**

1. Steven (or future reviewers) periodically reads a chapter through a simple review interface
2. Scores it on the same rubric dimensions the AI uses (1-10 each)
3. System compares human score vs AI score for that chapter
4. Over time, we build a calibration dataset that shows where AI over- or under-scores

**New table:**

```sql
CREATE TABLE human_quality_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reviewer_id UUID REFERENCES users(id),  -- Who reviewed it
  story_id UUID REFERENCES stories(id),
  chapter_number INTEGER NOT NULL,

  -- Same rubric dimensions as AI quality review
  show_dont_tell_score NUMERIC,          -- 1-10
  dialogue_quality_score NUMERIC,        -- 1-10
  pacing_engagement_score NUMERIC,       -- 1-10
  age_appropriateness_score NUMERIC,     -- 1-10
  character_consistency_score NUMERIC,   -- 1-10
  prose_quality_score NUMERIC,           -- 1-10
  overall_score NUMERIC,                 -- 1-10 gut feeling

  -- Character-specific assessment
  character_authenticity JSONB,          -- { "Marcus": 0.9, "Elena": 0.7 } — same scale as voice review

  -- Qualitative
  strengths TEXT,
  weaknesses TEXT,
  notes TEXT,

  -- Comparison (computed after save)
  ai_quality_score NUMERIC,              -- What the AI gave this chapter
  ai_voice_avg_score NUMERIC,            -- What voice review gave this chapter
  score_delta NUMERIC,                   -- human_overall - ai_quality (positive = AI underscored)

  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(reviewer_id, story_id, chapter_number)
);
```

**Calibration analysis:**

After accumulating 20+ human reviews, run analysis:

- **Correlation:** Do AI scores predict human scores? (Pearson r > 0.7 = good)
- **Bias detection:** Does AI consistently over-score dialogue but under-score pacing? (mean delta per dimension)
- **Threshold validation:** Is our 7.5 pass threshold right? What AI score corresponds to a human "this is good" (7+)?
- **Voice review calibration:** Do human character authenticity scores match voice review scores?

This analysis drives rubric weight adjustments. If humans consistently score dialogue lower than AI, we increase the dialogue weight in the quality review rubric.

**Admin endpoints:**

- `GET /admin/quality/review-queue` — returns a random chapter that hasn't been human-reviewed (prioritize recently generated chapters)
- `POST /admin/quality/human-review` — submit a human review
- `GET /admin/quality/calibration` — returns correlation analysis and recommended rubric adjustments

### Layer 4: Automated Iteration Cycle

A scheduled process that turns data into action.

**The cycle (runs weekly or per-N-books):**

```
1. MEASURE
   └─ Aggregate quality signals across recent books
   └─ Identify weakest quality dimension (lowest avg score)
   └─ Identify highest-cost system (cost/quality ratio)

2. DIAGNOSE
   └─ Pull specific chapters that scored lowest on the weak dimension
   └─ Send to Claude Sonnet with: "Here are 5 chapters that scored low on [dimension].
      What patterns do you see? What prompt adjustments would fix this?"
   └─ Sonnet returns specific, actionable prompt changes

3. RECOMMEND
   └─ Log recommendation to prompt_adjustment_log (table already exists!)
   └─ Flag for admin review OR auto-apply if confidence is high

4. VERIFY (next cycle)
   └─ Compare quality scores on the targeted dimension: before adjustment vs after
   └─ If improved → keep the change, log success
   └─ If unchanged or worse → revert, log failure, try different approach
```

**New table for iteration tracking:**

```sql
CREATE TABLE quality_iteration_cycles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cycle_date DATE NOT NULL,

  -- What we found
  weakest_dimension TEXT NOT NULL,        -- e.g., "dialogue_quality"
  dimension_avg_score NUMERIC,            -- Current average
  sample_chapter_ids UUID[],              -- Chapters analyzed

  -- What we recommend
  diagnosis TEXT,                          -- Sonnet's analysis of the pattern
  recommended_adjustment TEXT,            -- Specific prompt change
  adjustment_applied BOOLEAN DEFAULT FALSE,
  applied_at TIMESTAMPTZ,

  -- Verification (filled next cycle)
  post_adjustment_avg NUMERIC,            -- Score after change was applied
  improvement_delta NUMERIC,              -- post - pre (positive = improvement)
  verdict TEXT,                           -- 'improved', 'unchanged', 'regressed'

  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## Implementation Phases

### Phase 1: Quality Dashboard & Signal Aggregation

- Create `quality_snapshots` table
- Build `GET /admin/quality/dashboard` endpoint that computes and returns all signals for recent books
- Add `generation_config` column to stories table (default all-on)
- Wire feature flag checks into generateChapter() so systems can be toggled
- No new AI calls, no new cost — just organizing existing data

**Priority:** Foundation. Everything else builds on this.

### Phase 2: A/B Framework

- Create `experiments` and `experiment_assignments` tables
- Build admin endpoints: create experiment, assign stories, view results
- Add experiment assignment logic to story creation (automatically assigns new stories to active experiments)
- Build experiment analysis function (compare quality_snapshots between control and variant groups)

**Priority:** This is how we prove each system's value. Run first experiment: Character Ledger ON vs OFF.

### Phase 3: Human Calibration

- Create `human_quality_reviews` table
- Build admin endpoints: review queue, submit review, calibration analysis
- Build correlation analysis function (compare human vs AI scores)
- Generate recommended rubric weight adjustments based on calibration data
- Requires Steven (or future testers) to review ~20 chapters to build initial calibration dataset

**Priority:** This is how we ensure AI scores mean something. Can start as simple as Steven reading and rating chapters through an API endpoint.

### Phase 4: Automated Iteration

- Create `quality_iteration_cycles` table
- Build scheduled job (runs weekly or triggered manually)
- Implement the MEASURE → DIAGNOSE → RECOMMEND → VERIFY cycle
- Hook into existing `prompt_adjustment_log` table for audit trail
- Add auto-revert capability (if adjustment hurts quality, undo it)

**Priority:** This is the growth engine. Once calibrated, the system improves itself over time.

---

## Cost Analysis

| Component | Model | Cost per Run | Frequency |
|-----------|-------|-------------|-----------|
| Quality dashboard | None (DB queries) | $0.00 | On demand |
| A/B assignment | None (logic only) | $0.00 | Per story |
| A/B analysis | Sonnet (optional) | ~$0.05 | Per experiment |
| Human calibration | None (human input) | $0.00 | Per review |
| Calibration analysis | Sonnet | ~$0.10 | Monthly |
| Iteration cycle — diagnosis | Sonnet | ~$0.15 | Weekly |
| Iteration cycle — verification | None (DB queries) | $0.00 | Weekly |

**Total new AI cost:** ~$0.60-1.00/month at current scale. Negligible.

The real cost is Steven's time for human calibration (~20 minutes per chapter review, need ~20 reviews for initial calibration = ~7 hours total). This investment pays for itself by ensuring every other AI dollar we spend is actually improving quality.

---

## Success Metrics

### How we know the Quality Intelligence System itself is working:

1. **A/B attribution clarity:** Can we confidently say "the character ledger improves character satisfaction scores by X%" after running an experiment? Target: statistically significant result within 30 stories per group.

2. **Human-AI calibration correlation:** Pearson r > 0.7 between human overall scores and AI weighted quality scores. If lower, we know the AI rubric needs recalibration.

3. **Iteration cycle impact:** At least 1 measurable quality improvement per month from the automated iteration cycle. Track cumulative improvement over time.

4. **Cost efficiency:** Can identify and disable any system that doesn't measurably improve quality, saving its per-chapter cost. Target: every system in the pipeline has proven positive ROI.

5. **Reader retention signal:** Completion rates and return rates for ledger-enhanced stories are measurably higher than baseline. This is the ultimate business metric.

---

## What This Enables Long-Term

With this system in place, Mythweaver becomes a **self-improving writing engine**:

- Every book generated produces data that makes the next book better
- Every reader interaction calibrates the system's understanding of quality
- Every prompt adjustment is tracked, measured, and verified
- Systems that don't earn their cost get identified and optimized or removed
- New systems can be validated through A/B testing before full rollout

This is the moat. Anyone can build a story generator. Building one that measurably improves with every book it writes — and can prove it to investors with data — is a fundamentally different product.

---

*You can't improve what you can't measure. The generation systems are the engine. This is the dashboard, the telemetry, and the pit crew.*
