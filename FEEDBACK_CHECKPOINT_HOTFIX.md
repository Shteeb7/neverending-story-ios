# Feedback Checkpoint Hotfix — PRODUCTION BUG

## The Bug

`POST /feedback/checkpoint` returns 500 for ALL checkpoint feedback submissions with:
```
null value in column "response" of relation "story_feedback" violates not-null constraint
```

This causes a cascading failure: feedback never saves → GET /feedback/status returns `hasFeedback: false` → the app shows the checkpoint interview again → user submits → fails again → **infinite loop**.

## Root Cause

In `neverending-story-api/src/routes/feedback.js` line 109:
```javascript
response: response || null, // Keep for backward compatibility
```

The new dimension-based checkpoint feedback (pacing, tone, character) does NOT include a `response` field in the POST body. So `response` is `undefined`, which evaluates to `null`. But the `story_feedback` table's `response` column has a `NOT NULL` constraint — so the INSERT fails.

## Fix — Two Parts (Belt and Suspenders)

### Part 1: Database Migration

The `response` column was designed for the old format where users typed a text response. The new Adaptive Reading Engine format uses structured dimension fields (pacing_feedback, tone_feedback, character_feedback) instead. The column should allow NULL.

Apply this migration via Supabase MCP `apply_migration`:

```sql
ALTER TABLE story_feedback ALTER COLUMN response DROP NOT NULL;
```

That's the entire migration. One line.

### Part 2: Code Safety Net

In `neverending-story-api/src/routes/feedback.js`, change line 109 from:

```javascript
response: response || null, // Keep for backward compatibility
```

To:

```javascript
response: response || (hasDimensions ? 'dimension_feedback' : null), // Default for new format
```

This ensures even if the migration hasn't been applied yet, the code provides a non-null default value when using the new dimension-based format. The `hasDimensions` variable is already defined on line 84.

### Part 3: No Other Changes

Do NOT change anything else in feedback.js. The rest of the file is correct — the checkpoint normalization, batch generation triggering, course corrections, status endpoint, and completion-interview endpoint are all fine.

## Files to Modify

| File | Action |
|------|--------|
| Database | Migration: `ALTER TABLE story_feedback ALTER COLUMN response DROP NOT NULL` |
| `neverending-story-api/src/routes/feedback.js` | Change line 109 only |

## Verification

1. Apply the migration and confirm the column is now nullable:
   ```sql
   SELECT column_name, is_nullable FROM information_schema.columns
   WHERE table_name = 'story_feedback' AND column_name = 'response';
   ```
   Should return `is_nullable = YES`.

2. Verify the code change compiles (no syntax errors):
   ```
   cd neverending-story-api && npm test
   ```

3. The fix resolves BOTH reported bugs:
   - Bug 1: Checkpoint feedback 500 error → fixed, INSERT succeeds with nullable response
   - Bug 2: Infinite re-interview loop → fixed, feedback saves → status returns hasFeedback: true → checkpoint doesn't re-trigger

## What NOT to Do

1. Do NOT add a DEFAULT to the column — NULL is correct for new-format rows
2. Do NOT change the upsert conflict key or any other query logic
3. Do NOT modify any other endpoints
4. Do NOT backfill existing data — there are no NULL response rows (they all failed to insert)
