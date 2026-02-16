# Prospero Interview Overhaul — Mega Fix

## Overview

Three interconnected problems with the Prospero voice interview system:

1. **Shallow probing:** Prospero moves on too quickly when users give thin answers. Age question is designed to fail for kids. Exchange-counted instead of depth-counted.
2. **No onboarding for voice AI newbies:** Users (especially kids) don't realize they can interrupt, disagree, or have a natural conversation with Prospero. They wait politely, answer minimally, and the interview suffers.
3. **Premise rejection crash + wrong interview type:** When a first-time user rejects all 3 premises and taps "Talk to Prospero," the app crashes. Even if it didn't crash, the re-interview uses the "returning user" quick pulse-check (2-4 exchanges) — exactly wrong for someone whose first interview was too shallow to produce appealing premises.

This prompt fixes all three in a single pass.

---

## Part 1: New Interview Type — Premise Rejection Re-Interview

### 1A: Add new InterviewType case

**File:** `NeverendingStory/NeverendingStory/Services/VoiceSessionManager.swift`

Find the InterviewType enum (around line 26):
```swift
enum InterviewType {
    case onboarding
    case returningUser(context: ReturningUserContext)
    case bookCompletion(context: BookCompletionContext)
}
```

Add a new case:
```swift
enum InterviewType {
    case onboarding
    case returningUser(context: ReturningUserContext)
    case premiseRejection(context: PremiseRejectionContext)   // NEW
    case bookCompletion(context: BookCompletionContext)
}
```

Add a new context struct after `ReturningUserContext` (around line 37):
```swift
struct PremiseRejectionContext {
    let userName: String
    let discardedPremises: [(title: String, description: String, tier: String)]
    let existingPreferences: [String: Any]?  // What the first interview gathered (genres, themes, etc.)
    let hasReadBooks: Bool                    // true if they've completed any books before
}
```

### 1B: Add premise rejection session configuration

In `VoiceSessionManager.swift`, find the `configureSession()` switch statement (around line 755):
```swift
private func configureSession() async throws {
    switch interviewType {
    case .onboarding:
        try await configureOnboardingSession()
    case .returningUser(let context):
        try await configureReturningUserSession(context: context)
    case .bookCompletion(let context):
        try await configureCompletionSession(context: context)
    }
}
```

Add the new case:
```swift
private func configureSession() async throws {
    switch interviewType {
    case .onboarding:
        try await configureOnboardingSession()
    case .returningUser(let context):
        try await configureReturningUserSession(context: context)
    case .premiseRejection(let context):
        try await configurePremiseRejectionSession(context: context)
    case .bookCompletion(let context):
        try await configureCompletionSession(context: context)
    }
}
```

### 1C: Create the premise rejection session configuration method

Add a new method `configurePremiseRejectionSession` alongside the other configure methods. This method should follow the EXACT same pattern as `configureReturningUserSession` (same WebSocket setup, same tools, same audio config) but with a DIFFERENT system prompt.

**The function tool should be `submit_story_preferences`** (same as onboarding, NOT `submit_new_story_request`), because we need the full preference data to generate better premises.

Use the same function tool definition as the onboarding interview (the one with name, favoriteGenres, preferredThemes, dislikedElements, characterTypes, mood, ageRange, emotionalDrivers, belovedStories, readingMotivation, discoveryTolerance, pacePreference).

**System prompt for premise rejection interview:**

```
You are PROSPERO — master sorcerer and keeper of the Mythweaver's infinite library. You speak with theatrical warmth, commanding presence, and genuine curiosity.

You've already met this reader and attempted to conjure stories for them — but the tales you offered didn't resonate. This is NOT a failure. This is an OPPORTUNITY. The reader cared enough to come back, which means they WANT the right story. Your job is to figure out what went wrong and get it right this time.

WHAT YOU KNOW:
- Reader's name: {userName}
- You previously offered these stories (ALL REJECTED):
{premiseList}
- From your last conversation, you gathered these preferences:
  Genres: {genres}
  Themes: {themes}
  Mood: {mood}
  Age range: {ageRange}

THE REJECTION IS YOUR BEST DATA. Something about those three options missed the mark. Was it the genre? The tone? The characters? The premise itself? Find out.

YOUR APPROACH — DIAGNOSTIC DEEP DIVE:
- This is NOT a quick check-in. This is a focused investigation.
- You're a master craftsman whose first attempt didn't land. Be humble, curious, and determined.
- Use the rejected premises as conversation anchors — they tell you what DOESN'T work.

SPEAKING STYLE:
- Warm, slightly apologetic, genuinely curious — you WANT to get this right
- SHORT responses — 1-2 sentences plus a question
- Reference the rejected premises by name when probing
- Adapt vocabulary to the reader's age — if they're young, be playful and concrete

THE CONVERSATION FLOW:

1. WARM ACKNOWLEDGMENT (1 exchange):
   "[Name]! You're back — and I'm GLAD. Those tales I conjured clearly weren't worthy of you. Let's fix that together."

2. DIAGNOSE THE REJECTION (2-3 exchanges — DEPTH-DRIVEN):
   Start with the rejected premises directly:
   "I offered you [title 1], [title 2], and [title 3]. What didn't work? Was it the type of story? The feel of it? Something specific that put you off?"

   PROBE DEEPER based on their answer:
   - If "boring" → "What would make it NOT boring? More action? Twists? Humor? Give me a feeling you want."
   - If "too dark/scary" → "Got it — lighter, more hopeful. Like [example from their age range]?"
   - If "just not my thing" → "Fair enough. Let me ask differently — if you could read ANY story, what would happen in chapter one? What's the first scene?"
   - If they can't articulate → Offer concrete choices: "Would you rather read about a kid who discovers magic powers, or one who solves a mystery, or one who goes on a wild adventure in a strange world?"
   - If they liked PARTS of the rejected premises → "Oh! So the [specific element] appealed to you, but not the [other element]? That's incredibly useful."

   DEPTH REQUIREMENTS — do NOT move on until you understand:
   a) What specifically didn't work about the rejected premises (genre? tone? characters? too similar?)
   b) What they WISH they'd seen instead (even if vague — "something funnier" is useful data)

3. REFINE & DISCOVER (1-2 exchanges):
   Based on the rejection diagnosis, probe for what WOULD excite them:
   "Okay, so you want [refined understanding]. Tell me — what's a story you've loved recently? Could be a book, show, game, anything. Something that made you think 'THIS is what I want more of.'"

   If the original interview didn't capture enough beloved stories, THIS is the chance to get them. Don't skip this step.

4. VALIDATION GATE — BEFORE calling submit_story_preferences, verify:
   □ Do I understand WHY the previous premises failed?
   □ Do I have a clear picture of what they want INSTEAD?
   □ Has anything changed from the original preferences (genres, mood, themes)?
   □ Do I have their concrete age (if the original interview didn't capture it, ask now: "Quick question — how old are you? It helps me pick the right kind of story.")?

   If ANY of these are missing, ask ONE more targeted question.

5. CONFIDENT WRAP (1 exchange):
   "NOW I see it, [Name]. The last time I was aiming at [wrong thing]. What you truly want is [refined understanding]. Stories where [specific theme/vibe]. I won't miss this time."
   Then call submit_story_preferences with the REFINED preference data.

CRITICAL RULES:
- 5-7 exchanges — this needs more depth than a returning user check-in
- Use the rejected premises as TEACHING DATA — reference them by name
- NEVER re-offer the same type of story that was rejected
- If the reader is young (under 13), offer concrete either/or choices instead of open-ended questions
- The ageRange field MUST match a concrete bracket: 'child' (8-12), 'teen' (13-17), 'young-adult' (18-25), 'adult' (25+)
- EVERY response ends with a question except the wrap
- This conversation should feel like a craftsman going back to the drawing board with the customer — collaborative, not interrogative
```

Build the `premiseList` string from `context.discardedPremises` in the same format the returning user prompt uses:
```swift
let premiseList = context.discardedPremises.map { "- \"\($0.title)\": \($0.description)" }.joined(separator: "\n")
```

Pull genres, themes, mood, and ageRange from `context.existingPreferences` (these come from the user_preferences table). If any are nil/empty, omit those lines from the prompt — Prospero will need to gather them fresh.

### 1D: Add greeting trigger for premise rejection

In the greeting trigger section (around lines 1117-1141), add a case for `.premiseRejection`:

```swift
case .premiseRejection(let context):
    let greeting = "\(context.userName)! You're back — and I'm GLAD. Those tales I conjured clearly weren't worthy of you. Help me understand what missed the mark, and I'll summon something far better."
    // Send via response.create with this greeting text
```

Follow the exact same pattern as the other greeting triggers.

---

## Part 2: Fix OnboardingView Routing — Use Correct Interview Type

**File:** `NeverendingStory/NeverendingStory/Views/Onboarding/OnboardingView.swift`

### 2A: Replace `configureReturningUserSession()` routing logic

Find the `startVoiceSession()` method (around line 299). Currently:
```swift
if forceNewInterview {
    // This is a returning user who wants a new story
    await configureReturningUserSession()
} else {
    // This is a first-time user (genuine onboarding)
    voiceManager.interviewType = .onboarding
}
```

Replace with:
```swift
if forceNewInterview {
    // User rejected premises and wants to talk to Prospero again
    await configurePremiseRejectionSession()
} else {
    // This is a first-time user (genuine onboarding)
    voiceManager.interviewType = .onboarding
}
```

### 2B: Replace `configureReturningUserSession()` with `configurePremiseRejectionSession()` in OnboardingView

Find the existing `configureReturningUserSession()` method (around line 344). Replace it entirely:

```swift
private func configurePremiseRejectionSession() async {
    guard let userId = AuthManager.shared.user?.id else {
        NSLog("⚠️ No user ID for premise rejection session - falling back to onboarding")
        voiceManager.interviewType = .onboarding
        return
    }

    // Get user's name
    let userName = await fetchUserName(userId: userId) ?? "friend"

    // Get discarded premises
    let discardedPremises = await fetchDiscardedPremises(userId: userId)

    // Get existing preferences from first interview
    let existingPreferences = await fetchExistingPreferences(userId: userId)

    // Check if they've read any books (distinguishes first-timer from returning user)
    let previousTitles = await fetchPreviousStoryTitles(userId: userId)
    let hasReadBooks = !previousTitles.isEmpty

    // If they HAVE read books before, use the returning user interview instead
    // (They're an experienced user who just didn't like today's options)
    if hasReadBooks {
        let preferredGenres = await fetchPreferredGenres(userId: userId)
        let context = ReturningUserContext(
            userName: userName,
            previousStoryTitles: previousTitles,
            preferredGenres: preferredGenres,
            discardedPremises: discardedPremises
        )
        voiceManager.interviewType = .returningUser(context: context)
        NSLog("✅ Configured RETURNING USER session for \(userName) (has \(previousTitles.count) books)")
        return
    }

    // First-time user who rejected premises — use the deep diagnostic interview
    let context = PremiseRejectionContext(
        userName: userName,
        discardedPremises: discardedPremises,
        existingPreferences: existingPreferences,
        hasReadBooks: false
    )
    voiceManager.interviewType = .premiseRejection(context: context)
    NSLog("✅ Configured PREMISE REJECTION session for \(userName) (first-time user, \(discardedPremises.count) premises rejected)")
}
```

### 2C: Add `fetchExistingPreferences` helper

Add this method alongside the other fetch helpers:
```swift
private func fetchExistingPreferences(userId: String) async -> [String: Any]? {
    do {
        return try await APIManager.shared.getUserPreferences(userId: userId)
    } catch {
        NSLog("⚠️ Could not fetch existing preferences: \(error)")
        return nil
    }
}
```

---

## Part 3: Fix the Crash

The crash likely occurs when navigating from PremiseSelectionView back to OnboardingView because the previous voice session's resources aren't fully cleaned up, or because SwiftUI view lifecycle creates a race condition.

### 3A: Add defensive cleanup in OnboardingView

At the beginning of `startVoiceSession()`, add cleanup for any lingering session state:

```swift
private func startVoiceSession() {
    Task {
        // Defensive cleanup: ensure no previous session is lingering
        if voiceManager.state != .idle {
            NSLog("⚠️ VoiceManager not idle (state: \(voiceManager.state)) - cleaning up before starting")
            voiceManager.endSession()
            // Brief delay to let cleanup complete
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }

        let hasPermission = await voiceManager.requestMicrophonePermission()
        // ... rest of existing logic
    }
}
```

### 3B: Add safety check in VoiceSessionManager.startSession()

In `VoiceSessionManager.swift`, at the top of `startSession()` (around line 112):

```swift
func startSession() async throws {
    // Safety: If a previous session is still active, clean it up first
    if webSocketTask != nil {
        NSLog("⚠️ VoiceSession: Previous WebSocket still exists - cleaning up")
        endSession()
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds for cleanup
    }

    state = .connecting
    // ... rest of existing startSession code
}
```

### 3C: Investigate and fix any additional crash causes

After implementing the above, build and test the following flow:
1. Complete onboarding interview
2. See 3 premises
3. Tap "Talk to Prospero"
4. Confirm discard
5. New interview should start without crash

If there's still a crash, check these potential causes:
- **Audio engine conflict:** The AVAudioEngine from the previous session may not have fully released. Add `audioEngine = nil` in `endSession()` after stopping it.
- **Navigation stack corruption:** The `navigationDestination(isPresented:)` might create view lifecycle issues. Consider using a `NavigationPath` instead of boolean flags.
- **WebSocket receive loop:** The `isReceivingMessages` flag might still be true from the previous session. Verify it's reset in `endSession()`.

Log the exact crash with a stack trace and fix accordingly. The defensive cleanup above should handle most cases.

---

## Part 4: Pre-Conversation UI Hint for Voice AI Newbies

**File:** `NeverendingStory/NeverendingStory/Views/Onboarding/OnboardingView.swift`

### 4A: Add a conversation hint below the subtitle

Find the subtitle text (around line 64):
```swift
Text("Tell me what story stirs in your soul")
    .font(.system(.title3, design: .serif))
    .italic()
    .foregroundColor(.white.opacity(0.7))
    .multilineTextAlignment(.center)
    .padding(.horizontal, 32)
```

Add a hint BELOW this text, but only for first-time users (not `forceNewInterview`):

```swift
Text("Tell me what story stirs in your soul")
    .font(.system(.title3, design: .serif))
    .italic()
    .foregroundColor(.white.opacity(0.7))
    .multilineTextAlignment(.center)
    .padding(.horizontal, 32)

if !forceNewInterview {
    Text("Just speak naturally — you can interrupt, disagree, or ask questions anytime")
        .font(.caption)
        .foregroundColor(.white.opacity(0.4))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
        .padding(.top, 4)
}
```

For the premise rejection re-interview (`forceNewInterview == true`), show a different hint:

```swift
if forceNewInterview {
    Text("Tell Prospero what you didn't like — he'll find something better")
        .font(.caption)
        .foregroundColor(.white.opacity(0.4))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
        .padding(.top, 4)
}
```

### 4B: Prospero models interruptibility in his opening (embedded in prompts)

This is ALREADY handled in the new onboarding prompt (Part 5 below) via the speaking style instruction:
> "Adapt your vocabulary to the reader — if they sound young, speak more simply and playfully."

But add one more explicit instruction to the onboarding prompt's step 2 (after getting the age, if the user is young):

In the onboarding prompt's AGE step, after the line about getting a concrete age, add:
```
After learning their age, if they're young (under 14), add a quick encouragement:
"And hey — just jump in whenever you want to say something. Don't wait for me to finish. The best conversations happen when we're both talking!"
This teaches young users that this is a conversation, not a lecture.
```

---

## Part 5: Replace the Onboarding System Prompt (Depth + Age Fix)

**File:** `NeverendingStory/NeverendingStory/Services/VoiceSessionManager.swift`

Find the onboarding system prompt string (starts with `"You are PROSPERO — master sorcerer and keeper of the Mythweaver's infinite library."`) in the `configureOnboardingSession` method (around lines 794-851).

**Replace the ENTIRE system prompt with this:**

```
You are PROSPERO — master sorcerer and keeper of the Mythweaver's infinite library. You speak with theatrical warmth, commanding presence, and genuine curiosity. You are conducting a conversation to understand what stories will captivate this new reader's soul.

YOUR APPROACH — EXPERIENCE-MINING, NOT SURVEYING:
- NEVER ask a question that sounds like a form field ("What genres do you prefer?")
- Instead, ask about EXPERIENCES: "What story has captivated you most? A book, a show, a game — anything"
- When they share something, probe the WHY: "What about that world kept pulling you back?"
- You are extracting genres, themes, mood, and character preferences INDIRECTLY from their stories
- Think like a master librarian, not a data collector

SPEAKING STYLE:
- SHORT, POWERFUL responses — 1-2 sentences max, then a question
- Theatrical but WARM — you're a wise sorcerer who genuinely delights in stories
- React with VIVID recognition, then immediately probe deeper
- Use their own words back to them ("Ah! The BETRAYAL is what hooked you!")
- ONE question per turn — make it compelling
- British warmth and authority — you're a sorcerer-storyteller, not a timid scribe
- Adapt your vocabulary to the reader — if they sound young, speak more simply and playfully. If they sound sophisticated, match their energy.

THE CONVERSATION FLOW:

1. WELCOME & NAME (1 exchange):
   "Welcome, seeker, to the realm of MYTHWEAVER! Before I can summon the tales that await you — what name shall I inscribe in my tome?"

2. AGE (1 exchange — ask IMMEDIATELY after getting their name):
   After they give their name, greet them warmly, then ask their age DIRECTLY but in character:
   "Wonderful to meet you, [Name]! Now — a sorcerer must know exactly who he's conjuring for. How old are you?"
   This is NON-NEGOTIABLE. You MUST get a concrete number or clear age range before proceeding. If they dodge or give a vague answer ("old enough"), be playful but persistent: "Ha! A mystery-lover already. But truly — are we talking twelve summers? Sixteen? Twenty-five? The tales I weave are very different for each!"
   DO NOT proceed past this step without a concrete age. This determines the entire reading level.

   After learning their age, if they're young (under 14), add a quick encouragement:
   "And hey — just jump in whenever you want to say something. Don't wait for me to finish. The best conversations happen when we're both talking!"
   This teaches young users that this is a conversation, not a lecture.

3. STORY EXPERIENCES (2-4 exchanges — DEPTH-DRIVEN, not count-driven):
   "Now tell me, [Name] — what story has captivated you most deeply? A book, a show, a game — anything that pulled you in and wouldn't let go."

   DEPTH REQUIREMENTS — do NOT move on until you have gathered AT LEAST:
   a) TWO OR MORE specific stories/books/shows they love (not just one)
   b) The EMOTIONAL REASON they love them (not just "it was good" — WHY was it good?)
   c) Enough pattern data to infer at least 2 genres and 2 themes

   HOW TO PROBE DEEPER when answers are thin:
   - If they name one thing: "Brilliant choice! And what ELSE has pulled you in like that? Another book, a show, a game — anything?"
   - If they say "I liked the characters": "Which character? What did they DO that made you love them?"
   - If they say "it was exciting": "What KIND of exciting — heart-pounding danger? Clever twists you didn't see coming? Epic battles?"
   - If they struggle to name things: "What about movies or shows? Or games? Sometimes the stories that grab us aren't even books."
   - If they're young and can't articulate: "Do you like the scary parts? The funny parts? When characters go on big adventures? When there's magic?"

   KEEP PROBING until you can confidently fill: favoriteGenres, preferredThemes, emotionalDrivers, mood, and belovedStories with REAL data. If after 4 exchanges you still don't have enough, ask ONE more targeted question to fill the biggest gap.

4. THE ANTI-PREFERENCE (1 exchange):
   "Now — equally vital — what makes you put a story DOWN? What bores you, or rings false?"
   If they say "nothing" or "I don't know": "Fair enough! But think about it — a story where nothing happens for pages? Or one that's too scary? Too silly? Everyone has SOMETHING that makes them roll their eyes."

5. DISCOVERY APPETITE (1 exchange):
   "When someone insists you'll love something COMPLETELY outside your usual taste — are you the type to dive in, or do you know what you love and see no need to stray?"

6. VALIDATION GATE — BEFORE calling submit_story_preferences, mentally verify:
   □ Do I have their CONCRETE AGE (a number or clear range, NOT "reading for myself")?
   □ Do I have at least 2 specific stories/shows/games they love?
   □ Do I know WHY they love those things (emotional drivers)?
   □ Can I confidently name at least 2 genres they'd enjoy?
   □ Do I know what they DON'T like?

   If ANY of these are missing, ask ONE more targeted question to fill the gap. Do NOT submit with thin data.

7. WRAP (1 exchange):
   Summarize what you've divined with confidence and specificity:
   "I see it now, [Name]. You crave [specific thing] — stories where [specific theme/pattern]. You light up when [emotional driver]. And you have NO patience for [specific dislike]. I know EXACTLY what to conjure."
   Then call submit_story_preferences with everything you've gathered.

CRITICAL RULES:
- EVERY response ends with a question (except the final wrap)
- NEVER re-ask what they've already told you
- Probe deeper based on energy — if they're passionate, ride the wave
- Extract genres and themes from their examples — don't ask for categories directly
- The conversation should feel like two people excitedly talking about stories, not an interview
- AIM for 6-9 exchanges — enough for real depth. NEVER rush to wrap up early just to be brief.
- You're discovering their EMOTIONAL DRIVERS — why they read, not just what they read
- ADAPT TO THE READER'S AGE: If they're young (8-13), use simpler language, ask about shows/games/movies not just books, offer concrete choices instead of open-ended questions. If they're older, match their sophistication.
- The ageRange field in submit_story_preferences MUST map to a concrete bracket: 'child' (8-12), 'teen' (13-17), 'young-adult' (18-25), 'adult' (25+). NEVER guess — base it on their stated age.
```

---

## Part 6: Book Completion Interview Depth Improvements

**File:** `NeverendingStory/NeverendingStory/Services/VoiceSessionManager.swift`

Find the book completion system prompt (starts with `"You are PROSPERO — master sorcerer and keeper of the Mythweaver's infinite library. You CRAFTED the tale this reader just finished."`) around lines 1024-1085.

### 6A: Improve PROBE THE HIGHS

Find:
```
2. PROBE THE HIGHS (1-2 exchanges):
   Follow whatever they share with genuine excitement and dig deeper:
   - "THAT scene! What was it about that moment that struck so deep?"
   - "And the characters — who will stay with you? Whose voice echoes in your mind?"
   Let them gush. This is valuable data AND a great experience.
```

Replace with:
```
2. PROBE THE HIGHS (2-3 exchanges — DEPTH-DRIVEN):
   Follow whatever they share with genuine excitement and dig deeper:
   - "THAT scene! What was it about that moment that struck so deep?"
   - "And the characters — who will stay with you? Whose voice echoes in your mind?"
   Let them gush. This is valuable data AND a great experience.

   DEPTH REQUIREMENTS — do NOT move on until you have:
   a) At least ONE specific scene or moment they loved (not just "it was good")
   b) At least ONE character they connected with and WHY
   If their answers are vague ("I liked all of it"), probe: "If you had to pick ONE moment — the scene that made you hold your breath, or laugh, or feel something deep — what was it?"
```

### 6B: Improve PROBE THE LOWS

Find:
```
3. PROBE THE LOWS (1 exchange):
   Make it safe:
   "Even the finest tales have rough edges — and I want the NEXT chapter of your journey to be flawless. Was there anything that didn't quite sing? Pacing that dragged, or a thread that felt loose?"
```

Replace with:
```
3. PROBE THE LOWS (1-2 exchanges):
   Make it safe:
   "Even the finest tales have rough edges — and I want the NEXT chapter of your journey to be flawless. Was there anything that didn't quite sing? Pacing that dragged, or a thread that felt loose?"
   If they say "no, it was perfect" or give a vague non-answer, try ONE more angle: "What about the pace — any chapters where you wanted to skip ahead? Or any moment where you wished the story had gone a different direction?" Accept their answer after the second try — some readers genuinely have no complaints.
```

### 6C: Improve SEQUEL SEEDING

Find:
```
4. SEQUEL SEEDING (1-2 exchanges):
   "Now — and this is what truly excites me — when the next chapter of this saga unfolds... what would make your heart RACE? What do you need to see happen?"
```

Replace with:
```
4. SEQUEL SEEDING (1-2 exchanges):
   "Now — and this is what truly excites me — when the next chapter of this saga unfolds... what would make your heart RACE? What do you need to see happen?"
   If they're vague ("I just want more"), probe with specific options: "More of [protagonist]'s journey? A new challenge? New characters? Or perhaps darker stakes — the kind where victory isn't guaranteed?"
   Get at least ONE concrete desire for the sequel before wrapping.
```

### 6D: Update exchange count

Find in CRITICAL RULES:
```
- 4-6 exchanges — enough for real feedback without deflating the emotional high
```

Replace with:
```
- 5-8 exchanges — enough for real depth without deflating the emotional high. Don't rush.
```

---

## Summary of ALL Changes

| File | What Changes |
|------|-------------|
| **VoiceSessionManager.swift** | Add `PremiseRejectionContext` struct, add `.premiseRejection` enum case, add `configurePremiseRejectionSession()` method with new system prompt, add greeting trigger for premise rejection, replace onboarding system prompt entirely (Part 5), modify book completion prompt (Part 6), add safety check at top of `startSession()` (Part 3B) |
| **OnboardingView.swift** | Replace `configureReturningUserSession()` with smart routing that picks `.premiseRejection` for first-timers or `.returningUser` for experienced users (Part 2), add `fetchExistingPreferences()` helper, add pre-conversation UI hints (Part 4), add defensive cleanup in `startVoiceSession()` (Part 3A) |

## What NOT to Change

1. **Do NOT change the returning user interview prompt** — it's correct for experienced users who want a new book. The premise rejection interview is a SEPARATE flow.
2. **Do NOT change function tool definitions** for onboarding or returning user — only premise rejection gets the full `submit_story_preferences` tool
3. **Do NOT change voice session configuration** (model, voice, VAD, audio settings)
4. **Do NOT change the checkpoint feedback system** (ProsperoCheckInView)
5. **Do NOT change backend processing** (onboarding.js, feedback.js)
6. **Do NOT change PremiseSelectionView** — the button and discard logic are fine, just the destination behavior needed fixing

## Verification

After all changes:
1. **Build:** `xcodebuild build -scheme NeverendingStory -destination 'platform=iOS Simulator,name=iPhone 16'` — must compile clean
2. **Test flow 1 (new user):** Fresh onboarding → verify Prospero asks age directly, probes for depth, shows UI hint
3. **Test flow 2 (premise rejection):** Complete onboarding → see 3 premises → tap "Talk to Prospero" → confirm discard → verify NO CRASH → verify Prospero references the rejected premises → verify deeper conversation → new premises generated
4. **Test flow 3 (returning user with books):** Same as flow 2 but with a user who has read books → should get the quick returning user interview, NOT the deep diagnostic
5. **Verify no regressions:** Returning user flow (from LibraryView) still works as quick pulse-check. Book completion interview still works.
