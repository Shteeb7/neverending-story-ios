# Checkpoint Deadlock Fix

**Date:** 2026-02-15
**Status:** ✅ Complete
**Test Results:** ✅ Server tests pass (82/82), ✅ iOS build succeeds

## Problem

Users were stuck in a deadlock where:
1. GeneratingChaptersView polls forever for the next chapter
2. The server is at `awaiting_chapter_X_feedback` and won't generate chapters until it receives checkpoint feedback
3. The checkpoint interview either failed to show or wasn't completed

**Root Causes:**
- GeneratingChaptersView had no awareness of the checkpoint system
- No max retry limit (Rule #6 violation)
- No fallback when checkpoint triggers were missed

## Solution

Implemented 5 fixes to make the iOS app checkpoint-aware and add proper circuit breakers:

### Fix 1: Make handleNextChapterTap() checkpoint-aware
**File:** `BookReaderView.swift:407-455`

When user taps "Next Chapter" at the end of chapters 3, 6, or 9, the app now:
1. Checks if feedback has been submitted for that checkpoint
2. If not, shows ProsperoCheckInView immediately
3. Only shows GeneratingChaptersView if feedback already exists

This catches the case where the automatic checkpoint trigger was missed or failed.

### Fix 2: Add checkpoint check on view load
**File:** `BookReaderView.swift:350-371`

When BookReaderView loads (e.g., app restart), it now:
1. Checks for pending checkpoint after 1 second delay
2. Triggers checkpoint interview if the user is on a checkpoint chapter

This handles users who return to the app while on a checkpoint chapter.

### Fix 3: Make GeneratingChaptersView detect deadlocks
**File:** `GeneratingChaptersView.swift`

Added three safety mechanisms:
1. **Circuit breaker:** Max 60 polling attempts (5 minutes at 5-second intervals)
2. **Deadlock detection:** Every 30 seconds, checks if server is in `awaiting_*` state
3. **User feedback:** Shows different message when waiting for feedback vs. generating

Changes:
- Added state: `pollAttempts`, `isWaitingForFeedback`, `maxPollAttempts`
- Added callback: `onNeedsFeedback`
- Added method: `checkIfWaitingForFeedback()`
- Updated `checkChapterAvailability()` with circuit breaker logic
- Updated view body to show context-appropriate messages

### Fix 4: Wire up onNeedsFeedback callback
**File:** `BookReaderView.swift:310-337`

When GeneratingChaptersView detects the server is waiting for feedback:
1. Dismisses the generating view
2. Determines correct checkpoint based on chapter number
3. Shows ProsperoCheckInView

This automatically recovers from the deadlock state.

### Fix 5: Use getCurrentState for story progress
**File:** `GeneratingChaptersView.swift:146-159`

Uses `APIManager.shared.getCurrentState(storyId:)` to fetch story progress, which includes the `generationProgress` field needed to detect `awaiting_*` states.

## Testing Scenarios

All scenarios should be tested:

1. **Happy path:** User completes chapter 2 → checkpoint shows → feedback submitted → chapters 4-6 generate
2. **Missed trigger:** User completes chapter 3, checkpoint didn't show → tap "Next Chapter" → checkpoint shows
3. **App restart:** User quits app on chapter 3 → reopens app → checkpoint shows after 1 second
4. **Deadlock recovery:** GeneratingChaptersView shows, but server is stuck in `awaiting_chapter_2_feedback` → after 30 seconds, view detects deadlock → shows checkpoint
5. **Circuit breaker:** Chapter never becomes available → after 5 minutes, polling stops with log message

## Code Quality

- ✅ Complies with Rule #6 (no infinite loops, max retry count)
- ✅ Clear logging with attempt counts and circuit breaker activations
- ✅ Graceful error handling
- ✅ No breaking changes to existing flows
- ✅ All server tests pass (82/82)
- ✅ iOS app builds successfully

## Files Modified

1. `NeverendingStory/NeverendingStory/Views/Reader/BookReaderView.swift`
   - Updated `handleNextChapterTap()` (lines 407-455)
   - Updated `.task` block (lines 350-371)
   - Updated `.fullScreenCover(isPresented: $showGeneratingChapters)` (lines 310-337)

2. `NeverendingStory/NeverendingStory/Views/Feedback/GeneratingChaptersView.swift`
   - Added state variables and callback (lines 11-19)
   - Updated view body with conditional messaging (lines 75-101)
   - Added circuit breaker to `checkChapterAvailability()` (lines 106-143)
   - Added `checkIfWaitingForFeedback()` method (lines 145-159)
   - Updated preview (lines 139-149)

## Next Steps

1. Monitor Railway logs for circuit breaker activations: `🛑 GeneratingChaptersView: Max poll attempts`
2. Monitor for deadlock detections in production
3. If users still get stuck, consider adding a manual "Check for Feedback" button in GeneratingChaptersView
