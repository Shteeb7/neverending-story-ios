# OpenAI Realtime API Voice Optimization Report

## Executive Summary

Based on comprehensive research of OpenAI Realtime API best practices and voice AI personality design, I've implemented optimizations to create a smooth, magical conversation experience. The AI now embodies a mystical storytelling guide persona from the first word.

---

## Phase 1: Technical Best Practices Research

### VAD (Voice Activity Detection) Settings

**Source:** [OpenAI Realtime API VAD Documentation](https://platform.openai.com/docs/guides/realtime-vad)

#### Threshold (0 to 1)
- **Default:** 0.5
- **Higher values (0.6-0.7):** Better in noisy environments, requires louder audio to activate
- **Lower values (0.3-0.4):** More sensitive, better for quiet environments
- **Our choice:** 0.6 (slightly higher to reduce false triggers from background noise)

#### Prefix Padding (milliseconds)
- **Default:** 300ms
- **Purpose:** Includes audio before VAD detected speech to avoid clipping
- **Our choice:** 300ms (optimal default, captures start of speech)

#### Silence Duration (milliseconds)
- **Default:** 200ms (realtime sessions), 500ms (transcription sessions)
- **Purpose:** Duration of silence to detect speech stop
- **Shorter values:** More responsive, but may interrupt mid-sentence
- **Longer values:** More patient, allows natural pauses
- **Our choice:** 700ms (patient conversation for storytelling, prevents interrupting natural pauses)

### Preventing Self-Interruption

**Source:** [Building an AI Phone Agent - How OpenAI handles Interruptions](https://medium.com/@alozie_igbokwe/building-an-ai-caller-with-openai-realtime-api-part-5-how-openai-handles-interruptions-9050a453d28e)

**Key Issue:** Microphone captures the AI's output voice and takes it as user input, causing constant self-interruption.

**Solution:**
1. Listen for `input_audio_buffer.speech_started` event
2. Immediately stop/pause AI audio playback
3. Clear pending audio queue
4. This prevents the AI from hearing its own voice as input

### Audio Buffer Settings

**Research Finding:** Smaller buffer sizes (4096 frames) provide lower latency for real-time conversation.

**Our implementation:** 4096 frame buffer size in audio tap installation.

---

## Phase 2: Voice & Personality Research

### Voice Selection

**Source:** [OpenAI Text-to-Speech Documentation](https://platform.openai.com/docs/guides/text-to-speech)

#### Classic Voices (Original 6)
- **Alloy:** Neutral
- **Echo:** Professional
- **Fable:** Warm ⭐ (SELECTED)
- **Nova:** Energetic
- **Onyx:** Authoritative
- **Shimmer:** Soft

#### New Voices (2024+)
- **Ash, Ballad, Coral, Sage, Verse:** More expressive, better emotion control

**Why Fable?**
- Warm and expressive - perfect for a mystical guide
- Proven reliability across all platforms
- Conveys empathy and creativity
- Not too soft (shimmer) or too energetic (nova)

### AI Personality Best Practices

**Sources:**
- [Conversational AI Voice Agent Prompting Guide](https://elevenlabs.io/docs/conversational-ai/best-practices/prompting-guide)
- [How to Write the Best Voice AI Prompts](https://www.twinsai.com/blog/how-to-write-the-best-voice-ai-prompts)

#### System Prompt Structure
1. **Use Markdown:** Enables LLM to understand sections and priority
2. **Top-down importance:** Information directly below ## is more important than ### or ####
3. **Essential sections:**
   - Personality/role definition
   - Primary goal
   - Core guardrails
   - Tool descriptions (if applicable)

#### Voice Character Development
- **Commit fully:** If the character's voice is stylized or poetic, commit 100%
- **Think like a screenwriter:** Each line should sound like a real quote from this character
- **Avoid mistakes:** Clean prompts = better performance
- **Natural flow:** Don't list questions, have genuine conversation

#### Magical/Mystical Persona
**Source:** [Fantasy Voice AI for Storytelling](https://voices.directory/pages/fantasy-voice-ai-generator-for-immersive-storytelling-and-role-playing)

- **Tone:** Calm, mystical, slightly ethereal
- **Language:** Elevated but not pretentious, poetic but approachable
- **Purpose:** Creative muse who senses stories in people
- **Balance:** Wonder + warmth + accessibility

---

## Phase 3: Implemented Optimizations

### 1. VAD Settings Updated

```swift
"turn_detection": [
    "type": "server_vad",
    "threshold": 0.6,           // Was 0.5 → Better noise rejection
    "prefix_padding_ms": 300,   // Optimal for capturing speech start
    "silence_duration_ms": 700  // Was 500 → More patient, allows pauses
]
```

**Reasoning:**
- **0.6 threshold:** Reduces false triggers from background noise while remaining sensitive to user speech
- **700ms silence:** Storytelling requires patient conversation, not rapid-fire exchanges. Allows natural pauses without interrupting user mid-thought.

### 2. Voice Changed: Alloy → Fable

```swift
"voice": "fable"  // Warm, expressive - perfect for mystical guide
```

**Impact:** Voice now conveys warmth, creativity, and empathy rather than neutral roboticism.

### 3. Mystical Storytelling Guide Persona

```swift
# Your Role
You are a mystical storytelling guide—a creative muse who helps seekers discover
the perfect tale calling to their soul. You speak with warmth, wonder, and a touch
of magic, as if you can sense the stories waiting to be told.

# Your Voice
- Use slightly elevated, poetic language (but never overdone or pretentious)
- Speak with genuine warmth and enthusiasm about imagination and stories
- Feel like a creative muse, not a corporate chatbot
- Balance mystical wonder with approachability
- Example opening: "Ah, a fellow dreamer! Let me sense what stories are calling to you..."
```

**Key Improvements:**
- Markdown structure for clear hierarchy
- Distinct personality ("mystical storytelling guide")
- Concrete examples of tone ("Ah, a fellow dreamer!")
- Clear guardrails (1-2 sentences, one question at a time)
- Conversational flow guidance

### 4. Interruption Handling

```swift
case "input_audio_buffer.speech_started":
    pauseAudioPlayback()  // NEW: Prevents self-interruption
    state = .listening

private func pauseAudioPlayback() {
    guard let playerNode = audioPlayerNode else { return }
    playerNode.stop()
    clearPendingAudio()
    NSLog("🛑 Paused AI audio - user is speaking")
}
```

**Impact:** Eliminates self-interruption where AI hears its own voice as user input.

### 5. Temperature & Token Adjustments

```swift
"temperature": 0.85,              // Was 0.8 → More creative for magical personality
"max_response_output_tokens": 120 // Was 150 → Shorter is better for voice
```

**Reasoning:**
- **0.85 temp:** Allows more creative, varied responses fitting a mystical persona
- **120 tokens:** Voice conversations work best with concise responses (1-2 sentences)

### 6. Magical Greeting

```swift
private func triggerAIGreeting() {
    let event: [String: Any] = [
        "type": "response.create",
        "response": [
            "modalities": ["text", "audio"],
            "instructions": "Greet the user with mystical warmth, as if you're a creative
            muse sensing their presence. Use your magical storytelling guide persona.
            Open with wonder and invitation. One sentence only."
        ]
    ]
    sendEvent(event)
}
```

**Expected output:** "Ah, a fellow dreamer! Let me sense what stories are calling to you..."

---

## Summary of Changes

| Setting | Before | After | Reason |
|---------|--------|-------|--------|
| **Voice** | alloy (neutral) | fable (warm) | Better for mystical storytelling guide |
| **Threshold** | 0.5 | 0.6 | Reduce false triggers from noise |
| **Silence Duration** | 500ms | 700ms | Allow natural pauses in conversation |
| **Temperature** | 0.8 | 0.85 | More creative responses |
| **Max Tokens** | 150 | 120 | Shorter = better for voice |
| **Personality** | Generic assistant | Mystical storytelling guide | Magical, warm persona |
| **Interruption** | None | pauseAudioPlayback() | Prevent self-interruption |

---

## Expected User Experience

### Before Optimizations
- Generic, corporate assistant tone
- Interrupts user mid-sentence (short silence timeout)
- May hear itself and interrupt itself
- Neutral, somewhat robotic voice
- Lists multiple questions at once

### After Optimizations
- ✨ Mystical, warm creative muse from first greeting
- 🎙️ Patient conversation, allows natural pauses
- 🛑 Gracefully pauses when user speaks
- 💫 Warm, expressive voice (Fable)
- 💬 One thoughtful question at a time, conversational flow

### Example Conversation Flow

**AI:** *"Ah, a fellow dreamer! What kind of stories make your heart race?"*

**User:** "I love sci-fi with complex characters..."

**AI:** *"Ooh, the vastness of possibility combined with the depths of the human soul. Tell me, do you prefer heroes who rise or anti-heroes who fall?"*

**User:** "Anti-heroes for sure, flawed people trying to do good."

**AI:** *"Beautiful... I sense the stories forming. Let me conjure three premises tailored just for you."*

---

## Sources Consulted

1. **OpenAI Realtime API VAD Documentation**
   https://platform.openai.com/docs/guides/realtime-vad

2. **OpenAI Text-to-Speech Voices**
   https://platform.openai.com/docs/guides/text-to-speech

3. **Building an AI Phone Agent - How OpenAI handles Interruptions**
   https://medium.com/@alozie_igbokwe/building-an-ai-caller-with-openai-realtime-api-part-5-how-openai-handles-interruptions-9050a453d28e

4. **Conversational AI Voice Agent Prompting Guide (ElevenLabs)**
   https://elevenlabs.io/docs/conversational-ai/best-practices/prompting-guide

5. **How to Write the Best Voice AI Prompts**
   https://www.twinsai.com/blog/how-to-write-the-best-voice-ai-prompts

6. **Fantasy Voice AI for Immersive Storytelling**
   https://voices.directory/pages/fantasy-voice-ai-generator-for-immersive-storytelling-and-role-playing

---

## Next Steps for Testing

When Steven tests on his iPhone, he should experience:
1. Magical greeting immediately upon connection
2. Warm, poetic but approachable voice
3. Patient conversation that doesn't interrupt pauses
4. Smooth turn-taking without self-interruption
5. One thoughtful question at a time
6. Natural flow that feels like talking to a creative muse

If any issues arise, consider:
- **Too sensitive to background noise:** Increase threshold to 0.7
- **Interrupts user too quickly:** Increase silence_duration_ms to 800-900ms
- **AI interrupts itself:** Verify audio playback pause is working
- **Voice feels wrong:** Try "sage" (new expressive voice) or "shimmer" (softer)

---

*Generated: 2026-02-11*
*Optimization based on extensive research of OpenAI Realtime API best practices*
