# Adaptive Reading Engine
## Neverending Story — Real-Time Story Personalization

**Date Created:** February 14, 2026
**Status:** IMPLEMENTED — Phases 1-4 complete (Feb 14, 2026). Phase 5 (Testing & Validation) pending deployment.
**Supersedes:** Feedback checkpoint system in FEEDBACK_AND_SEQUEL_SYSTEM.md (chapters 3/6/9 with Fantastic/Great/Meh)
**Goal:** Transform the reading experience from static delivery to a living conversation between Prospero and the reader, where each batch of chapters is crafted based on real-time feedback — and where aggregate reader intelligence continuously improves the engine for everyone.

---

## The Problem with the Current System

The existing feedback system has three fatal flaws:

**1. It asks too late.** Six chapters are pre-generated before the reader turns a single page. By the time they hit the chapter 3 checkpoint, the die is cast for half the book.

**2. It asks the wrong question.** "Fantastic / Great / Meh" tells us satisfaction level but nothing about what to change. A reader who wants more humor and a reader who wants faster pacing both press "Meh" — and the system can't distinguish between them.

**3. It doesn't steer.** Even positive feedback ("Great") triggers chapter generation without injecting any reader signal into the generation prompt. The feedback is a gate (generate more chapters yes/no), not a steering wheel (adjust how those chapters are written).

The Adaptive Reading Engine fixes all three.

---

## The New Reading Rhythm

The core pattern: **Read 2 → Talk to Prospero → Read 1 (buffer) → next batch lands.**

The reader never waits. Prospero never interrupts mid-chapter. The system learns and adapts every three chapters.

```
STORY START: Generate Chapters 1-3

Reader reads Chapter 1
Reader reads Chapter 2
    ┌─────────────────────────────────────────┐
    │  PROSPERO CHECK-IN #1 (after Ch 2)      │
    │  "What do you think so far?"             │
    │  3 dimension taps: pacing, tone, connect │
    │  "Go enjoy Chapter 3 — I'll be weaving   │
    │   the next part while you read."         │
    └─────────────────────────────────────────┘
Reader reads Chapter 3 (BUFFER)
    └── Meanwhile: Chapters 4-6 generate with course corrections

Reader reads Chapter 4
Reader reads Chapter 5
    ┌─────────────────────────────────────────┐
    │  PROSPERO CHECK-IN #2 (after Ch 5)      │
    │  "We're halfway through! How did those   │
    │   last two chapters feel?"               │
    │  3 dimension taps (same dimensions)      │
    │  "Chapter 6 awaits — I'll have the next  │
    │   act ready when you emerge."            │
    └─────────────────────────────────────────┘
Reader reads Chapter 6 (BUFFER)
    └── Meanwhile: Chapters 7-9 generate with accumulated corrections

Reader reads Chapter 7
Reader reads Chapter 8
    ┌─────────────────────────────────────────┐
    │  PROSPERO CHECK-IN #3 (after Ch 8)      │
    │  "We're nearing the final act..."        │
    │  3 dimension taps                        │
    │  "The conclusion awaits in Chapter 9 —   │
    │   I'm crafting the finale as we speak."  │
    └─────────────────────────────────────────┘
Reader reads Chapter 9 (BUFFER)
    └── Meanwhile: Chapters 10-12 generate with accumulated corrections

Reader reads Chapter 10
Reader reads Chapter 11
Reader reads Chapter 12
    ┌─────────────────────────────────────────┐
    │  FULL VOICE INTERVIEW (after Ch 12)      │
    │  Deep conversation with Prospero          │
    │  What they loved, what could be better    │
    │  Sequel interest and preferences          │
    │  Feeds long-term preference learning      │
    └─────────────────────────────────────────┘
```

---

## The Three Dimensions

Each Prospero check-in asks the same three questions via quick taps (not text input, not voice — just taps). Consistency across checkpoints lets the system track deltas: "They said slow at Ch 2, now they say just right at Ch 5 — the correction worked."

### Pacing
**"How's the rhythm?"**

| Option | What it tells us | Generation adjustment |
|--------|-----------------|----------------------|
| I'm hooked | Pacing is working | Maintain current pacing parameters |
| A little slow | Needs more momentum | Enter scenes later, leave earlier. Shorter paragraphs. More cliffhanger chapter endings. Reduce descriptive passages. Increase action-to-reflection ratio. |
| Almost too fast | Needs room to breathe | Add sensory grounding moments. Longer scene transitions. More internal reflection. Let emotional beats land before moving on. |

### Tone
**"How's the mood landing?"**

| Option | What it tells us | Generation adjustment |
|--------|-----------------|----------------------|
| Just right | Tone is calibrated | Maintain current tone parameters |
| Too serious | Needs levity | Add moments of humor through dialogue and character interactions. Give protagonist or a secondary character dry wit. Include at least one moment of comic relief per chapter. Lighter metaphors. |
| Too light | Needs weight | Deepen emotional stakes. More consequence to actions. Richer internal conflict. Reduce banter, increase tension. |

### Character Connection
**"How are you feeling about [protagonist name]?"**

| Option | What it tells us | Generation adjustment |
|--------|-----------------|----------------------|
| Love them | Character is landing | Maintain current characterization |
| Warming up | Needs more depth | Add more interior thought and vulnerability. Show relatable mundane moments alongside the extraordinary. Reveal backstory through action, not exposition. |
| Not clicking | Fundamental disconnect | Increase protagonist agency and decisiveness. Show more competence. Add moments where they surprise the reader. Lean into their unique voice. |

### Why These Three (and Only Three)

These dimensions cover the three reasons someone puts a book down: it's boring (pacing), it's not the right vibe (tone), or they don't care about the characters (connection). Everything else — description density, dialogue style, vocabulary complexity — is downstream of these three. The system infers the right lever from the dimension feedback.

Three taps. Two seconds. No typing. No feeling like a focus group.

---

## No "Meh" Exit Strategy

The old system had a "Meh" response that branched into a follow-up dialog (Start a Different Story / Keep Reading / Give Story Tips). This is being removed.

Readers who are genuinely bored will do what every reader does: close the book. They'll naturally navigate to the library and pick something else. The app will detect this through behavioral analytics — an abandoned story at chapter 3 with low reading time per chapter IS the data point. We don't need to ask them to confirm they're bored.

This means the following files are **deprecated and should be removed:**

- `NeverendingStory/Views/Feedback/StoryFeedbackDialog.swift` — replaced by ProsperoCheckInView
- `NeverendingStory/Views/Feedback/MehFollowUpDialog.swift` — no longer needed

---

## Course Correction: How Feedback Becomes Better Writing

This is the core innovation. Each check-in's dimension responses map to a `<reader_course_correction>` XML block that gets injected into the generation prompt for the next batch of chapters.

### Single Checkpoint Example

Reader says after Ch 2: Pacing = "A little slow", Tone = "Too serious", Character = "Love them"

The generation prompt for chapters 4-6 includes:

```xml
<reader_course_correction>
  The reader has provided feedback on the story so far. Adjust your writing
  to address these preferences while maintaining the story bible and arc:

  PACING (reader said: a little slow):
  - Enter scenes later, leave earlier — skip setup the reader can infer
  - Shorter paragraphs during action sequences
  - End each chapter with a hook that creates immediate forward pull
  - Reduce descriptive passages; weave world-building into action
  - Increase the ratio of action and dialogue to reflection

  TONE (reader said: too serious):
  - Add at least one moment of levity or humor per chapter
  - Give the protagonist (or a secondary character) a dry wit
  - Use lighter metaphors and occasional self-aware moments
  - Balance heavy emotional beats with character warmth
  - Include humor that emerges naturally from character dynamics, not jokes

  CHARACTER (reader said: love them):
  - Maintain current characterization — it's working
  - Continue deepening what the reader already connects with

  IMPORTANT: These are adjustments to HOW the story is told, not WHAT happens.
  The story bible, arc outline, and plot events remain exactly as planned.
  Only the craft of the telling changes.
</reader_course_correction>
```

### Accumulated Corrections (Multiple Checkpoints)

By the time chapters 10-12 generate, the prompt carries all three rounds of feedback:

```xml
<reader_course_correction>
  Feedback history across this story:

  CHECKPOINT 1 (after Ch 2):
    Pacing: a little slow → CORRECTED in Ch 4-6
    Tone: too serious → CORRECTED in Ch 4-6
    Character: love them → Maintained

  CHECKPOINT 2 (after Ch 5):
    Pacing: I'm hooked → Correction worked, maintain
    Tone: just right → Correction worked, maintain
    Character: love them → Consistent

  CHECKPOINT 3 (after Ch 8):
    Pacing: I'm hooked → Stable
    Tone: just right → Stable
    Character: love them → Stable

  Current writing directives (accumulated):
  - Maintain increased action density and scene pacing from Ch 4+ correction
  - Maintain humor and levity level established in Ch 4+ correction
  - Character voice is consistent and working — no changes needed
  - For the finale (Ch 10-12): elevate all dimensions slightly for climactic payoff
</reader_course_correction>
```

The key insight: accumulated corrections show the system what worked and what didn't. A correction that "sticks" (reader confirms improvement at next checkpoint) becomes a stable directive. A correction that fails (reader still says "too serious") gets amplified.

---

## Preference Persistence: The Compounding Flywheel

Steven's requirement: "Make sure these preferences are logged so we aren't having to repeat this nudging over and over again."

### Within a Single Story (Intra-Story)

Each checkpoint's structured feedback is stored in the `story_feedback` table with the new dimension fields. The generation prompt for the next batch includes ALL accumulated corrections from previous checkpoints. By chapters 10-12, the system has three rounds of refinement.

### Across Stories (Cross-Story Learning)

After the book completion voice interview, the existing `analyzeUserPreferences()` function pulls all `story_feedback` rows. With structured dimension data (pacing: "a little slow", tone: "too serious"), the preference engine gets dramatically better signal than a single word like "Great."

The structured preferences are stored in `user_writing_preferences` and injected into the `<learned_reader_preferences>` XML block for future stories from chapter 1.

### The Result Over Time

**Story 1:** Lots of course corrections. The system is learning this reader.

**Story 2:** Initial generation already incorporates learned preferences. Chapters 1-3 are written with the reader's preferred pacing and tone baked in. Checkpoints still happen, but corrections should be smaller or unnecessary. Reader notices: "This one nailed it right away."

**Story 3+:** System nails it from chapter 1. Checkpoints become confirmation ("just right" across the board) rather than correction. Reader thinks: "This app gets me."

That's the flywheel. Each story teaches the system more, and the checkpoints shift from steering to validation.

---

## Global Writing Intelligence: Making Every Book Better for Everyone

Individual reader preferences (likes humor, prefers fast pacing) are personal and should never bleed across users. But aggregate patterns across ALL readers reveal something different: systemic truths about what constitutes good writing.

### The Insight

If 70% of readers say "too serious" at their first checkpoint, that's not a personal preference — that's a signal that our base generation prompts are too heavy. If "a little slow" is the most common pacing feedback for mystery stories but rare for fantasy, that tells us our mystery pacing defaults need adjustment.

### What We Collect (Anonymized and Aggregated)

Every checkpoint response gets stored with the reader's dimension selections. Over time, this creates a dataset:

```
Aggregate patterns we can detect:
- Most common feedback per dimension, per genre, per checkpoint
- Correction success rate: "Did the reader report improvement at the next checkpoint?"
- Abandonment correlation: "What checkpoint responses predict story abandonment?"
- Genre-specific patterns: "Fantasy readers want faster pacing; romance readers want slower"
- Age-range patterns: "Young adult readers need more humor than adult literary readers"
- Which corrections amplify engagement vs. which have no effect
```

### How It Improves the System

**Phase 1 (Manual):** Build an admin query/dashboard that surfaces aggregate patterns. Steven (or whoever manages the product) reviews the data periodically and manually adjusts base generation prompts. Example: "80% of readers say 'too serious' for fantasy → increase default humor level in the base fantasy prompt."

**Phase 2 (Semi-Automated):** The system generates a quarterly "Writing Intelligence Report" — a Claude-analyzed summary of aggregate feedback patterns with specific recommended prompt adjustments. A human reviews and approves changes.

**Phase 3 (Automated, Future):** The system auto-tunes base generation prompts per genre based on statistically significant aggregate patterns. Guardrails prevent drift. A/B testing validates improvements.

### Data Model for Global Intelligence

New table: `writing_intelligence_snapshots`
- Periodic aggregation of all checkpoint feedback
- Broken down by genre, age range, checkpoint number
- Includes correction success rates and abandonment correlations
- Feeds admin dashboard and eventual auto-tuning

New table: `prompt_adjustment_log`
- Tracks every change to base generation prompts
- Links to the aggregate data that motivated the change
- Enables rollback and A/B comparison

### The Virtuous Cycle

```
Readers give feedback → Individual stories improve (course correction)
                      → Individual preferences learn (cross-story)
                      → Aggregate patterns surface (global intelligence)
                      → Base prompts improve (system-wide)
                      → ALL future stories start better
                      → Readers need fewer corrections
                      → Corrections that DO happen are more meaningful signal
```

Every reader who uses the app makes it better for every future reader. That's the moat.

---

## Buffer Math: Why This Works Without Making Anyone Wait

### The Timing

| Metric | Value |
|--------|-------|
| Chapter word count | ~2,500 words |
| Average reading speed (engaged fiction) | ~250 words/minute |
| Time to read one chapter | ~10 minutes |
| Time to generate one chapter (with quality review) | ~2.5 minutes |
| Time to generate 3 chapters (sequential) | ~8 minutes |
| Buffer chapter reading time | ~10 minutes |
| **Margin** | **~2 minutes** |

### The Sequence

1. Reader finishes chapter 2
2. Prospero check-in appears (30-60 seconds of interaction)
3. Reader taps 3 dimensions, reads Prospero's farewell
4. Generation starts immediately (the INSTANT the check-in ends)
5. Reader opens chapter 3 (buffer)
6. Reader reads chapter 3 (~10 minutes)
7. Chapters 4-6 generate (~8 minutes)
8. By the time reader finishes chapter 3, chapters 4-6 are ready

The check-in conversation itself adds 30-60 seconds of buffer on top of the chapter reading time. Total effective buffer: ~11 minutes. Generation needs ~8. Margin of ~3 minutes.

### Edge Case: Speed Readers

If someone reads significantly faster than average, they could finish the buffer chapter before generation completes. For this case:

**Fallback screen:** A beautiful "Prospero is still crafting..." animation. Not a loading spinner — an atmospheric, on-brand moment with Prospero's magical energy visual. Could include a contextual message: "The next chapter of [story title] is being woven..." This should be rare but graceful when it happens.

### Generation Pipeline Change

**Current:** `orchestratePreGeneration()` generates chapters 1-6 sequentially.

**New:** Renamed to `generateBatch()` — generates 3 chapters at a time with course correction context.

```
Initial call:    generateBatch(storyId, 1, 3, userId)        → Chapters 1-3
After Ch 2:      generateBatch(storyId, 4, 6, userId, corrections)  → Chapters 4-6
After Ch 5:      generateBatch(storyId, 7, 9, userId, corrections)  → Chapters 7-9
After Ch 8:      generateBatch(storyId, 10, 12, userId, corrections) → Chapters 10-12
```

Each subsequent call receives the accumulated course correction context from all previous checkpoints.

---

## Database Changes

### Modified Table: `story_feedback`

Add structured dimension columns alongside the existing response field:

```sql
ALTER TABLE story_feedback
  ADD COLUMN pacing_feedback TEXT,           -- 'hooked', 'slow', 'fast'
  ADD COLUMN tone_feedback TEXT,             -- 'right', 'serious', 'light'
  ADD COLUMN character_feedback TEXT,        -- 'love', 'warming', 'not_clicking'
  ADD COLUMN protagonist_name TEXT;          -- for context in aggregate analysis

-- Update checkpoint values: 'chapter_2', 'chapter_5', 'chapter_8' (was 3, 6, 9)
-- Old 'response' column (Fantastic/Great/Meh) becomes unused for new checkpoints
-- Keep for backward compatibility with any existing data
```

### New Table: `writing_intelligence_snapshots`

```sql
CREATE TABLE writing_intelligence_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_date DATE NOT NULL,
  genre TEXT,
  age_range TEXT,
  checkpoint TEXT,                           -- 'chapter_2', 'chapter_5', 'chapter_8'
  total_responses INTEGER NOT NULL,
  pacing_distribution JSONB,                 -- {"hooked": 45, "slow": 38, "fast": 17}
  tone_distribution JSONB,                   -- {"right": 52, "serious": 35, "light": 13}
  character_distribution JSONB,              -- {"love": 60, "warming": 30, "not_clicking": 10}
  correction_success_rate NUMERIC(5,2),      -- % of corrections that resulted in improvement
  abandonment_rate NUMERIC(5,2),             -- % of readers who stopped after this checkpoint
  insights JSONB,                            -- Claude-generated analysis
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### New Table: `prompt_adjustment_log`

```sql
CREATE TABLE prompt_adjustment_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  adjustment_type TEXT NOT NULL,             -- 'base_prompt', 'genre_default', 'quality_rubric'
  genre TEXT,
  description TEXT NOT NULL,                 -- human-readable what changed
  previous_value TEXT,
  new_value TEXT,
  data_basis TEXT,                           -- what aggregate data motivated this
  snapshot_id UUID REFERENCES writing_intelligence_snapshots(id),
  applied_by TEXT NOT NULL,                  -- 'manual' or 'auto'
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## API Changes

### Modified Endpoint: `POST /feedback/checkpoint`

**New request body:**
```json
{
  "storyId": "uuid",
  "checkpoint": "chapter_2",
  "pacing": "slow",
  "tone": "serious",
  "character": "love",
  "protagonistName": "Kael"
}
```

**New response:**
```json
{
  "success": true,
  "feedback": { /* stored feedback with dimensions */ },
  "generatingChapters": [4, 5, 6],
  "courseCorrections": {
    "pacing": "Increasing pace — entering scenes later, more hooks",
    "tone": "Adding humor and levity through character interactions",
    "character": "Maintaining current characterization"
  }
}
```

**New trigger logic:**
- `checkpoint === 'chapter_2'` → generate chapters 4-6 with corrections
- `checkpoint === 'chapter_5'` → generate chapters 7-9 with accumulated corrections
- `checkpoint === 'chapter_8'` → generate chapters 10-12 with accumulated corrections

All three ALWAYS trigger generation (no gate based on satisfaction level).

### New Endpoint: `GET /admin/writing-intelligence`

Returns aggregate feedback analysis for monitoring and prompt tuning. Requires admin auth.

```json
{
  "success": true,
  "overall": {
    "total_checkpoints": 1247,
    "most_common_corrections": ["too_serious", "slow_pacing"],
    "correction_success_rate": 78.3
  },
  "by_genre": {
    "fantasy": {
      "pacing": {"hooked": 45, "slow": 38, "fast": 17},
      "tone": {"right": 32, "serious": 55, "light": 13}
    }
  },
  "recommended_adjustments": [
    "Fantasy base prompt: increase default humor — 55% of readers report 'too serious'",
    "Mystery pacing: current defaults working — 62% report 'hooked'"
  ]
}
```

---

## iOS Changes

### Files to DELETE
- `Views/Feedback/StoryFeedbackDialog.swift` — replaced by ProsperoCheckInView
- `Views/Feedback/MehFollowUpDialog.swift` — no longer needed (no Meh exit path)

### Files to CREATE

**`Views/Feedback/ProsperoCheckInView.swift`**

A full-screen modal with Prospero's avatar animation (reuse existing sparkles/glow aesthetic). Three dimension questions presented sequentially or simultaneously as quick taps. Prospero's dialogue is contextual to the checkpoint number:

- Check-in #1 (Ch 2): "What do you think so far?" → taps → "You've given me much to consider. Go enjoy Chapter 3 — I'll be weaving the next part while you read."
- Check-in #2 (Ch 5): "We're halfway through! How did those last two chapters feel?" → taps → "Wonderful. Chapter 6 awaits — I'll have the next act ready when you emerge."
- Check-in #3 (Ch 8): "We're nearing the final act..." → taps → "The conclusion awaits in Chapter 9 — I'm crafting the finale as we speak."

Prospero's farewell should reinforce the magic: he's going off to WRITE for you. The reader is the patron; Prospero is the artist.

**`Views/Feedback/GeneratingChaptersView.swift`**

Fallback screen for the rare case where a speed reader finishes the buffer chapter before the next batch is ready. Beautiful atmospheric animation with Prospero's energy. Contextual message: "Prospero is still weaving the next chapter of [story title]..." Checks for chapter availability on a timer and auto-dismisses when ready.

### Files to MODIFY

**`Views/Reader/BookReaderView.swift`**
- Change checkpoint triggers from chapters 3/6/9 to chapters 2/5/8
- Show ProsperoCheckInView instead of StoryFeedbackDialog
- Add GeneratingChaptersView fallback when next chapter isn't available
- Remove all Meh/follow-up handling

**`Services/APIManager.swift`**
- Update `submitFeedback()` to send structured dimensions (pacing, tone, character) instead of single response string
- Add method to check chapter availability (for buffer fallback)

**`Views/Onboarding/PremiseSelectionView.swift`**
- Remove `TalkToProsperoCard` struct and references (part of the Meh flow)

---

## Generation Engine Changes

### `generation.js` Modifications

**1. New function: `generateBatch(storyId, startChapter, endChapter, userId, courseCorrections)`**

Replaces the chapter 7-9 and 10-12 generation logic in `feedback.js`. Takes optional courseCorrections parameter containing accumulated dimension feedback. Generates chapters sequentially within the batch with 1-second pauses.

**2. Modified function: `generateChapter()` — course correction injection**

When courseCorrections are provided, build a `<reader_course_correction>` XML block and inject it into the chapter generation prompt alongside the existing `<learned_reader_preferences>` block:

```javascript
// Build course correction block from checkpoint feedback
let courseCorrectionsBlock = '';
if (courseCorrections && courseCorrections.length > 0) {
  const latestCorrections = buildCourseCorrections(courseCorrections);
  courseCorrectionsBlock = `
<reader_course_correction>
  ${latestCorrections}
</reader_course_correction>`;
}
```

The `<reader_course_correction>` block sits alongside but separate from `<learned_reader_preferences>`. Course corrections are real-time, same-story adjustments. Learned preferences are cross-story patterns. Both can coexist.

**3. Modified function: `orchestratePreGeneration()` — generate 3, not 6**

Change the initial generation loop from `i <= 6` to `i <= 3`. Update the completion status to `awaiting_chapter_2_feedback` instead of `awaiting_chapter_3_feedback`.

**4. New function: `buildCourseCorrections(feedbackHistory)`**

Takes an array of checkpoint feedback objects and returns the formatted course correction text. Handles:
- Single checkpoint: direct correction instructions
- Multiple checkpoints: accumulated corrections with delta tracking ("correction worked, maintain" vs "still an issue, amplify")

**5. Modified: `feedback.js` checkpoint handler**

- Accept new dimension fields (pacing, tone, character)
- Fetch previous checkpoints for this story to build accumulated corrections
- Call `generateBatch()` with corrections instead of directly calling `generateChapter()` in a loop
- Always trigger generation (no gate on satisfaction level)

---

## Implementation Phases

### Phase 1: Core Architecture (CC Session 1)

**API work:**
- Modify `orchestratePreGeneration()` to generate chapters 1-3 (not 1-6)
- Create `generateBatch()` function
- Create `buildCourseCorrections()` function
- Modify `generateChapter()` to accept and inject course corrections
- Modify checkpoint handler in `feedback.js` for new dimension structure and triggers at ch 2/5/8
- Database migration: add dimension columns to story_feedback

**Priority:** This is the foundation. Everything else depends on the API correctly generating batches of 3 with course corrections.

### Phase 2: iOS Overhaul (CC Session 2)

- Create ProsperoCheckInView (3-dimension tap UI)
- Create GeneratingChaptersView (buffer fallback)
- Modify BookReaderView checkpoint triggers (ch 2/5/8)
- Modify APIManager feedback submission
- Delete StoryFeedbackDialog, MehFollowUpDialog
- Remove TalkToProsperoCard from PremiseSelectionView
- Wire up new check-in flow end-to-end

**Priority:** This is the user-facing change. Must feel magical, not like a survey.

### Phase 3: Preference Accumulation (CC Session 3)

- Ensure checkpoint dimension data feeds into `analyzeUserPreferences()`
- Update the preference analysis prompt to weight structured dimension data
- Verify that Story 2 generation incorporates learned preferences from Story 1's checkpoints
- Test the full flywheel: Story 1 corrections → completion interview → Story 2 starts better

**Priority:** This is what makes the system compound over time.

### Phase 4: Global Writing Intelligence (CC Session 4)

- Create `writing_intelligence_snapshots` table
- Create `prompt_adjustment_log` table
- Build aggregate query/analysis functions
- Create admin endpoint for writing intelligence dashboard
- Design the first "Writing Intelligence Report" prompt

**Priority:** Lower urgency, but this is the long-term moat. Can wait until there's meaningful user data.

### Phase 5: Testing & Validation

- Integration smoke tests for the new 3-chapter batch flow
- Test course correction injection produces measurably different output
- Test accumulated corrections across all 3 checkpoints
- Test buffer timing (does the buffer chapter provide enough generation time?)
- Test the fallback GeneratingChaptersView
- Test the full Story 1 → preferences → Story 2 pipeline

---

## Cost Impact

### Current: $18.22 per 12-chapter story
- All generation happens upfront or in 2 large batches (6 then 3+3)
- No course correction overhead

### New: ~$19.50 per 12-chapter story (+7%)
- Same total chapters generated (12)
- Same quality review per chapter
- Small additional cost: fetching and processing checkpoint feedback for course correction context (~$0.30 per batch, 4 batches)
- Offset: fewer wasted chapters (currently generating 6 that a "Meh" reader may never read; now generating 3)

### Net: Likely cheaper in practice
- For readers who abandon early: we generate 3 chapters instead of 6 before they leave
- For readers who finish: marginal increase for dramatically better personalization
- The real ROI: higher completion rates and sequel engagement from course-corrected writing

---

## Files Reference (Complete)

### API Changes
| File | Change |
|------|--------|
| `src/services/generation.js` | `orchestratePreGeneration()` → 3 chapters, new `generateBatch()`, new `buildCourseCorrections()`, course correction injection in `generateChapter()` |
| `src/routes/feedback.js` | Checkpoint handler accepts dimensions, new trigger logic (ch 2/5/8), calls `generateBatch()` with corrections |
| `database/migrations/006_adaptive_reading.sql` | Add dimension columns to story_feedback, create writing_intelligence tables |

### iOS Changes
| File | Change |
|------|--------|
| `Views/Feedback/StoryFeedbackDialog.swift` | **DELETE** |
| `Views/Feedback/MehFollowUpDialog.swift` | **DELETE** |
| `Views/Feedback/ProsperoCheckInView.swift` | **CREATE** — 3-dimension tap check-in |
| `Views/Feedback/GeneratingChaptersView.swift` | **CREATE** — buffer fallback screen |
| `Views/Reader/BookReaderView.swift` | Change checkpoint triggers to ch 2/5/8, wire ProsperoCheckInView, add fallback |
| `Views/Onboarding/PremiseSelectionView.swift` | Remove TalkToProsperoCard |
| `Services/APIManager.swift` | Update feedback submission, add chapter availability check |

### Documentation
| File | Change |
|------|--------|
| `ADAPTIVE_READING_ENGINE.md` | **This document** — master plan |
| `FEEDBACK_AND_SEQUEL_SYSTEM.md` | Mark as SUPERSEDED by this document |
| `GENERATION_ENGINE_IMPROVEMENTS.md` | Update to reference new architecture |

---

## Success Metrics

### Immediate (Measurable After Phase 2)
- Correction success rate: reader reports improvement at next checkpoint > 70%
- Buffer reliability: readers hit GeneratingChaptersView fallback < 5% of the time
- Check-in completion rate: readers complete all 3 taps > 95% (should be near-instant)

### Medium Term (After 50+ Users)
- Chapter completion rate: > 85% (readers finish books they start)
- "Just right" response rate increases across checkpoints within a story (corrections working)
- Story 2 needs fewer corrections than Story 1 for same reader (cross-story learning working)

### Long Term (After 200+ Users)
- Aggregate patterns surface actionable prompt improvements quarterly
- Base prompt adjustments measurably improve first-checkpoint satisfaction scores
- New readers need fewer corrections than early adopters did (system-wide improvement)

---

## The Moat

Competitors can copy the generation prompts. They can use the same AI models. They can build a similar app.

What they can't copy is a dataset of thousands of structured reader feedback signals mapped to specific writing dimensions, across genres, across age ranges, across reading behaviors — continuously improving the engine that writes every story.

Every reader who uses Neverending Story makes it better for every future reader. That's not a feature. That's a flywheel.

---

**Owner:** Steven (steven.labrum@gmail.com)
**Status:** Master plan approved. Ready for implementation.
