# Generation Pipeline Smoke Test — Suite 1

## Purpose

End-to-end integration test of the full Mythweaver generation pipeline using **live API calls** against the production Railway server. Tests 4 mock reader profiles from preferences through chapter generation, checkpoint feedback, course corrections, completion interviews, and sequel generation.

**Why now:** We've shipped Quality Review, Adaptive Reading Engine, Character Relationship Ledger, Voice Review, QIS Phase 1 Feature Flags, and Checkpoint UX Fixes in rapid succession. This test validates the full pipeline still works as an integrated system.

**Estimated cost:** ~$60-80 in Claude API usage across all 4 profiles
**Estimated time:** 30-45 minutes if profiles run in parallel
**Execution:** CC runs the test script. Steven and Max review at each gate before advancing.

---

## Setup: Create Test Users

Before any API calls, create 4 test users in Supabase with consent flags and DOB set.

```sql
-- Run via Supabase MCP execute_sql (project: hszuuvkfgdfqgtaycojz)

-- Create auth users (CC should use supabase.auth.admin.createUser or insert directly)
-- For each profile, we need:
-- 1. An auth user (email/password)
-- 2. A user_preferences row with ai_consent=true, voice_consent=true, birth_month, birth_year

-- Profile A: 12-year-old fantasy reader
-- birth_year = 2014, birth_month = 3 → middle_grade
INSERT INTO user_preferences (user_id, ai_consent, ai_consent_date, voice_consent, voice_consent_date, birth_month, birth_year, is_minor, name_confirmed)
VALUES ('<profile_a_user_id>', true, now(), true, now(), 3, 2014, true, true);

-- Profile B: 58-year-old literary adult
-- birth_year = 1968, birth_month = 7 → adult
INSERT INTO user_preferences (user_id, ai_consent, ai_consent_date, voice_consent, voice_consent_date, birth_month, birth_year, is_minor, name_confirmed)
VALUES ('<profile_b_user_id>', true, now(), true, now(), 7, 1968, false, true);

-- Profile C: 16-year-old genre hopper
-- birth_year = 2010, birth_month = 11 → young_adult
INSERT INTO user_preferences (user_id, ai_consent, ai_consent_date, voice_consent, voice_consent_date, birth_month, birth_year, is_minor, name_confirmed)
VALUES ('<profile_c_user_id>', true, now(), true, now(), 11, 2010, true, true);

-- Profile D: 14-year-old reluctant reader
-- birth_year = 2012, birth_month = 1 → upper_middle_grade
INSERT INTO user_preferences (user_id, ai_consent, ai_consent_date, voice_consent, voice_consent_date, birth_month, birth_year, is_minor, name_confirmed)
VALUES ('<profile_d_user_id>', true, now(), true, now(), 1, 2012, true, true);
```

**CC Note:** Use `supabaseAdmin.auth.admin.createUser()` to create auth accounts with emails like `smoke-test-a@mythweaver.app`, etc. Capture each user's UUID, then insert the user_preferences rows above with the real UUIDs.

---

## The 4 Test Profiles

### Profile A — "Luna" (Middle Grade Fantasy)

**Target systems:** Character ledger with large cast, callback utilization, age-appropriate prose
**Reading level:** middle_grade (age 12)
**Discovery tolerance:** 0.2 (low — wants familiar tropes)

```json
{
  "transcript": "Luna is 12 years old. She loves fantasy books, especially ones with dragons and magic schools. Her favorite books are Harry Potter and Wings of Fire. She likes brave female protagonists who discover they have special powers. She doesn't like scary or sad endings. She reads pretty fast and likes action-packed chapters.",
  "sessionId": "smoke-test-a-session",
  "preferences": {
    "name": "Luna",
    "ageRange": "10-12",
    "favoriteGenres": ["fantasy", "adventure"],
    "preferredThemes": ["friendship", "self-discovery", "magical powers", "overcoming fears"],
    "mood": "exciting and hopeful",
    "dislikedElements": ["horror", "sad endings", "excessive violence"],
    "characterTypes": ["brave girl protagonist", "loyal sidekick", "wise mentor", "dragon companion"],
    "emotionalDrivers": ["wonder", "courage", "belonging"],
    "belovedStories": ["Harry Potter", "Wings of Fire", "Percy Jackson"],
    "readingMotivation": "escape into magical worlds",
    "discoveryTolerance": 0.2,
    "pacePreference": "fast",
    "readingLevel": "middle_grade"
  }
}
```

**Why this profile tests well:** Large character cast request (4 types) stresses the character ledger. Low discovery tolerance means premises should stick close to familiar fantasy tropes. Middle grade reading level tests age-appropriate prose filtering.

---

### Profile B — "Margaret" (Literary Adult)

**Target systems:** Voice review (distinctive adult prose), quality review (literary standards), adaptive preferences
**Reading level:** adult (age 58)
**Discovery tolerance:** 0.7 (open to surprises)

```json
{
  "transcript": "Margaret is 58. She reads literary fiction primarily — she loves Marilynne Robinson, Donna Tartt, Anthony Doerr. She wants a story that's contemplative, with rich interior lives and beautiful prose. She prefers slow-burn character development over plot twists. She dislikes anything that feels young adult or formulaic. Her ideal story would be a multigenerational family saga set in a specific place with deep sense of landscape.",
  "sessionId": "smoke-test-b-session",
  "preferences": {
    "name": "Margaret",
    "ageRange": "55-65",
    "favoriteGenres": ["literary fiction", "family saga"],
    "preferredThemes": ["memory", "loss", "resilience", "sense of place", "intergenerational bonds"],
    "mood": "contemplative and lyrical",
    "dislikedElements": ["formulaic plots", "young adult tone", "excessive action", "happy endings that feel unearned"],
    "characterTypes": ["complex matriarch", "prodigal child returning", "quiet observer"],
    "emotionalDrivers": ["nostalgia", "bittersweet recognition", "beauty in ordinary moments"],
    "belovedStories": ["Gilead", "The Secret History", "All the Light We Cannot See"],
    "readingMotivation": "find language that makes me feel something true",
    "discoveryTolerance": 0.7,
    "pacePreference": "slow",
    "readingLevel": "adult"
  }
}
```

**Why this profile tests well:** Literary prose demands high voice authenticity scores. Slow pacing preference tests whether the system respects reader pace. "Formulaic" in dislikes tests whether premises avoid obvious tropes. This profile will give CRITICAL feedback at checkpoints to test course corrections.

---

### Profile C — "Kai" (Genre-Hopping Teen)

**Target systems:** High discovery tolerance, mixed feedback handling, genre flexibility
**Reading level:** young_adult (age 16)
**Discovery tolerance:** 0.9 (loves surprises)

```json
{
  "transcript": "Kai is 16 and reads everything — sci-fi, romance, horror, fantasy, whatever looks interesting. They loved The Hunger Games but also loved heartstopper. They want something that mixes genres, like maybe sci-fi romance or fantasy horror. They get bored easily so the story needs to keep surprising them. They like morally gray characters and plot twists.",
  "sessionId": "smoke-test-c-session",
  "preferences": {
    "name": "Kai",
    "ageRange": "15-17",
    "favoriteGenres": ["science fiction", "romance", "fantasy", "horror"],
    "preferredThemes": ["moral ambiguity", "unexpected alliances", "identity", "rebellion"],
    "mood": "intense and unpredictable",
    "dislikedElements": ["predictable plots", "purely good protagonists", "slow beginnings"],
    "characterTypes": ["morally gray protagonist", "unexpected ally", "charming antagonist"],
    "emotionalDrivers": ["surprise", "tension", "romantic chemistry"],
    "belovedStories": ["The Hunger Games", "Heartstopper", "Six of Crows"],
    "readingMotivation": "be surprised and feel intense emotions",
    "discoveryTolerance": 0.9,
    "pacePreference": "fast",
    "readingLevel": "young_adult"
  }
}
```

**Why this profile tests well:** High discovery tolerance should produce premises that push genre boundaries. Mixed genres test the bible/arc system's ability to blend. This profile will give MIXED feedback at checkpoints (some positive, some critical) to test nuanced course corrections.

---

### Profile D — "Tyler" (Reluctant Reader)

**Target systems:** Thin preferences handling, short/accessible prose, minimal character complexity
**Reading level:** upper_middle_grade (age 14)
**Discovery tolerance:** 0.5 (default)

```json
{
  "transcript": "Tyler is 14. He doesn't really read much. He liked the Diary of a Wimpy Kid books when he was younger. He plays a lot of video games, mostly Fortnite and Minecraft. If a story is too long or too complicated he'll stop reading. He doesn't know what kind of story he wants.",
  "sessionId": "smoke-test-d-session",
  "preferences": {
    "name": "Tyler",
    "ageRange": "13-15",
    "favoriteGenres": ["humor", "adventure"],
    "preferredThemes": ["gaming", "survival", "friendship"],
    "mood": "fun and easy",
    "dislikedElements": ["long descriptions", "complicated plots", "romance"],
    "characterTypes": ["funny protagonist"],
    "emotionalDrivers": ["fun", "achievement"],
    "belovedStories": ["Diary of a Wimpy Kid"],
    "readingMotivation": "not sure, maybe if it was like a game",
    "discoveryTolerance": 0.5,
    "pacePreference": "fast",
    "readingLevel": "upper_middle_grade"
  }
}
```

**Why this profile tests well:** DELIBERATELY THIN preferences — only 1 character type, minimal emotional drivers, vague motivation. Tests whether the generation system produces viable stories without rich input. Should produce shorter, punchier chapters. This profile will give ALL NEGATIVE feedback at checkpoints to test maximum course correction.

---

## Execution Flow

All 4 profiles follow the same pipeline. Run them in parallel (separate auth tokens).

### STEP 1: Process Preferences

```
POST /onboarding/process-transcript
Authorization: Bearer <user_token>
Body: <profile payload above>
```

**Expected response:** `{ success: true }`

**Database verification after Step 1:**
```sql
SELECT user_id, preferences->>'name' as name, reading_level, discovery_tolerance,
       preferences->>'favoriteGenres' as genres, preferences->>'pacePreference' as pace
FROM user_preferences
WHERE user_id IN ('<a_id>', '<b_id>', '<c_id>', '<d_id>');
```

Confirm reading_level matches expectations: middle_grade, adult, young_adult, upper_middle_grade.

---

### STEP 2: Generate Premises

```
POST /onboarding/generate-premises
Authorization: Bearer <user_token>
Body: {} (empty — uses stored preferences)
```

**Expected response:** `{ success: true, premises: [...], premisesId: "uuid" }`

**Database verification after Step 2:**
```sql
SELECT id, user_id, created_at,
       premises->0->>'title' as premise_1_title,
       premises->1->>'title' as premise_2_title,
       premises->2->>'title' as premise_3_title
FROM premises
WHERE user_id IN ('<a_id>', '<b_id>', '<c_id>', '<d_id>')
ORDER BY created_at DESC;
```

---

## ⛳ GATE 1: Premise Quality Review

**STOP HERE. Do not proceed until Steven and Max have reviewed.**

For each profile, evaluate:

| Criterion | Pass | Fail |
|-----------|------|------|
| Genre alignment | Premises match requested genres | Premises ignore genre preferences |
| Age appropriateness | Language/themes match reading level | Adult themes for kids, or patronizing for adults |
| Discovery tolerance | Low tolerance → familiar tropes; High tolerance → creative twists | Opposite of what was requested |
| Disliked elements | None of the disliked elements appear | Premises contain disliked elements |
| Premise count | Exactly 3 premises returned | Fewer or more than 3 |
| Distinctiveness | 3 premises feel meaningfully different | All 3 are variations of the same idea |

**Profile-specific checks:**

- **Luna (A):** Should see classic fantasy premises (magic school, dragon quest, chosen one). Should NOT see horror, dystopia, or mature themes.
- **Margaret (B):** Should see literary/family saga premises with specific settings. Should NOT see genre fiction tropes, YA tone, or action-heavy plots.
- **Kai (C):** Should see genre-blending premises (sci-fi romance, fantasy horror). Should NOT see predictable single-genre premises.
- **Tyler (D):** Should see accessible, game-inspired or humor-driven premises. Should NOT see complex multi-threaded narratives or dense world-building.

**Decision:** Select premise 1 for all profiles (consistent testing). If premise 1 is clearly broken for a profile, note it and select the best alternative.

---

### STEP 3: Select Premise → Trigger Story Generation

```
POST /story/select-premise
Authorization: Bearer <user_token>
Body: { "premiseId": "<premises_id>" }
```

**Note:** The `premiseId` here is the ID from the `premises` table row, NOT an individual premise. The first premise in the array is selected by default.

**Expected response:** `{ success: true, story: { id, title, status: "generating", generation_progress: {...} } }`

This triggers async generation of: story bible → arc outline → chapters 1-3.

**Poll for completion:**
```
GET /story/generation-status/<storyId>
Authorization: Bearer <user_token>
```

Poll every 15 seconds. Expected progression:
1. `current_step: "generating_bible"` (30-60s)
2. `current_step: "generating_arc"` (30-60s)
3. `current_step: "generating_chapter_1"` (60-90s)
4. `current_step: "generating_chapter_2"` (60-90s)
5. `current_step: "generating_chapter_3"` (60-90s)
6. `current_step: "awaiting_chapter_2_feedback"` — **DONE**

**Timeout:** If any story hasn't reached `awaiting_chapter_2_feedback` within 10 minutes, flag it.

**Database verification after Step 3:**
```sql
-- Story bibles created
SELECT story_id, character_count, theme_count
FROM story_bibles
WHERE story_id IN (SELECT id FROM stories WHERE user_id IN ('<a_id>', '<b_id>', '<c_id>', '<d_id>'));

-- Arc outlines created
SELECT story_id, arc_number, chapter_count
FROM story_arcs
WHERE story_id IN (SELECT id FROM stories WHERE user_id IN ('<a_id>', '<b_id>', '<c_id>', '<d_id>'));

-- Chapters 1-3 generated
SELECT s.title, c.chapter_number, c.word_count, c.quality_score,
       c.quality_review->'criteria_scores'->>'show_dont_tell' as show_dont_tell,
       c.quality_review->'criteria_scores'->>'dialogue_quality' as dialogue_quality,
       c.quality_review->'criteria_scores'->>'pacing_engagement' as pacing_engagement,
       c.quality_review->'criteria_scores'->>'age_appropriateness' as age_appropriate,
       c.quality_review->'criteria_scores'->>'character_consistency' as char_consistency,
       c.quality_review->'criteria_scores'->>'prose_quality' as prose_quality
FROM chapters c
JOIN stories s ON c.story_id = s.id
WHERE s.user_id IN ('<a_id>', '<b_id>', '<c_id>', '<d_id>')
ORDER BY s.title, c.chapter_number;

-- Character ledger entries created
SELECT s.title, cle.chapter_number, cle.characters_tracked,
       jsonb_array_length(cle.callback_bank) as callback_count
FROM character_ledger_entries cle
JOIN stories s ON cle.story_id = s.id
WHERE s.user_id IN ('<a_id>', '<b_id>', '<c_id>', '<d_id>')
ORDER BY s.title, cle.chapter_number;

-- Voice reviews created
SELECT s.title, cvr.chapter_number, cvr.characters_reviewed,
       cvr.review_data->'summary'->>'overall_authenticity' as authenticity,
       cvr.revision_applied
FROM character_voice_reviews cvr
JOIN stories s ON cvr.story_id = s.id
WHERE s.user_id IN ('<a_id>', '<b_id>', '<c_id>', '<d_id>')
ORDER BY s.title, cvr.chapter_number;

-- Generation config (feature flags all ON by default)
SELECT title, generation_config
FROM stories
WHERE user_id IN ('<a_id>', '<b_id>', '<c_id>', '<d_id>');

-- Cover images generated (name_confirmed = true, so covers should exist)
SELECT title, cover_image_url, genre
FROM stories
WHERE user_id IN ('<a_id>', '<b_id>', '<c_id>', '<d_id>');

-- API costs so far
SELECT s.title, ac.operation, SUM(ac.cost) as total_cost, COUNT(*) as call_count
FROM api_costs ac
JOIN stories s ON ac.story_id = s.id
WHERE s.user_id IN ('<a_id>', '<b_id>', '<c_id>', '<d_id>')
GROUP BY s.title, ac.operation
ORDER BY s.title, ac.operation;
```

---

## ⛳ GATE 2: Initial Generation Quality Review

**STOP HERE. Do not proceed until reviewed.**

For each profile, evaluate chapters 1-3:

| Criterion | Pass | Fail |
|-----------|------|------|
| Quality scores | Average >= 7.0 across all dimensions | Any dimension consistently below 6.0 |
| Word count | Appropriate for reading level (middle_grade: 1500-3000, adult: 2500-5000, YA: 2000-4000) | Way outside range |
| Age appropriateness | Score >= 8.0 for minor profiles (A, C, D) | Below 7.0 for any minor |
| Character ledger | Entries exist for chapters 1-3, tracking named characters | Missing entries |
| Voice review | Reviews exist, authenticity >= 0.7 | Missing or authenticity below 0.5 |
| Prose quality | Matches requested mood/tone | Completely wrong voice |
| Chapter progression | Story advances logically ch1→ch2→ch3 | Repetitive or disconnected |
| Cover generated | `cover_image_url` exists and is a valid URL | NULL or missing |
| Cover variety | Covers visually match genre/tone of each story | All covers look the same or wrong genre |

**Profile-specific checks:**

- **Luna (A):** Chapters should feel like a middle grade fantasy novel. Dragon/magic elements present. No mature language. Cover should feel whimsical/fantasy.
- **Margaret (B):** Prose should be literary and contemplative. Rich descriptions. Slow, character-driven pacing. Cover should feel literary/elegant.
- **Kai (C):** Should see genre-blending elements. Morally gray characters introduced. Pacing should feel fast. Cover should feel bold/genre-bending.
- **Tyler (D):** Shorter chapters. Simple language. Game/humor elements. Should NOT feel like homework. Cover should feel fun/game-inspired.

**Also verify:**
- `generation_config` on each story shows all 4 flags as true (default behavior)
- No error events in `error_events` table for these stories
- **Include the 4 cover image URLs in the gate report** so we can visually inspect them

---

### STEP 4: Checkpoint 1 Feedback (after chapter 2)

Submit dimension-based feedback. Each profile gives DIFFERENT feedback to test course corrections:

**Profile A (Luna) — All Positive:**
```
POST /feedback/checkpoint
Authorization: Bearer <profile_a_token>
Body: {
  "storyId": "<a_story_id>",
  "checkpoint": "chapter_2",
  "pacing": "hooked",
  "tone": "right",
  "character": "love"
}
```

**Profile B (Margaret) — Critical on Pacing:**
```
POST /feedback/checkpoint
Authorization: Bearer <profile_b_token>
Body: {
  "storyId": "<b_story_id>",
  "checkpoint": "chapter_2",
  "pacing": "fast",
  "tone": "right",
  "character": "warming"
}
```
Margaret wants SLOWER pacing. "fast" means it's going too fast for her. Course corrections should slow things down.

**Profile C (Kai) — Mixed:**
```
POST /feedback/checkpoint
Authorization: Bearer <profile_c_token>
Body: {
  "storyId": "<c_story_id>",
  "checkpoint": "chapter_2",
  "pacing": "hooked",
  "tone": "serious",
  "character": "warming"
}
```
Kai wants a lighter tone but loves the pacing and is warming to characters.

**Profile D (Tyler) — All Negative:**
```
POST /feedback/checkpoint
Authorization: Bearer <profile_d_token>
Body: {
  "storyId": "<d_story_id>",
  "checkpoint": "chapter_2",
  "pacing": "slow",
  "tone": "serious",
  "character": "detached"
}
```
Tyler thinks it's too slow, too serious, and doesn't care about the characters. Maximum course correction pressure.

**Expected response for all:** `{ success: true, feedback: {...}, generatingChapters: [4,5,6], courseCorrections: {...} }`

**Poll for chapters 4-6 completion:**
```
GET /story/generation-status/<storyId>
```
Wait until `current_step: "awaiting_chapter_5_feedback"`.

**Database verification after Step 4:**
```sql
-- Feedback stored correctly
SELECT s.title, sf.checkpoint, sf.pacing_feedback, sf.tone_feedback, sf.character_feedback,
       sf.follow_up_action
FROM story_feedback sf
JOIN stories s ON sf.story_id = s.id
WHERE s.user_id IN ('<a_id>', '<b_id>', '<c_id>', '<d_id>')
ORDER BY s.title, sf.checkpoint;

-- Course corrections generated
-- Check chapters 4-6 were generated with course corrections applied
-- Look at chapter quality scores for chapters 4-6 vs 1-3
SELECT s.title, c.chapter_number, c.word_count, c.quality_score
FROM chapters c
JOIN stories s ON c.story_id = s.id
WHERE s.user_id IN ('<a_id>', '<b_id>', '<c_id>', '<d_id>')
AND c.chapter_number BETWEEN 4 AND 6
ORDER BY s.title, c.chapter_number;
```

---

## ⛳ GATE 3: Course Correction Effectiveness

**STOP HERE. Do not proceed until reviewed.**

| Criterion | Pass | Fail |
|-----------|------|------|
| Feedback stored | All 4 feedback rows exist with correct dimension values | Missing or wrong values |
| Ch 4-6 generated | All profiles have chapters 4-6 | Generation failed or stuck |
| Course correction signal | Chapters 4-6 show influence from feedback | No discernible change |

**Profile-specific course correction checks:**

- **Luna (A):** Positive feedback → chapters 4-6 should maintain same quality/tone. No dramatic shifts.
- **Margaret (B):** "fast" pacing feedback → chapters 4-6 should have MORE description, slower scene development, deeper interior monologue. Word count per chapter should increase or stay stable.
- **Kai (C):** "serious" tone feedback → chapters 4-6 should lighten up, more humor or levity. Character "warming" → continue developing relationships.
- **Tyler (D):** All negative → chapters 4-6 should show DRAMATIC shifts: faster pacing, lighter tone, more engaging character moments. This is the hardest test — can the system rescue a struggling reader?

**Compare chapter metrics:**
```sql
-- Side-by-side: chapters 1-3 vs 4-6 per profile
SELECT s.title,
  CASE WHEN c.chapter_number <= 3 THEN 'batch_1' ELSE 'batch_2' END as batch,
  AVG(c.word_count) as avg_words,
  AVG(c.quality_score) as avg_quality,
  AVG((c.quality_review->'criteria_scores'->>'pacing_engagement')::numeric) as avg_pacing
FROM chapters c
JOIN stories s ON c.story_id = s.id
WHERE s.user_id IN ('<a_id>', '<b_id>', '<c_id>', '<d_id>')
AND c.chapter_number <= 6
GROUP BY s.title, CASE WHEN c.chapter_number <= 3 THEN 'batch_1' ELSE 'batch_2' END
ORDER BY s.title, batch;
```

---

### STEP 5: Checkpoint 2 Feedback (after chapter 5)

**Profile A (Luna) — Still Positive:**
```json
{ "storyId": "<a>", "checkpoint": "chapter_5", "pacing": "hooked", "tone": "right", "character": "love" }
```

**Profile B (Margaret) — Still Wants Slower:**
```json
{ "storyId": "<b>", "checkpoint": "chapter_5", "pacing": "fast", "tone": "right", "character": "love" }
```
Margaret is now loving the characters but still wants slower pacing. Tests persistent feedback.

**Profile C (Kai) — Flips to Positive:**
```json
{ "storyId": "<c>", "checkpoint": "chapter_5", "pacing": "hooked", "tone": "right", "character": "love" }
```
The course corrections worked for Kai. All positive now.

**Profile D (Tyler) — Still Critical (but softening):**
```json
{ "storyId": "<d>", "checkpoint": "chapter_5", "pacing": "hooked", "tone": "serious", "character": "warming" }
```
Tyler likes the pacing now (correction worked!) but still finds tone too serious and is only warming to characters.

Poll until `awaiting_chapter_8_feedback`. Same verification queries as Step 4 for chapters 7-9.

---

### STEP 6: Checkpoint 3 Feedback (after chapter 8)

**Profile A (Luna):** `{ "pacing": "hooked", "tone": "right", "character": "love" }`
**Profile B (Margaret):** `{ "pacing": "right", "tone": "right", "character": "love" }` — she's finally happy with pacing
**Profile C (Kai):** `{ "pacing": "hooked", "tone": "right", "character": "love" }`
**Profile D (Tyler):** `{ "pacing": "hooked", "tone": "right", "character": "love" }` — all corrections have landed

Poll until `chapter_12_complete`.

---

## ⛳ GATE 4: Full Story Quality Review

**STOP HERE. This is the big one.**

```sql
-- Complete quality scorecard across all 12 chapters per profile
SELECT s.title, s.status,
  COUNT(c.id) as chapter_count,
  AVG(c.quality_score) as avg_quality,
  MIN(c.quality_score) as min_quality,
  MAX(c.quality_score) as max_quality,
  AVG(c.word_count) as avg_words,
  SUM(c.word_count) as total_words
FROM chapters c
JOIN stories s ON c.story_id = s.id
WHERE s.user_id IN ('<a_id>', '<b_id>', '<c_id>', '<d_id>')
GROUP BY s.title, s.status
ORDER BY s.title;

-- Quality trend per story (should see improvement after course corrections)
SELECT s.title, c.chapter_number, c.quality_score, c.word_count,
       c.quality_review->'criteria_scores'->>'pacing_engagement' as pacing,
       c.quality_review->'criteria_scores'->>'prose_quality' as prose
FROM chapters c
JOIN stories s ON c.story_id = s.id
WHERE s.user_id IN ('<a_id>', '<b_id>', '<c_id>', '<d_id>')
ORDER BY s.title, c.chapter_number;

-- Character ledger completeness
SELECT s.title, COUNT(cle.id) as ledger_entries,
       AVG(cle.characters_tracked) as avg_chars_tracked,
       AVG(jsonb_array_length(cle.callback_bank)) as avg_callbacks
FROM character_ledger_entries cle
JOIN stories s ON cle.story_id = s.id
WHERE s.user_id IN ('<a_id>', '<b_id>', '<c_id>', '<d_id>')
GROUP BY s.title;

-- Voice review completeness
SELECT s.title, COUNT(cvr.id) as voice_reviews,
       AVG((cvr.review_data->'summary'->>'overall_authenticity')::numeric) as avg_authenticity,
       SUM(CASE WHEN cvr.revision_applied THEN 1 ELSE 0 END) as revisions_applied
FROM character_voice_reviews cvr
JOIN stories s ON cvr.story_id = s.id
WHERE s.user_id IN ('<a_id>', '<b_id>', '<c_id>', '<d_id>')
GROUP BY s.title;

-- Total cost per story
SELECT s.title, SUM(ac.cost) as total_cost,
       SUM(ac.cost) / COUNT(DISTINCT c.id) as cost_per_chapter
FROM api_costs ac
JOIN stories s ON ac.story_id = s.id
JOIN chapters c ON c.story_id = s.id
WHERE s.user_id IN ('<a_id>', '<b_id>', '<c_id>', '<d_id>')
GROUP BY s.title;

-- Run QIS dashboard for these stories
-- Call GET /admin/quality/dashboard with these story IDs
```

**Pass criteria for Gate 4:**

| Criterion | Pass | Fail |
|-----------|------|------|
| Chapter count | All 4 stories have exactly 12 chapters | Any story has fewer than 12 |
| Quality scores | Fleet average >= 7.0 | Fleet average below 6.5 |
| No quality collapse | No chapter scores below 5.0 | Any chapter below 5.0 |
| Voice reviews | All chapters have voice reviews | Missing for any chapter |
| Character ledger | All chapters have ledger entries | Missing for any chapter |
| Course correction visible | Profiles B & D show measurable quality changes after feedback | No discernible difference |
| Cost reasonable | Cost per chapter < $1.50 | Cost per chapter > $3.00 |

---

### STEP 7: Completion Interviews

All 4 profiles complete their stories. Profiles A and C will signal sequel interest. Profiles B and D will not.

**Profile A (Luna) — Wants a Sequel:**
```
POST /feedback/completion-interview
Authorization: Bearer <profile_a_token>
Body: {
  "storyId": "<a_story_id>",
  "transcript": "Luna absolutely loved the story! Her favorite part was the dragon bonding scene and she wants to know what happens next. She's especially curious about the side character who betrayed the group — she thinks there's more to that story.",
  "sessionId": "smoke-test-a-completion",
  "preferences": {
    "highlights": ["dragon bonding", "friendship themes", "magic system"],
    "lowlights": [],
    "characterConnections": "deeply connected to protagonist and dragon",
    "sequelDesires": "wants to continue the adventure, explore betrayal subplot",
    "satisfactionSignal": "satisfied",
    "preferenceUpdates": "none"
  }
}
```

**Profile B (Margaret) — Satisfied, No Sequel:**
```
POST /feedback/completion-interview
Body: {
  "storyId": "<b_story_id>",
  "transcript": "Margaret found the story beautifully written once the pacing settled. The family dynamics were compelling. She doesn't need a sequel — the ending felt complete. She'd prefer a completely new story next time, perhaps historical fiction.",
  "sessionId": "smoke-test-b-completion",
  "preferences": {
    "highlights": ["prose quality", "family dynamics", "sense of place"],
    "lowlights": ["early pacing was too fast"],
    "characterConnections": "connected to the matriarch character",
    "sequelDesires": "none — prefers a fresh story",
    "satisfactionSignal": "satisfied",
    "preferenceUpdates": "interested in historical fiction next"
  }
}
```

**Profile C (Kai) — Wants a Sequel:**
```
POST /feedback/completion-interview
Body: {
  "storyId": "<c_story_id>",
  "transcript": "Kai thought it was really good, especially after the tone shift mid-book. They want a sequel but with even more genre-bending — what if the sequel went full sci-fi while keeping the fantasy characters?",
  "sessionId": "smoke-test-c-completion",
  "preferences": {
    "highlights": ["genre mixing", "plot twists", "character chemistry"],
    "lowlights": ["first few chapters were too serious"],
    "characterConnections": "loved the morally gray protagonist",
    "sequelDesires": "sequel with more sci-fi elements",
    "satisfactionSignal": "satisfied",
    "preferenceUpdates": "lean more into sci-fi"
  }
}
```

**Profile D (Tyler) — Not Satisfied:**
```
POST /feedback/completion-interview
Body: {
  "storyId": "<d_story_id>",
  "transcript": "Tyler said it was okay. He liked the later chapters better than the beginning. He's not sure he wants another story right now but said he'd try a shorter one if it was more like a game.",
  "sessionId": "smoke-test-d-completion",
  "preferences": {
    "highlights": ["later chapters were better"],
    "lowlights": ["beginning was boring", "too much description"],
    "characterConnections": "meh",
    "sequelDesires": "maybe something shorter and more interactive",
    "satisfactionSignal": "neutral",
    "preferenceUpdates": "shorter stories, more game-like"
  }
}
```

**Database verification:**
```sql
SELECT s.title, bci.created_at,
       bci.preferences->>'satisfactionSignal' as satisfaction,
       bci.preferences->>'sequelDesires' as sequel_interest
FROM book_completion_interviews bci
JOIN stories s ON bci.story_id = s.id
WHERE s.user_id IN ('<a_id>', '<b_id>', '<c_id>', '<d_id>');
```

---

### STEP 8: Sequel Generation (Profiles A and C only)

```
POST /story/<a_story_id>/generate-sequel
Authorization: Bearer <profile_a_token>
Body: {}

POST /story/<c_story_id>/generate-sequel
Authorization: Bearer <profile_c_token>
Body: {}
```

**Expected:** New story created with `book_number: 2`, `series_id` linking to Book 1.

Poll generation status. Wait for `awaiting_chapter_2_feedback` on both sequels.

---

## ⛳ GATE 5: Sequel & Completion Review (FINAL)

```sql
-- Sequel stories created
SELECT s.title, s.book_number, s.series_id, s.parent_story_id, s.status,
       sp.current_step
FROM stories s
LEFT JOIN LATERAL (SELECT s.generation_progress->>'current_step' as current_step) sp ON true
WHERE s.user_id IN ('<a_id>', '<c_id>')
AND s.book_number = 2;

-- Sequel chapters (should have 1-3)
SELECT s.title, c.chapter_number, c.quality_score, c.word_count
FROM chapters c
JOIN stories s ON c.story_id = s.id
WHERE s.book_number = 2
AND s.user_id IN ('<a_id>', '<c_id>')
ORDER BY s.title, c.chapter_number;

-- Verify sequel bible references Book 1 characters/events
SELECT s.title, sb.id
FROM story_bibles sb
JOIN stories s ON sb.story_id = s.id
WHERE s.book_number = 2
AND s.user_id IN ('<a_id>', '<c_id>');
```

**Pass criteria:**

| Criterion | Pass | Fail |
|-----------|------|------|
| Sequel created | Both sequels have story records with book_number=2 | Missing |
| Series linked | series_id matches between Book 1 and Book 2 | No link |
| Chapters generating | At least chapters 1-3 of sequel exist | Generation failed |
| Continuity | Sequel references Book 1 characters and events | Completely disconnected |

---

## Test Data Retention

**DO NOT delete test users, stories, or any generated data after testing.** These accounts (Luna, Margaret, Kai, Tyler) and their full story pipelines are valuable for:

- Future regression testing against the same profiles
- Demonstrating the system to investors/partners
- Debugging specific pipeline stages without re-running generation
- Testing new features (e.g., library UI, reading progress) against real data

Test user emails: `smoke-test-a@mythweaver.app` through `smoke-test-d@mythweaver.app`

---

## Quick Reference: CC Execution Prompt

Give CC this prompt to execute the test:

> Run the Generation Pipeline Smoke Test defined in `NeverendingStory/GENERATION_PIPELINE_SMOKE_TEST.md`. Execute each step exactly as written. At each GATE (marked with ⛳), STOP and output all verification query results plus your assessment against the evaluation criteria. Do not proceed past a gate until I tell you to continue. Create all 4 test users first, then run all 4 profiles in parallel through each step. Use the Supabase MCP for database operations and make HTTP calls to the live Railway API at the production URL. Do NOT delete any test data — keep all accounts and stories for future use.
>
> **TIMING NOTE:** Story generation (bible → arc → chapters 1-3) takes ~15-20 minutes per story. Set your polling timeout to at least 20 minutes per story. Do not flag a timeout until 25 minutes have passed. This is normal — the pipeline calls Claude API multiple times sequentially.
>
> **COVER IMAGES:** Each story should generate a cover image (cover_image_url on the stories table). Include these URLs in the Gate 2 report so we can visually compare them across profiles.
