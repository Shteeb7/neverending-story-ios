# DNATransferView Timer Cleanup Fix

## Problem Summary
DNATransferView's premise polling timer (running every 2.5 seconds) was not being properly stopped after the view completed or dismissed, causing:
- Continuous API calls to `/onboarding/premises/:userId` even after user left the view
- 70+ API calls over 70 seconds while user was in LibraryView waiting for book generation
- Wasted server resources and unnecessary network traffic

## Root Causes

### Issue 1: DNATransferView Timer Not Stopping
When the user completed DNATransferView and navigated to LibraryView:
1. LaunchView switched from OnboardingView to LibraryView
2. DNATransferView's `.onDisappear` did NOT fire reliably (known SwiftUI bug with fullScreenCover)
3. The timer kept running in memory even after the view was removed from hierarchy
4. Multiple async Tasks were already in-flight when timer was invalidated
5. No guard to prevent in-flight Tasks from calling the API

### Issue 2: LibraryView Polling Never Starting
When LibraryView loaded:
1. `.onAppear` called `loadLibrary()` and `startPollingIfNeeded()` in sequence
2. `startPollingIfNeeded()` ran while `stories` array was still empty (API hadn't returned yet)
3. `hasGeneratingStories` returned false, so polling never started
4. Even if book was generating, user wouldn't see updates

## Comprehensive Fix (Multiple Safety Layers)

### Layer 1: Active View Guard
- Added `@State private var isViewActive = true` to track if view is still active
- Prevents zombie polling from continuing after view dismisses

### Layer 2: Guard in checkForPremises()
- Added guard at start: stops if `isViewActive == false`
- Added guard after API call: discards result if view dismissed during call
- Prevents in-flight async Tasks from continuing

### Layer 3: Stop Timer in finishCeremony()
- Timer is invalidated IMMEDIATELY when premises are found
- Happens BEFORE `onComplete()` callback (before dismissal)
- Doesn't rely on `.onDisappear` being called

### Layer 4: Enhanced cleanup()
- Sets `isViewActive = false` to stop all in-flight Tasks
- Invalidates both timers (transferTimer and premiseTimer)
- Sets timer references to nil
- Added logging to track when cleanup happens

### Layer 5: .onDisappear Fallback
- Calls `cleanup()` if view disappears via other paths
- Acts as safety net if finishCeremony() didn't run

### Layer 6: Logging
- Added NSLog statements at key points to track:
  - When polling starts
  - When guards block API calls
  - When timer is stopped
  - When cleanup happens

## Files Modified
- `/NeverendingStory/Views/Onboarding/DNATransferView.swift`
- `/NeverendingStory/Views/Library/LibraryView.swift`
- `/NeverendingStory/Views/Components/BookFormationView.swift`

## Changes Made

### DNATransferView.swift
1. Added `isViewActive` state variable (line ~162)
2. Updated `cleanup()` to set `isViewActive = false` and add logging
3. Added guards to `checkForPremises()` to check `isViewActive`
4. Updated `finishCeremony()` to invalidate timer BEFORE calling `onComplete()`
5. Added logging to `startPremisePolling()`
6. Updated `retryGeneration()` to reset `isViewActive = true`

### LibraryView.swift
7. Removed `startPollingIfNeeded()` call from `.onAppear` (was running before data loaded)
8. Added `startPollingIfNeeded()` call inside `loadLibrary()` AFTER stories array is populated
9. Verified `refreshLibrary()` already stops polling when no generating stories (existing logic)

### BookFormationView.swift
10. Updated message text to clarify timing: "10 minutes for the first few chapters"

## Testing Recommendations
Once deployed:
1. Complete onboarding flow through DNATransferView
2. Navigate to LibraryView and wait for book generation
3. Check Railway logs - should see:
   - ✅ "Timer stopped and view marked inactive" when premises found
   - ✅ No more `/onboarding/premises/:userId` calls after that
4. Check for logs showing guards blocking zombie calls:
   - "🛑 checkForPremises() aborted - view is no longer active"
   - "🛑 checkForPremises() result discarded - view dismissed during API call"

## Expected Behavior After Fix
- Timer starts when DNATransferView enters `.sustaining` phase
- Timer stops immediately when premises are found (< 15 seconds typically)
- No API calls after user navigates away
- In-flight Tasks are blocked by guards
- Clean logs showing proper lifecycle

## Commit When Ready
**DO NOT COMMIT YET** - User is waiting for current book generation to complete.
When ready to deploy:
```bash
cd "/Users/steven/Library/Mobile Documents/com~apple~CloudDocs/NeverendingStory"
git add -A
git commit -m "Fix polling timers and clarify BookFormationView message

Three improvements:

1. DNATransferView timer not stopping after completion
   - Add isViewActive guard to prevent zombie polling
   - Stop timer in finishCeremony() before dismissal
   - Add guards in checkForPremises() for in-flight Tasks
   - Enhanced cleanup() with logging
   - Fixes 70+ unnecessary premise API calls after user left view

2. LibraryView polling never starting
   - Move startPollingIfNeeded() from .onAppear to inside loadLibrary()
   - Now called AFTER stories array is populated, not before
   - Fixes polling not starting when books are generating
   - Existing logic already stops polling when generation completes

3. BookFormationView message clarity
   - Updated text to clarify: \"10 minutes for the first few chapters\"
   - Sets accurate expectations about incremental generation

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
git push origin main
```
