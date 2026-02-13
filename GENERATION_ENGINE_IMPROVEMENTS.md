# Generation Engine Improvement Plan
## The Neverending Story - Making AI Write Better Books

**Date Created:** February 12, 2026
**Last Updated:** February 12, 2026
**Status:** Phases 1-2 COMPLETE, Phase 3 partially complete, Phases 4-5 deferred
**Goal:** Transform our generation engine from "decent" to "legitimately good" fiction

---

## Executive Summary

This plan overhauled the generation engine prompts, quality review system, model configuration, and built a preference learning engine that makes the app smarter with every book. Phases 1 through 2.4 are complete and deployed. Remaining work is A/B testing (deferred until user volume) and advanced features (genre modules, style transfer, multi-model).

---

## Current State (as of Feb 12, 2026)

### What's Built and Working

**Generation Pipeline:**
- Story bible generation with deep character psychology (internal contradictions, lies they believe, deepest fears, voice notes), antagonist sympathy (why they believe they're right, sympathetic element, point of no return), supporting character goals and relationship dynamics, and sensory location details
- 12-chapter arc outline with emotional arcs per chapter, key dialogue moments, chapter hooks, subplot tracking as objects with chapter mapping, and character growth milestones
- Chapter generation with full XML-structured prompt including 7 show-don't-tell examples, dialogue quality rules, pacing rules, 13 negative instructions, style anchoring paragraph, strict word count enforcement, and age range guidance
- Quality review with weighted rubric (show/tell 25%, dialogue 20%, pacing 20%, age 15%, character 10%, prose 10%), evidence quotes required per criterion, threshold raised to 7.5/10
- Structured JSON outputs for all generation steps
- Context from previous 3 chapters for continuity
- Dynamic age range personalization throughout pipeline
- Cost tracking per API call with correct pricing ($5/$25 per 1M tokens for Opus 4.6)
- Model configuration externalized to environment variables (CLAUDE_GENERATION_MODEL, OPENAI_REALTIME_MODEL)

**Feedback System (COMPLETE):**
- Checkpoint feedback at chapters 3, 6, and 9 (Fantastic / Great / Meh emoji responses)
- "Meh" follow-up actions: start different story, keep reading, or give voice tips
- Feedback-triggered chapter generation (positive feedback at ch3 generates 7-9, at ch6 generates 10-12)
- Only chapters 1-6 pre-generated; remaining batches gated by reader engagement
- Backend: `POST /feedback/checkpoint`, `GET /feedback/status/:storyId/:checkpoint`
- Database: `story_feedback` table with RLS

**Book Completion Voice Interview (COMPLETE):**
- AI voice interview with Prospero after chapter 12
- Extracts structured preferences: liked themes, wants_more, favorite_character, sequel interest
- Auto-triggers preference analysis in background after interview completion
- Backend: `POST /feedback/completion-interview`
- Database: `book_completion_interviews` table
- iOS: BookCompletionInterviewView.swift built and functional

**Sequel Generation (COMPLETE):**
- Book context extraction from final 3 chapters (character states, relationships, world changes, loose threads)
- Sequel bible generation with strict continuity enforcement (same protagonist, retained skills, 3-6 month gap, different conflict type)
- Series tracking infrastructure (series_id, book_number, parent_story_id on stories table)
- Backend: `POST /story/:storyId/generate-sequel`
- Database: `story_series_context` table
- iOS: SequelGenerationView.swift built

**Preference Learning Engine (COMPLETE):**
- `user_writing_preferences` table with JSONB preference fields, custom_instructions TEXT[], avoid_patterns TEXT[], confidence scoring
- `analyzeUserPreferences()` function: requires 2+ completed stories, fetches all feedback + interviews + quality scores + reading behavior, sends to Claude for pattern analysis, upserts structured preferences
- `getUserWritingPreferences()` function: simple fetch
- Automatic injection of `<learned_reader_preferences>` XML block into chapter generation prompts when confidence >= 0.5 and stories_analyzed >= 2
- Auto-triggers after every completion interview (non-blocking)
- Manual trigger: `POST /feedback/analyze-preferences`
- Query endpoint: `GET /feedback/writing-preferences`
- Database: `user_writing_preferences` table with RLS (migration 004 applied)

**Behavioral Reading Analytics (COMPLETE):**
- `reading_sessions` table tracking individual sessions per chapter with start/end timestamps, duration, max scroll progress, completion and abandonment flags
- `chapter_reading_stats` table with aggregated per-chapter metrics (total reading time, session count, max scroll, first opened, last read, completion status)
- 4 API endpoints: `POST /analytics/session/start`, `POST /analytics/session/heartbeat`, `POST /analytics/session/end`, `GET /analytics/reading-stats/:storyId`
- Full iOS lifecycle integration: sessions start on chapter open, heartbeat on scroll (piggybacks existing 2-sec debounce), end on chapter change / app background / reader dismissal
- Scene phase handling: sessions end on background, restart on foreground
- Scroll percentage (0-100) correctly calculated and sent (not raw pixel offset)
- Reading behavior data wired into preference analysis prompt (`<reading_behavior>` XML block with avg reading time, skimmed chapters, re-reads, abandoned chapters)
- Database: `reading_sessions` and `chapter_reading_stats` tables with RLS (migration 005 applied)

**Test Infrastructure:**
- `POST /test/generate-sample-chapter` endpoint: generates a chapter with hardcoded test bible/arc using the full prompt pipeline, runs quality review, returns chapter + scores + cost + timing. No database dependencies. Accepts optional genre and ageRange params.

---

## Research Findings: What Works with Claude 4.x

### Key Behavioral Shift
Claude 4.x takes instructions literally. Earlier versions inferred intent and expanded on vague requests. Now you must be explicit about everything — if you want "above and beyond" behavior, you must explicitly request it.

### Sonnet 4.5 / Opus 4.6 Fiction Strengths
- Understands subtext, emotional pacing, distinct character voices
- 200K context window (can maintain consistency across entire book)
- Excellent style mimicry when given concrete samples
- Rewards specificity — takes instructions literally
- Strong at dialogue-only scenes with distinct speaker voices (Novelcrafter testing confirmed this)

### Known Weaknesses to Prompt Around
- **Wordiness** — Will double word count if not explicitly constrained
- **Tells > Shows** — Without explicit instruction + examples, explains emotions instead of showing
- **AI tropes** — Recurring patterns (character names like "Marcus", em dash overuse, correlative constructions "Not X, but Y")
- **Follows examples too closely** — Can repeat patterns from provided examples (strength for style anchoring, weakness if examples are too narrow)
- **Melodrama** — Reactions feel over-the-top without concrete restraint examples

### Techniques That Deliver Measurable Results
1. **XML Tags for Structure** — Claude trained on these, parses perfectly
2. **Show Don't Tell with Before/After Examples** — Simply saying "show don't tell" helps, but providing concrete before/after examples produces dramatically better results
3. **Negative Instructions** — Tell it what NOT to do (avoid purple prose, avoid explaining emotions, no "Not X, but Y" constructions)
4. **Style Anchoring** — Provide 2-3 paragraphs of target prose style; model mimics effectively
5. **Sensory Language Directives** — Explicit instructions to use sight, sound, touch, smell
6. **Dialogue Rules** — Specific beats, subtext, character voice guidelines; distinct voices per character
7. **Weighted Quality Criteria** — Different aspects matter differently for fiction
8. **Explicit Word Count Enforcement** — Must be firm about limits or output balloons

### Sources
- [Novelcrafter: Testing Sonnet 4.5 for Writing](https://www.novelcrafter.com/blog/testing-sonnet-4-5-for-writing)
- [Anthropic: Claude 4.x Prompting Best Practices](https://docs.claude.com/en/docs/build-with-claude/prompt-engineering/claude-4-best-practices)
- [Skywork: Claude 4.5 Creative Writing Best Practices](https://skywork.ai/blog/claude-4-5-best-practices-creative-writing-brainstorming-ideation-2025/)
- [LessWrong: Experiments with Sonnet 4.5 Fiction](https://www.lesswrong.com/posts/SwiChH68fRERBiCHe/experiments-with-sonnet-4-5-s-fiction)
- [Every.to: Testing Claude Sonnet 4.5 for Writing](https://every.to/vibe-check/vibe-check-we-tested-claude-sonnet-4-5-for-writing-and-editing)
- [LessWrong: Creative Writing with LLMs - Prompting for Fiction](https://www.lesswrong.com/posts/D9MHrR8GrgSbXMqtB/creative-writing-with-llms-part-1-prompting-for-fiction)

---

## Completed Work

### Phase 1: Enhanced Prompts — COMPLETE

**Files modified:** `neverending-story-api/src/services/generation.js`

**1.1 Chapter Generation Prompt Overhaul**
Full XML-structured prompt with `<story_context>`, `<chapter_outline>`, `<previous_chapters>`, `<writing_craft_rules>` (show-don't-tell with 7 before/after examples, dialogue quality rules, pacing rules, 13 negative instructions), `<style_example>` (2-paragraph prose anchor), `<word_count>` (strict 2500-3500), `<target_age_range>`, and `<learned_reader_preferences>` injection block.

**1.2 Quality Review Prompt Enhancement**
Weighted rubric: Show/Tell 25%, Dialogue 20%, Pacing 20%, Age 15%, Character 10%, Prose 10%. Evidence quotes required per criterion. Priority fixes listed. Threshold raised from 7.0 to 7.5. Backward compatibility fallback for weighted_score.

**1.3 Bible Prompt Enhancement**
Added internal_contradiction, lie_they_believe, deepest_fear, voice_notes for protagonist. Added why_they_believe_theyre_right, sympathetic_element, point_of_no_return for antagonist. Supporting characters get their_own_goal and relationship_dynamic. Locations get sensory_details (sounds, smells, tactile).

**1.4 Arc Prompt Enhancement**
Added emotional_arc per chapter (reader_start/reader_end), key_dialogue_moment, chapter_hook, subplot tracking as objects with chapter mapping, character_growth_milestones.

### Phase 1.5: Model Configuration & Bug Fixes — COMPLETE

- Model strings externalized to env vars with fallback defaults
- Pricing corrected from 15/75 (Opus 4.5) to 5/25 (Opus 4.6)
- OpenAI realtime model externalized
- Startup log shows active models in Railway logs
- quality_score column changed from INTEGER to NUMERIC(4,2) (migration 004)

### Phase 2: Preference Learning Engine — COMPLETE

- `user_writing_preferences` table created (migration 004)
- `analyzeUserPreferences()`: requires 2+ completed stories, analyzes all feedback/interviews/quality/reading behavior, extracts structured preferences via Claude
- `getUserWritingPreferences()`: simple fetch
- `<learned_reader_preferences>` XML block injected into chapter prompts (gated: stories >= 2, confidence >= 0.5)
- Auto-trigger on completion interview, manual trigger endpoint, query endpoint
- New routes: `POST /feedback/analyze-preferences`, `GET /feedback/writing-preferences`

### Phase 2.4: Behavioral Reading Analytics — COMPLETE

- `reading_sessions` and `chapter_reading_stats` tables (migration 005)
- 4 API endpoints: session start, heartbeat, end, reading-stats
- Full iOS integration: ReadingStateManager session lifecycle, APIManager methods, BookReaderView lifecycle hooks (onAppear, onDisappear, scenePhase)
- Reading behavior summary wired into preference analysis prompt
- ScrollProgress bug fixed (sends 0-100 percentage, not raw pixel offset)
- first_opened preservation fix (doesn't overwrite on subsequent visits)

---

## Remaining Work

### Phase 3: A/B Testing Framework — DEFERRED

**Status:** NOT STARTED
**Priority:** LOW — premature until we have user volume
**When to build:** After 50+ active users generating stories

Would test variations of dialogue emphasis levels, pacing styles (action-dense vs. character-focused), show/tell strictness, and style example paragraphs.

### Phase 4: Advanced Features — FUTURE

- Genre-specific prompt modules (fantasy vs sci-fi vs mystery craft rules)
- Reading level adaptation (vocabulary + sentence complexity scaling)
- Multi-model ensemble (different models for different generation stages, e.g. Sonnet for speed, Opus for quality)
- Style transfer (user uploads favorite book excerpts as style anchors)

---

## Files Modified/Created (Complete List)

### API (`neverending-story-api/`)
- `src/services/generation.js` — Prompt overhaul, model config, preference learning functions, reading behavior integration
- `src/routes/feedback.js` — Preference analysis endpoints, auto-trigger on completion interview
- `src/routes/analytics.js` — NEW: 4 reading analytics endpoints
- `src/routes/test.js` — Sample chapter generation endpoint
- `src/routes/onboarding.js` — OpenAI model externalized
- `src/server.js` — Analytics route registration, startup model log
- `.env` / `.env.example` — CLAUDE_GENERATION_MODEL, OPENAI_REALTIME_MODEL
- `database/migrations/004_preferences_and_fixes.sql` — NEW: user_writing_preferences table, quality_score fix
- `database/migrations/005_reading_analytics.sql` — NEW: reading_sessions, chapter_reading_stats tables

### iOS (`NeverendingStory/`)
- `Services/ReadingStateManager.swift` — Session tracking (start, heartbeat, end, stopTracking), scrollPercentage property
- `Services/APIManager.swift` — 3 new analytics methods
- `Views/Reader/BookReaderView.swift` — Session lifecycle hooks, scenePhase handling, scrollPercentage update

---

## Cost Analysis

### Per Story Costs (12 chapters, Opus 4.6 at $5/$25 per 1M tokens)
- Premise: ~$0.08
- Bible: ~$0.48 (richer output with deep character psychology)
- Arc: ~$0.35 (more detailed with emotional arcs, subplots)
- 12 Chapters: ~12 x $1.17 = $14.04 (longer prompts + richer output)
- Quality reviews: ~12 x $0.26 = $3.12 (more detailed feedback with evidence quotes)
- Preference analysis: ~$0.15 (one-time after 2+ books, amortized)
- **Total: ~$18.22 per story**

### Cost Justification
- Quality is the only sustainable competitive advantage
- Free AI tools exist — we must be meaningfully better
- Better quality = higher retention = more stories = more revenue
- One engaged user who stays for a year pays for the increased cost many times over

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Prompts too restrictive, stifle creativity | A/B test changes gradually; keep old prompts as fallback |
| Learning system overfits to small sample | Require 2+ completed stories and confidence >= 0.5 before injection |
| User fatigue from feedback requests | Feedback is emoji-based and optional; voice interview only at book end |
| Quality regression from prompt changes | Monitor quality_score trends; test endpoint for manual review; instant rollback via env vars |
| Increased API costs | Track cost per story rigorously; consider Sonnet for specific stages |

---

## Success Metrics

### Quality (Phase 1) — NEEDS BASELINE MEASUREMENT
- Average quality_score: target 8.0+ (use test endpoint to establish baseline)
- Show/tell criterion: target 8.0+
- Dialogue criterion: target 8.0+
- Regeneration rate: target <25%

### Engagement (Phase 2+) — NEEDS USER DATA
- Chapter completion rate: target 85%+
- Return rate (finish book 1, start book 2): target 60%+
- "Fantastic" checkpoint feedback rate: target 50%+

---

**Owner:** Steven (steven.labrum@gmail.com)
**Status:** Core engine work complete. Next steps: validate quality with test endpoint, deploy, gather user data, then revisit A/B testing and genre modules.
