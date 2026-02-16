# Scroll-Based Reading Analytics — Implementation Spec

Replace wall-clock reading time with scroll-activity-based measurement. The current system calculates duration as `session_end - session_start`, which counts phone-down time, idle time, and app-backgrounded time as "reading." This spec replaces that with a scroll-velocity model that only counts time when the user is actively scrolling.

**Result:** Accurate per-user reading speed (WPM proxy), true active reading time, engagement heatmaps, and head/tail estimation. No iOS changes required — the app already sends the data we need.

---

## TASK 1: Database — `reading_heartbeats` Table

Create a new table to store individual heartbeat events instead of discarding them.

```sql
CREATE TABLE reading_heartbeats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES reading_sessions(id) ON DELETE CASCADE,
  scroll_position NUMERIC(5,2) NOT NULL,  -- 0-100%
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_heartbeats_session ON reading_heartbeats(session_id, recorded_at);

ALTER TABLE reading_heartbeats ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access to heartbeats" ON reading_heartbeats
  FOR ALL USING (true);
```

Also add computed reading columns to `reading_sessions`:

```sql
ALTER TABLE reading_sessions
  ADD COLUMN active_reading_seconds INTEGER,
  ADD COLUMN estimated_reading_speed NUMERIC(6,2),  -- scroll % per minute (proxy for WPM)
  ADD COLUMN idle_seconds INTEGER;
```

And to `chapter_reading_stats`:

```sql
ALTER TABLE chapter_reading_stats
  ADD COLUMN total_active_reading_seconds INTEGER DEFAULT 0,
  ADD COLUMN avg_reading_speed NUMERIC(6,2);
```

Apply as a single migration via Supabase MCP `apply_migration`.

---

## TASK 2: Modify Heartbeat Endpoint — Store Events

**File:** `neverending-story-api/src/routes/analytics.js`

**Current behavior (line 80-126):** The `POST /analytics/session/heartbeat` endpoint receives `{sessionId, scrollProgress}`, updates `reading_sessions.session_end` and `max_scroll_progress`, and discards the individual data point.

**New behavior:** In addition to the existing update logic, INSERT a row into `reading_heartbeats`:

```javascript
// After the existing session update (line ~117), add:
await supabaseAdmin
  .from('reading_heartbeats')
  .insert({
    session_id: sessionId,
    scroll_position: scrollProgress,
    recorded_at: new Date().toISOString()
  });
```

This is fire-and-forget — don't await or error-handle. The heartbeat endpoint must stay fast. If the insert fails, we lose one data point, which is fine.

**Do NOT change the existing session update logic.** The heartbeat insert is purely additive.

---

## TASK 3: Compute Active Reading Time on Session End

**File:** `neverending-story-api/src/routes/analytics.js`

**Modify the `POST /analytics/session/end` handler (line 132-223).** After fetching the session but before updating it, compute active reading time from the heartbeat trail.

### Algorithm: `computeActiveReadingTime(sessionId)`

Create this as a helper function in the same file (or in a new `src/services/reading-analytics.js` if you prefer separation):

```javascript
async function computeActiveReadingTime(sessionId, sessionStart) {
  // 1. Fetch all heartbeats for this session, ordered by time
  const { data: heartbeats } = await supabaseAdmin
    .from('reading_heartbeats')
    .select('scroll_position, recorded_at')
    .eq('session_id', sessionId)
    .order('recorded_at', { ascending: true });

  if (!heartbeats || heartbeats.length < 2) {
    // Not enough data — fall back to wall-clock, capped at 60s
    return {
      activeSeconds: null,  // signals "not enough data"
      idleSeconds: null,
      readingSpeed: null
    };
  }

  const IDLE_THRESHOLD_MS = 10000;  // 10 seconds with no scroll movement = idle
  let activeMs = 0;
  let idleMs = 0;
  let totalScrollDelta = 0;
  let activeScrollTime = 0;

  for (let i = 1; i < heartbeats.length; i++) {
    const prev = heartbeats[i - 1];
    const curr = heartbeats[i];
    const timeDelta = new Date(curr.recorded_at) - new Date(prev.recorded_at);
    const scrollDelta = Math.abs(curr.scroll_position - prev.scroll_position);

    if (scrollDelta > 0 && timeDelta < IDLE_THRESHOLD_MS) {
      // Active reading: scroll moved within threshold
      activeMs += timeDelta;
      totalScrollDelta += scrollDelta;
      activeScrollTime += timeDelta;
    } else if (scrollDelta === 0 && timeDelta < IDLE_THRESHOLD_MS) {
      // Paused but not idle yet (could be reading visible text)
      // Count up to 5 seconds of no-scroll as active, then idle
      const pauseCredit = Math.min(timeDelta, 5000);
      activeMs += pauseCredit;
      idleMs += (timeDelta - pauseCredit);
    } else {
      // Gap exceeds threshold — user was idle
      idleMs += timeDelta;
    }
  }

  // Reading speed: scroll % per minute of active time
  const activeMinutes = activeMs / 60000;
  const readingSpeed = activeMinutes > 0 ? totalScrollDelta / activeMinutes : null;

  // Head estimation: time from session_start to first heartbeat
  const firstHeartbeat = new Date(heartbeats[0].recorded_at);
  const headMs = firstHeartbeat - new Date(sessionStart);
  // Only count head time if reasonable (< 30s) — beyond that, they opened and walked away
  const headCredit = Math.min(Math.max(headMs, 0), 30000);

  // Tail estimation: based on reading speed, estimate time to read remaining visible content
  // Assume ~15% of chapter is visible in viewport at any time
  const tailCredit = readingSpeed ? (15 / readingSpeed) * 60000 : 10000;  // default 10s
  const cappedTail = Math.min(tailCredit, 30000);  // cap at 30s

  const totalActiveMs = activeMs + headCredit + cappedTail;

  return {
    activeSeconds: Math.round(totalActiveMs / 1000),
    idleSeconds: Math.round(idleMs / 1000),
    readingSpeed: readingSpeed ? Math.round(readingSpeed * 100) / 100 : null
  };
}
```

### Wire into session end handler

In the existing `POST /analytics/session/end` handler, after fetching the session (line ~144) and before updating it (line ~169):

```javascript
// Compute active reading time from heartbeat trail
const readingMetrics = await computeActiveReadingTime(sessionId, session.session_start);

// Use active time if available, fall back to wall-clock (existing behavior)
const activeSeconds = readingMetrics.activeSeconds;
const wallClockSeconds = Math.round((sessionEnd - sessionStart) / 1000);
const finalDuration = activeSeconds !== null ? activeSeconds : wallClockSeconds;
```

Then update the session with the new fields:

```javascript
// In the .update() call, add:
active_reading_seconds: readingMetrics.activeSeconds,
estimated_reading_speed: readingMetrics.readingSpeed,
idle_seconds: readingMetrics.idleSeconds,
reading_duration_seconds: finalDuration  // NOW uses active time, not wall-clock
```

And in the `chapter_reading_stats` upsert, use `finalDuration` instead of `durationSeconds`:

```javascript
total_reading_time_seconds: (existingStats?.total_reading_time_seconds || 0) + finalDuration,
total_active_reading_seconds: (existingStats?.total_active_reading_seconds || 0) + (readingMetrics.activeSeconds || finalDuration),
avg_reading_speed: readingMetrics.readingSpeed || existingStats?.avg_reading_speed,  // latest speed overwrites
```

### Logging

Use the existing `📖` prefix:

```javascript
console.log(`📖 Ending session: ${sessionId.slice(0, 8)}..., active=${readingMetrics.activeSeconds}s, idle=${readingMetrics.idleSeconds}s, wall=${wallClockSeconds}s, speed=${readingMetrics.readingSpeed}%/min, scroll=${newMaxScroll.toFixed(1)}%`);
```

---

## TASK 4: Admin Endpoint for Reading Analytics

**File:** `neverending-story-api/src/routes/admin.js`

Add one new endpoint:

### `GET /admin/reading-analytics`

Query params: `storyId` (optional), `userId` (optional)

Returns:
- Per-user reading speed averages (from `reading_sessions.estimated_reading_speed`)
- Active vs idle time breakdown
- Per-chapter reading time (active, not wall-clock)
- Completion rate comparison: wall-clock completion vs active-time completion

```javascript
router.get('/reading-analytics', authenticateUser, asyncHandler(async (req, res) => {
  const { storyId, userId } = req.query;

  let query = supabaseAdmin
    .from('reading_sessions')
    .select('user_id, story_id, chapter_number, reading_duration_seconds, active_reading_seconds, idle_seconds, estimated_reading_speed, max_scroll_progress, completed')
    .not('active_reading_seconds', 'is', null);

  if (storyId) query = query.eq('story_id', storyId);
  if (userId) query = query.eq('user_id', userId);

  const { data, error } = await query.order('session_start', { ascending: false }).limit(500);

  if (error) throw new Error(`Failed to fetch reading analytics: ${error.message}`);

  // Aggregate
  const byUser = {};
  for (const row of data) {
    if (!byUser[row.user_id]) byUser[row.user_id] = { sessions: [], speeds: [] };
    byUser[row.user_id].sessions.push(row);
    if (row.estimated_reading_speed) byUser[row.user_id].speeds.push(row.estimated_reading_speed);
  }

  const userSummaries = Object.entries(byUser).map(([uid, d]) => ({
    user_id: uid,
    total_active_seconds: d.sessions.reduce((s, r) => s + (r.active_reading_seconds || 0), 0),
    total_wall_seconds: d.sessions.reduce((s, r) => s + (r.reading_duration_seconds || 0), 0),
    total_idle_seconds: d.sessions.reduce((s, r) => s + (r.idle_seconds || 0), 0),
    avg_reading_speed: d.speeds.length ? d.speeds.reduce((a, b) => a + b, 0) / d.speeds.length : null,
    session_count: d.sessions.length
  }));

  res.json({
    success: true,
    analytics: {
      sessions_analyzed: data.length,
      user_summaries: userSummaries,
      fleet_avg_speed: userSummaries.filter(u => u.avg_reading_speed).reduce((s, u) => s + u.avg_reading_speed, 0) / (userSummaries.filter(u => u.avg_reading_speed).length || 1)
    }
  });
}));
```

---

## What NOT to Do

1. **Do NOT modify the iOS app.** The heartbeat mechanism in `ReadingStateManager.swift` already sends `scrollProgress` every ~2 seconds via `debouncedSave()`. No client changes needed.
2. **Do NOT remove the wall-clock `reading_duration_seconds` calculation.** Keep it as a fallback for sessions with < 2 heartbeats. The new `active_reading_seconds` field is additive.
3. **Do NOT batch-process old sessions.** Old sessions don't have heartbeat data. The new system only applies going forward.
4. **Do NOT change the heartbeat frequency on the client.** 2 seconds is fine for scroll-delta analysis.
5. **Do NOT use `.single()` for heartbeat queries.** A session can have hundreds of heartbeats.
6. **Do NOT make the heartbeat INSERT blocking.** It must be fire-and-forget to keep the endpoint fast.
7. **Do NOT store heartbeats for sessions that have already ended.** Only active sessions should accept heartbeats (the existing `session not found` guard handles this).

---

## Files Summary

| File | Action |
|------|--------|
| Database | Migration: `reading_heartbeats` table + new columns on `reading_sessions` and `chapter_reading_stats` |
| `neverending-story-api/src/routes/analytics.js` | MODIFY — heartbeat INSERT + active reading computation on session end |
| `neverending-story-api/src/routes/admin.js` | MODIFY — add `/admin/reading-analytics` endpoint |

---

## Verification

1. Server: `npm test` passes.
2. Start a reading session, scroll through a chapter, end the session. Check that `reading_heartbeats` has rows, `reading_sessions.active_reading_seconds` is populated, and `reading_sessions.active_reading_seconds < reading_sessions.reading_duration_seconds` (active should be less than or equal to wall-clock).
3. Open a chapter, wait 30 seconds without scrolling, then scroll. Verify `idle_seconds` is roughly 20-25s (30s minus the 5s pause credit and head estimation).
4. `GET /admin/reading-analytics` returns data with per-user speed averages.

---

## Future Enhancements (not in this spec)

- **Engagement heatmaps:** Aggregate scroll-speed-per-position across all readers of a chapter. Where do people slow down? Speed up? Re-read? This feeds directly into QIS for quality signal per paragraph.
- **Reading speed → WPM conversion:** Once we know chapter word counts and scroll % maps to character position, we can convert scroll speed into actual WPM per user.
- **Adaptive chapter length:** If we know a user reads at 200 WPM and prefers 10-minute sessions, we can target ~2,000 words per chapter for them.
- **Dashboard integration:** Add reading speed and active/idle breakdown to `mythweaver-dashboard.html` alongside existing reading time metrics.
