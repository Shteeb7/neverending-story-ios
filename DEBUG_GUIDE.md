# Voice Interview Debug Guide

## Critical Bug Fixed ✅

**Issue Found:** The audio player node was being stopped when user started speaking (`playerNode.stop()`) but **never restarted** when user stopped speaking. This meant no audio could play after the first interruption.

**Fix Applied:**
- Created `resumeAudioPlayback()` function that calls `playerNode.play()`
- Automatically called when `input_audio_buffer.speech_stopped` is received
- Safety check in `response.audio.delta` to restart player if stopped

This was likely the root cause of no audio output!

---

## What to Look for in Xcode Console

### ✅ Expected Successful Flow:

```
🔌 Connecting to OpenAI WebSocket...
   URL: wss://api.openai.com/v1/realtime?model=gpt-4o-realtime-preview-2024-12-17
✅ WebSocket task created and resumed
   API Key present: sk-proj-ON...

🔊 Setting up audio playback...
✅ Attached player and mixer nodes
✅ Connected audio nodes: player -> mixer -> output
✅ Audio player node started

🎤 Starting audio engine...
✅ Audio engine started successfully
   Engine is running: true

📨 Received event: session.created
✅ session.created - WebSocket connected to OpenAI!
   Session ID: sess_xxxxx

📤 Sending session configuration...
📨 Received event: session.updated
✅ session.updated - Configuration applied successfully

👋 Triggering AI greeting with response.create event...
✅ response.create event sent (greeting request)
👋 AI greeting triggered

📨 Received event: response.created
✅ response.created - AI is preparing to respond
   Response ID: resp_xxxxx

📨 Received event: response.audio.delta
🔊 response.audio.delta received
   Delta length: 2048 characters
🎵 playAudioChunk called with base64 length: 2048
   Decoded audio data: 1536 bytes
🎵 Scheduled audio chunk: 768 frames, 1536 bytes

[... more audio.delta events ...]

📨 Received event: response.audio.done
✅ response.audio.done - AI finished speaking

📨 Received event: response.done
✅ response.done - conversation turn complete
```

---

## Diagnostic Scenarios

### Scenario A: WebSocket Not Connecting

**Symptoms in logs:**
```
🔌 Connecting to OpenAI WebSocket...
❌ WebSocket receive error: [error message]
```

**Possible causes:**
- Invalid API key (check Secrets.swift)
- Network connectivity issues
- OpenAI API is down

---

### Scenario B: Audio Not Being Sent to OpenAI

**Symptoms in logs:**
```
✅ Audio engine started successfully
   Engine is running: true

[NO "📤 Sending audio" messages]
```

**Possible causes:**
- Microphone tap not working
- Audio converter failing silently
- Audio buffer format mismatch

---

### Scenario C: No Responses from OpenAI

**Symptoms in logs:**
```
✅ response.create event sent (greeting request)

[NO "response.created" or "response.audio.delta" messages]
```

**Possible causes:**
- Session configuration rejected by OpenAI
- Invalid modalities or voice setting
- API rate limit or quota exceeded

---

### Scenario D: Audio Playback Not Working (NOW FIXED!)

**Symptoms in logs:**
```
📨 Received event: response.audio.delta
🔊 response.audio.delta received
   Delta length: 2048 characters
❌ audioPlayerNode is nil - cannot play audio

OR

🎵 playAudioChunk called with base64 length: 2048
❌ Failed to decode base64 audio data

OR

⚠️ Cannot create audio format
⚠️ Cannot create audio buffer
```

**Now includes:**
```
▶️  Resumed audio playback - ready for AI response
```

This confirms the player node is restarted after user stops speaking.

---

## Key Events to Watch For

| Event | Meaning |
|-------|---------|
| `session.created` | WebSocket connected successfully |
| `session.updated` | Configuration applied |
| `response.created` | AI acknowledged greeting request |
| `response.audio.delta` | Audio chunk received from AI |
| `response.audio.done` | AI finished speaking this response |
| `response.done` | Full conversation turn complete |
| `input_audio_buffer.speech_started` | User started speaking (player paused) |
| `input_audio_buffer.speech_stopped` | User stopped speaking (player resumed) |

---

## Testing Checklist

1. **Connect to Xcode debugger** before tapping "Start Voice Session"
2. **Watch console logs** as you tap the button
3. **Verify all ✅ checkmarks appear** in sequence
4. **Listen for audio** - should hear greeting within 2-3 seconds
5. **Check for any ❌ or ⚠️ warnings**
6. **Try speaking** - watch for `speech_started` → `speech_stopped` → audio playback

---

## If Audio Still Doesn't Play

After the bug fix, if you still don't hear audio:

1. **Check iPhone volume** - make sure it's not muted
2. **Check audio route** - might be going to AirPods/Bluetooth
3. **Check logs for** `⚠️ Player was stopped, restarting...` (indicates fix is working)
4. **Look for** `🔊 Audio chunk played (768 frames)` - confirms playback completion
5. **Verify** `Engine is running: true` - audio engine must be active

---

## Most Likely Fix

The `resumeAudioPlayback()` fix should resolve the no-audio issue. The player node was being stopped but never restarted, so after the first `speech_started` event (even if user didn't speak), audio would be permanently silent until the app restarted.

Now the player automatically restarts when:
- User stops speaking (`speech_stopped` event)
- First audio delta arrives (safety check)

Test again and report what you see in the logs! 🎉
