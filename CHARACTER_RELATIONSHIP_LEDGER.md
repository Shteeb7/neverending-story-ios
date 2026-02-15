# Character Relationship Ledger
## Mythweaver — Deep Character Continuity Through Structured Memory

**Date Created:** February 15, 2026
**Status:** ✅ TESTED & PRODUCTION READY — Phases 1-3 complete (Feb 15, 2026). Integration tests: 8/8 passing.
**Goal:** Give the generation AI persistent memory of how characters experience the story — their evolving relationships, private knowledge, emotional states, inside jokes, and unresolved tensions — so that character dynamics deepen naturally across chapters instead of remaining static.

---

## The Problem

AI-generated fiction's biggest weakness is character relationship depth. The story bible defines who characters ARE (traits, roles, backstory), but nothing tracks what they've BEEN THROUGH together. By chapter 8, the AI has no memory of:

- The inside joke from chapter 2 that should resurface
- The quiet betrayal in chapter 4 that's been festering
- The slowly building romantic tension between two characters
- The private knowledge one character holds that others don't
- The emotional arc a character has traveled from confident to broken to rebuilding

Research confirms this is a fundamental limitation: LLMs can reliably track only 5-10 variables before degrading, and the "lost in the middle" effect means relationship details established mid-narrative get underweighted in later chapters. You can't solve this by cramming more context — you need structured, selective memory.

---

## The Solution: Three Layers

### Layer 1: Relationship Ledger Extraction (After Each Chapter — Haiku)

After every chapter is generated and saved, a lightweight AI pass extracts a structured JSON ledger entry capturing each major character's subjective experience of that chapter.

```json
{
  "chapter": 4,
  "chapter_title": "The Bridge Burns",
  "characters": {
    "Marcus": {
      "emotional_state": "suspicious, guarded — the certainty he had in chapter 1 is gone",
      "chapter_experience": "Discovered Elena lied about her origins. Confronted her but she deflected skillfully.",
      "new_knowledge": ["Elena's backstory doesn't match records", "The seal on the letter was forged"],
      "private_thoughts": "Beginning to question whether the whole mission was built on lies",
      "relationship_shifts": {
        "Elena": {
          "direction": "deteriorating",
          "detail": "Trust cracking. Suspects she's hiding something bigger. The easy banter from chapters 1-3 is strained now.",
          "unresolved": "Hasn't confronted her about the forged seal yet — saving that card"
        },
        "Kai": {
          "direction": "strengthening",
          "detail": "Growing reliance. Sees Kai as the only person being straight with him.",
          "callback_seed": "Kai's joke about 'at least the food's good' from chapter 2 — Marcus almost smiled despite everything"
        }
      }
    },
    "Elena": {
      "emotional_state": "panicking internally, composed externally — the mask is holding but barely",
      "chapter_experience": "Marcus asked questions she wasn't ready for. Deflected, but knows he's not satisfied.",
      "new_knowledge": ["Marcus is smarter than she estimated", "Her window to come clean is closing"],
      "private_thoughts": "Torn between the mission she was sent on and the genuine connection she's developed",
      "relationship_shifts": {
        "Marcus": {
          "direction": "complicated",
          "detail": "Guilt mixing with something she didn't expect to feel. Every lie costs more now.",
          "unresolved": "Knows she should tell him the truth but the stakes are too high"
        }
      }
    },
    "Kai": {
      "emotional_state": "oblivious to the tension, focused on survival",
      "chapter_experience": "Noticed Marcus and Elena being weird but chalked it up to stress.",
      "relationship_shifts": {
        "Marcus": {
          "direction": "stable",
          "detail": "Still the steady friend. Doesn't know what Marcus knows."
        }
      }
    }
  },
  "group_dynamics": {
    "overall_tension": "rising — the trio's easy camaraderie from Act I is fracturing",
    "power_balance": "shifting — Elena held information advantage, now Marcus is catching up",
    "unspoken_things": ["Marcus knows about the forgery but hasn't told anyone", "Elena's real mission", "Kai is the only one without secrets"]
  },
  "callback_bank": [
    {"source_chapter": 2, "moment": "Kai's 'at least the food's good' joke", "status": "ripe for callback", "context": "Could land as bittersweet humor in a tense moment"},
    {"source_chapter": 3, "moment": "Elena touching Marcus's arm on the bridge", "status": "recontextualized", "context": "Was it genuine or manipulation? Marcus is now questioning it"},
    {"source_chapter": 1, "moment": "Marcus's promise to his sister", "status": "dormant", "context": "Hasn't been relevant yet but should surface when stakes get personal"}
  ]
}
```

**Model:** Haiku (fast, cheap, structured extraction — no creativity needed)
**Cost:** ~$0.03 per chapter
**Time:** ~5 seconds per chapter
**When:** Immediately after chapter is saved to database, before any notification

### Layer 2: Continuity Injection (Before Next Chapter — Free)

The accumulated ledger entries (all previous chapters) are compiled into a `<character_continuity>` XML block and injected into the generation prompt for the next chapter, alongside the existing `<story_bible>`, `<learned_reader_preferences>`, and `<reader_course_correction>` blocks.

```xml
<character_continuity>
  <instruction>
    The following is a chapter-by-chapter record of how each character has EXPERIENCED
    the story from their own perspective. Use this to ensure:
    1. Characters reference shared history naturally (inside jokes, past events, callbacks)
    2. Emotional arcs are continuous (don't reset a character's emotional state between chapters)
    3. Unresolved tensions build rather than disappear
    4. Private knowledge stays private until dramatically revealed
    5. Relationship dynamics reflect accumulated experience, not just initial descriptions

    The callback_bank contains specific moments worth revisiting. Use them when they
    would land naturally — don't force them, but don't waste them either.
  </instruction>

  <chapter_4_ledger>
    [JSON ledger entry for chapter 4]
  </chapter_4_ledger>

  <chapter_3_ledger>
    [JSON ledger entry for chapter 3]
  </chapter_3_ledger>

  <!-- Most recent chapters first — primacy/recency bias works in our favor -->
</character_continuity>
```

**Key design decisions:**
- Most recent ledger entries first (exploits LLM recency bias — the AI pays most attention to the latest relationship state)
- Older entries can be summarized/compressed if context window becomes tight (chapters 1-3 summary instead of three full entries)
- The callback_bank accumulates across all chapters but items get marked "used" or "expired" as they're deployed or become irrelevant
- The `<instruction>` block tells the AI HOW to use the data, not just what it is

### Layer 3: Character Voice Review (After Chapter, Before Publishing — Sonnet)

One additional AI pass that reads the newly generated chapter wearing each character's hat. It receives the full ledger plus the new chapter and returns a structured review:

```json
{
  "chapter_reviewed": 5,
  "voice_checks": [
    {
      "character": "Marcus",
      "authenticity_score": 0.85,
      "flags": [
        {
          "type": "tone_inconsistency",
          "location": "paragraph 3, dialogue line 'Don't worry about it'",
          "issue": "Marcus has been guarded and suspicious since chapter 4. This casual dismissal doesn't match his current emotional state.",
          "suggestion": "Something more guarded: 'I'll handle it' with a look that says he's not sharing everything"
        }
      ],
      "missed_callbacks": [
        {
          "callback": "Kai's 'at least the food's good' joke from chapter 2",
          "opportunity": "The campfire scene in paragraph 7 — Kai could make a callback to this as nervous humor, and Marcus's reaction would show how much has changed"
        }
      ]
    },
    {
      "character": "Elena",
      "authenticity_score": 0.92,
      "flags": [],
      "missed_callbacks": []
    }
  ],
  "relationship_dynamics": {
    "marcus_elena_tension": "Present but could be sharper — add a moment where eye contact lingers a beat too long",
    "group_cohesion": "Correctly fracturing. Good."
  },
  "overall_assessment": "Strong chapter. Marcus needs one dialogue adjustment. One callback opportunity in the campfire scene would add depth."
}
```

**Model:** Sonnet (needs nuance to evaluate character authenticity, but not generating creative content)
**Cost:** ~$0.15 per chapter
**Time:** ~15-20 seconds per chapter
**When:** After chapter generation, before quality review (or integrated into the quality review pass)

**How suggestions are applied:** The voice review output feeds into the existing quality review / revision loop. If there are actionable flags (authenticity score < 0.8 on any character, or missed callbacks in scenes that are natural fits), the chapter gets a targeted revision pass that addresses only the flagged items. This is NOT a full rewrite — it's surgical fixes to dialogue lines and moment insertions.

---

## Context Window Management

The ledger grows with each chapter. By chapter 12, there are 11 previous ledger entries. This needs management:

### Compression Strategy

**Chapters 1-3 (distant past):** Compress into a single "Act I Summary" that captures the major relationship baselines and any callbacks that are still live.

**Chapters N-3 to N-1 (recent past):** Full ledger entries, uncompressed. These are the most relevant for continuity.

**Chapter N-1 (immediately preceding):** Full ledger entry plus the callback_bank in its entirety.

### Token Budget

Estimate per full ledger entry: ~500-800 tokens
Full uncompressed ledger at chapter 12: ~6,000-9,000 tokens
With compression strategy: ~3,000-4,000 tokens

For context: the generation prompt for a chapter is already ~8,000-12,000 tokens (bible + arc + previous chapter + preferences + course corrections). Adding 3,000-4,000 tokens for character continuity is a ~30% increase — significant but well within context window limits.

---

## Database Changes

### New Table: `character_ledger_entries`

```sql
CREATE TABLE character_ledger_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  story_id UUID NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  chapter_number INTEGER NOT NULL,
  ledger_data JSONB NOT NULL,          -- the full structured ledger JSON
  compressed_summary TEXT,              -- compressed version for older chapters
  callback_bank JSONB,                  -- accumulated callbacks with status tracking
  token_count INTEGER,                  -- approximate token count for budget management
  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(story_id, chapter_number)      -- one ledger entry per chapter per story
);

-- Index for quick lookup during generation
CREATE INDEX idx_character_ledger_story ON character_ledger_entries(story_id, chapter_number);

-- RLS: Users can read their own story ledgers
ALTER TABLE character_ledger_entries ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own story ledgers" ON character_ledger_entries
  FOR SELECT USING (
    story_id IN (SELECT id FROM stories WHERE user_id = auth.uid())
  );

COMMENT ON TABLE character_ledger_entries IS 'Stores per-chapter character relationship tracking data for continuity injection into generation prompts';
```

### New Table: `character_voice_reviews`

```sql
CREATE TABLE character_voice_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  story_id UUID NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  chapter_number INTEGER NOT NULL,
  review_data JSONB NOT NULL,           -- the full voice review JSON
  flags_count INTEGER DEFAULT 0,        -- number of authenticity flags raised
  revision_applied BOOLEAN DEFAULT FALSE, -- whether suggestions were incorporated
  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(story_id, chapter_number)
);

CREATE INDEX idx_voice_reviews_story ON character_voice_reviews(story_id, chapter_number);

ALTER TABLE character_voice_reviews ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own voice reviews" ON character_voice_reviews
  FOR SELECT USING (
    story_id IN (SELECT id FROM stories WHERE user_id = auth.uid())
  );

COMMENT ON TABLE character_voice_reviews IS 'Stores character voice authenticity reviews used for quality control during generation';
```

---

## API Changes

### Modified: `generateChapter()` in `generation.js`

After a chapter is generated and saved:
1. Call `extractCharacterLedger(storyId, chapterNumber, chapterContent)` — Haiku pass
2. Save ledger entry to `character_ledger_entries`
3. Call `reviewCharacterVoices(storyId, chapterNumber, chapterContent, ledgerHistory)` — Sonnet pass
4. Save review to `character_voice_reviews`
5. If review has actionable flags → trigger targeted revision pass
6. Continue to existing quality review

Before a chapter is generated:
1. Fetch all `character_ledger_entries` for this story
2. Apply compression strategy (summarize old entries, keep recent ones full)
3. Build `<character_continuity>` XML block
4. Inject alongside existing blocks in the generation prompt

### New Functions in `generation.js` (or new service file `character-intelligence.js`)

**`extractCharacterLedger(storyId, chapterNumber, chapterContent)`**
- Fetches story bible (for character list)
- Fetches previous ledger entries (for callback_bank continuity)
- Sends chapter content + character list + previous callbacks to Haiku
- Haiku returns structured JSON ledger entry
- Merges new callbacks into accumulated callback_bank (marks used/expired ones)
- Saves to database
- Returns the ledger entry

**`buildCharacterContinuityBlock(storyId, targetChapterNumber)`**
- Fetches all ledger entries for this story
- Applies compression strategy based on distance from target chapter
- Formats as `<character_continuity>` XML block
- Returns the block string

**`reviewCharacterVoices(storyId, chapterNumber, chapterContent, ledgerHistory)`**
- Sends chapter + full ledger history to Sonnet
- Sonnet reviews each character's voice, flags inconsistencies, identifies missed callbacks
- Returns structured review JSON
- Saves to database
- Returns flags and suggestions

**`applyVoiceRevisions(storyId, chapterNumber, chapterContent, reviewFlags)`**
- If flags are actionable (authenticity < 0.8, or natural callback opportunities)
- Sends chapter + specific flags to the generation model (Opus/Sonnet, same model that wrote it)
- Requests targeted revisions ONLY to flagged items (not a full rewrite)
- Returns revised chapter content
- Updates the chapter in database

---

## Prompt Design

### Ledger Extraction Prompt (Haiku)

```
You are extracting character relationship data from a chapter of a novel.

<story_bible>
{story bible content — character definitions}
</story_bible>

<previous_callbacks>
{accumulated callback_bank from previous chapters}
</previous_callbacks>

<chapter_content>
{the full chapter text}
</chapter_content>

Extract a structured ledger entry for this chapter. For EACH major character who appears or is referenced:

1. emotional_state — How are they feeling RIGHT NOW at the end of this chapter? Reference how this has changed from previous chapters.
2. chapter_experience — What happened TO them this chapter, from THEIR perspective (not the narrator's).
3. new_knowledge — What do they now know that they didn't before? Be specific.
4. private_thoughts — What are they thinking that they haven't said out loud?
5. relationship_shifts — For each significant relationship, note: direction (strengthening/deteriorating/complicated/stable), detail (specific to THIS chapter's events), and any unresolved tensions.

Also identify:
- group_dynamics: overall tension level, power balance shifts, unspoken things
- callback_bank updates: new moments worth calling back to later, status updates on existing callbacks (used/expired/still ripe)

Return ONLY valid JSON matching this structure:
{schema example}

IMPORTANT: Focus on SUBJECTIVE experience, not plot summary. We need to know how characters FEEL, not just what happened.
```

### Character Voice Review Prompt (Sonnet)

```
You are a character authenticity reviewer for a novel-in-progress.

<character_continuity>
{full ledger history}
</character_continuity>

<new_chapter>
{chapter to review}
</new_chapter>

Review this chapter for character authenticity. For each major character:

1. Does their dialogue match their current emotional state (per the ledger)?
2. Are there moments where a character acts inconsistently with their established arc?
3. Are there natural opportunities to callback earlier moments that were missed?
4. Do relationship dynamics feel appropriate given accumulated history?

Rate each character's authenticity 0.0-1.0. Flag specific dialogue lines or moments that feel off, with concrete suggestions for fixes. Identify callback opportunities that would add depth.

Be surgical — only flag things that would genuinely improve the chapter. A score of 0.85+ means "good, minor notes." Below 0.8 means "this needs revision."

Return ONLY valid JSON.
```

---

## Implementation Phases

### Phase 1: Ledger Extraction + Continuity Injection

- Database migration: `character_ledger_entries` table
- New function: `extractCharacterLedger()` — Haiku pass after each chapter
- New function: `buildCharacterContinuityBlock()` — compile and compress ledger for injection
- Modify `generateChapter()` to inject `<character_continuity>` block into prompt
- Modify `generateChapter()` to call ledger extraction after chapter save
- Wire into both `orchestratePreGeneration()` (chapters 1-3) and `generateBatch()` (chapters 4+)

**Priority:** This is the foundation. The ledger is the memory; injection is the delivery mechanism.

### Phase 2: Character Voice Review

- Database migration: `character_voice_reviews` table
- New function: `reviewCharacterVoices()` — Sonnet review pass
- New function: `applyVoiceRevisions()` — targeted revision pass for flagged items
- Integrate into post-generation pipeline (after ledger extraction, before/alongside quality review)
- Decision: should voice review be a gate (fail = revise) or advisory (log but don't block)?

**Priority:** This is the quality layer. Can be implemented after Phase 1 is proven.

### Phase 3: Compression and Optimization

- Implement ledger compression for older chapters (Act I summary)
- Token counting and budget management
- Callback_bank lifecycle management (mark used/expired, prune old entries)
- Performance monitoring: does the ledger actually improve quality? Compare chapters generated with vs without continuity injection.

**Priority:** Optimization. Only matters once the system is running at scale.

---

## Cost Analysis

| Component | Model | Cost/Chapter | Cost/Book (12 ch) |
|-----------|-------|-------------|-------------------|
| Ledger extraction | Haiku | ~$0.03 | ~$0.36 |
| Continuity injection | Free (prompt engineering) | $0.00 | $0.00 |
| Voice review | Sonnet | ~$0.15 | ~$1.80 |
| Targeted revisions (est. 30% of chapters) | Sonnet | ~$0.10 | ~$0.36 |
| **Total overhead** | | | **~$2.52** |

Current book generation cost: ~$6.00
New total: ~$8.52 (42% increase)

This is a meaningful cost increase. Phase 1 alone (ledger + injection, no voice review) adds only $0.36/book — a 6% increase for what could be the single biggest quality improvement. Phase 2 (voice review) can be toggled on/off or reserved for premium tier if cost is a concern.

---

## Success Metrics

How do we know this is working?

1. **Quality score improvement:** Compare weighted quality scores for chapters generated with vs without the continuity block. Target: 0.5+ point improvement on the 10-point scale.

2. **Callback utilization:** Track how many callback_bank items get naturally deployed by the AI. Target: at least 1 callback per chapter after chapter 4.

3. **Voice review pass rate:** Percentage of chapters scoring 0.85+ on character authenticity. Target: >80% without revision needed.

4. **Reader feedback correlation:** Do readers who get ledger-enhanced stories report better "character connection" scores at checkpoints? This is the ultimate signal.

5. **Revision rate:** How often does the voice review trigger a revision? Too high (>50%) means the base generation isn't using the ledger effectively. Too low (<10%) means the review isn't catching real issues.

---

*The story bible tells the AI who characters ARE. The relationship ledger tells the AI who characters have BECOME. That's the difference between reading a character sheet and reading a person.*
