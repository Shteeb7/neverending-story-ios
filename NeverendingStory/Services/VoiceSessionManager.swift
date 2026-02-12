//
//  VoiceSessionManager.swift
//  NeverendingStory
//
//  Manages OpenAI Realtime API voice sessions
//

import Foundation
import AVFoundation
import Combine
import UIKit

enum VoiceSessionState {
    case idle
    case requestingPermission
    case connecting
    case connected
    case listening
    case processing
    case conversationComplete
    case error(String)
}

@MainActor
class VoiceSessionManager: ObservableObject {
    @Published var state: VoiceSessionState = .idle
    @Published var audioLevel: Float = 0.0
    @Published var transcription: String = ""
    @Published var conversationText: String = "" // Full conversation for display
    @Published var isConversationComplete = false // Signals conversation end

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var webSocketTask: URLSessionWebSocketTask?
    private var audioConverter: AVAudioConverter?
    private var isReceivingMessages = false
    private var sessionToken: String?

    // Callback for when story preferences are gathered
    var onPreferencesGathered: (([String: Any]) -> Void)?

    // Continuation to wait for session.created event
    private var sessionCreatedContinuation: CheckedContinuation<Void, Never>?

    // Audio playback
    private var audioPlayerNode: AVAudioPlayerNode?
    private var audioMixerNode: AVAudioMixerNode?
    private var pendingAudioData = Data()

    // Audio buffering (prevents choppy/silent audio)
    private var audioQueue: [Data] = []
    private var isPlayingAudio = false
    private var isAudioStreamComplete = false // Track if response.audio.done received
    private var scheduledBufferCount = 0 // Track how many buffers are currently scheduled

    // Target format for OpenAI: 24kHz, PCM16, mono
    private let targetSampleRate: Double = 24000
    private let targetChannels: AVAudioChannelCount = 1

    // MARK: - Initialization

    func requestMicrophonePermission() async -> Bool {
        state = .requestingPermission

        let status = await AVAudioApplication.requestRecordPermission()

        if status {
            state = .idle
        } else {
            state = .error("Microphone permission denied")
        }

        return status
    }

    // MARK: - Session Management

    func startSession() async throws {
        state = .connecting

        NSLog("🔐 VoiceSession: Starting DIRECT WebSocket connection (no backend session)")
        NSLog("📊 Initial conversationText length: \(conversationText.count)")

        // Prevent screen from sleeping during voice session
        await MainActor.run {
            UIApplication.shared.isIdleTimerDisabled = true
            NSLog("🔒 Screen lock DISABLED - phone will stay awake during conversation")
        }

        // Setup audio engine first
        try setupAudioEngine()

        // Create WebSocket connection DIRECTLY to OpenAI (same as AIPersonalTrainer)
        guard let url = URL(string: "wss://api.openai.com/v1/realtime?model=gpt-4o-realtime-preview-2024-12-17") else {
            throw NSError(domain: "VoiceSession", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid WebSocket URL"])
        }

        var request = URLRequest(url: url)
        // Use API key directly - same as working AIPersonalTrainer app
        request.setValue("Bearer \(AppConfig.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")

        NSLog("🔌 Connecting to OpenAI WebSocket...")
        NSLog("   URL: \(url.absoluteString)")

        webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask?.resume()

        NSLog("✅ WebSocket task created and resumed")
        NSLog("   API Key present: \(AppConfig.openAIAPIKey.prefix(10))...")

        // Start receiving messages immediately
        startReceivingMessages()
        NSLog("✅ Started receiving messages")

        // Wait for session.created event from OpenAI before configuring (with timeout)
        NSLog("⏳ Waiting for session.created event from OpenAI...")
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                // Task 1: Wait for session.created
                group.addTask { @MainActor in
                    await withCheckedContinuation { continuation in
                        self.sessionCreatedContinuation = continuation
                    }
                }

                // Task 2: Timeout after 5 seconds
                group.addTask {
                    try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                    throw NSError(domain: "VoiceSession", code: -99, userInfo: [NSLocalizedDescriptionKey: "Timeout waiting for session.created"])
                }

                // Wait for first task to complete (either session.created or timeout)
                try await group.next()
                group.cancelAll()
            }
            NSLog("✅ session.created event received, now configuring...")
        } catch {
            NSLog("❌ Failed waiting for session.created: \(error)")
            throw error
        }

        // Configure the session (AFTER session.created is received)
        NSLog("⚙️ Configuring session...")
        try await configureSession()
        NSLog("✅ Session configured")

        state = .connected
        NSLog("✅ State set to connected")

        // Start audio streaming
        await startListening()
        NSLog("🎤 Audio streaming started")

        // Send initial greeting to start conversation
        triggerAIGreeting()
        NSLog("👋 AI greeting triggered")
    }

    func endSession() {
        stopListening()

        // Re-enable screen lock now that conversation is over
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
            NSLog("🔓 Screen lock RE-ENABLED - phone can sleep normally")
        }

        // Clean up any pending continuation
        if let continuation = sessionCreatedContinuation {
            sessionCreatedContinuation = nil
            continuation.resume()
            NSLog("⚠️ Cleaned up pending session.created continuation")
        }

        // Send session end event
        if webSocketTask != nil {
            sendEvent(type: "input_audio_buffer.commit")
        }

        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isReceivingMessages = false

        // NOTE: Conversation submission is now handled manually in OnboardingView.proceedToLibrary()
        // DON'T auto-submit here anymore

        state = .conversationComplete
        isConversationComplete = true
    }

    // MARK: - Backend Integration

    private func submitConversationToBackend() async {
        guard let userId = AuthManager.shared.user?.id else {
            NSLog("⚠️ Cannot submit conversation - no user ID")
            return
        }

        NSLog("📤 Submitting conversation transcript to backend...")
        NSLog("   User ID: \(userId)")
        NSLog("   Transcript length: \(conversationText.count) characters")

        do {
            // Step 1: Submit transcript to extract preferences
            try await APIManager.shared.submitVoiceConversation(
                userId: userId,
                conversation: conversationText
            )
            NSLog("✅ Conversation transcript submitted")

            // Step 2: Generate premises based on extracted preferences
            try await APIManager.shared.generatePremises()
            NSLog("✅ Story premises generated")

        } catch {
            NSLog("❌ Failed to process conversation: \(error)")
            state = .error("Failed to process conversation: \(error.localizedDescription)")
        }
    }

    // MARK: - Audio Engine Setup

    private func setupAudioEngine() throws {
        let audioSession = AVAudioSession.sharedInstance()
        // Use playAndRecord for two-way audio conversation
        // .voiceChat mode automatically handles Bluetooth routing
        // Allow Bluetooth audio (AirPods, etc.) - removed .defaultToSpeaker to enable this
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetoothA2DP])
        try audioSession.setActive(true)

        // Prefer Bluetooth audio route if available (AirPods, etc.)
        let availableInputs = audioSession.availableInputs ?? []
        if let bluetoothInput = availableInputs.first(where: { $0.portType == .bluetoothHFP || $0.portType == .bluetoothA2DP }) {
            try audioSession.setPreferredInput(bluetoothInput)
            NSLog("✅ Using Bluetooth audio input: \(bluetoothInput.portName)")
        }

        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode

        guard let inputNode = inputNode else {
            throw NSError(domain: "VoiceSession", code: -2, userInfo: [NSLocalizedDescriptionKey: "No input node available"])
        }

        // Enable voice processing on input node (prevents feedback/echo)
        try audioEngine?.inputNode.setVoiceProcessingEnabled(true)
        NSLog("✅ Voice processing enabled on INPUT node")

        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Create target format: 24kHz, PCM16, mono
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: targetSampleRate,
            channels: targetChannels,
            interleaved: true
        ) else {
            throw NSError(domain: "VoiceSession", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to create target audio format"])
        }

        // Create converter
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw NSError(domain: "VoiceSession", code: -4, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio converter"])
        }

        audioConverter = converter

        // Setup audio playback
        setupAudioPlayback()

        // DON'T install tap yet - must start engine first!
        // Tap will be installed in startListening() after engine is running
        NSLog("✅ Audio engine setup complete (tap will be installed after engine starts)")
    }

    private func setupAudioPlayback() {
        guard let audioEngine = audioEngine else {
            NSLog("⚠️ setupAudioPlayback: audioEngine is nil")
            return
        }

        NSLog("🔊 Setting up audio playback...")

        // Create player node for AI audio responses
        audioPlayerNode = AVAudioPlayerNode()
        audioMixerNode = AVAudioMixerNode()

        guard let playerNode = audioPlayerNode,
              let mixerNode = audioMixerNode else {
            NSLog("⚠️ Failed to create player/mixer nodes")
            return
        }

        // Attach nodes to engine
        audioEngine.attach(playerNode)
        audioEngine.attach(mixerNode)
        NSLog("✅ Attached player and mixer nodes")

        // Enable voice processing on output node (prevents feedback/echo)
        do {
            try audioEngine.outputNode.setVoiceProcessingEnabled(true)
            NSLog("✅ Voice processing enabled on OUTPUT node")
        } catch {
            NSLog("⚠️ Failed to enable voice processing on output: \(error)")
        }

        // Create format for playback (24kHz, PCM16, mono - same as OpenAI output)
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: targetSampleRate,
            channels: targetChannels,
            interleaved: true
        ) else {
            NSLog("⚠️ Failed to create output audio format")
            return
        }

        // Connect player -> mixer -> output
        audioEngine.connect(playerNode, to: mixerNode, format: outputFormat)
        audioEngine.connect(mixerNode, to: audioEngine.mainMixerNode, format: outputFormat)
        NSLog("✅ Connected audio nodes: player -> mixer -> output")

        // DON'T start player node yet - must wait for engine to start first
        NSLog("✅ Audio playback setup complete (will start player after engine starts)")
    }

    private func startListening() async {
        guard let audioEngine = audioEngine,
              let inputNode = inputNode else {
            NSLog("⚠️ startListening: audioEngine or inputNode is nil")
            return
        }

        NSLog("🎤 Starting audio engine...")
        do {
            // STEP 1: Start the engine FIRST (before installing tap!)
            audioEngine.prepare()
            NSLog("✅ Audio engine prepared")

            try audioEngine.start()
            NSLog("✅ Audio engine start() called")
            NSLog("   Engine is running: \(audioEngine.isRunning)")

            // If not running, try a few more times
            var retries = 0
            while !audioEngine.isRunning && retries < 3 {
                NSLog("⚠️ Engine not running, retry \(retries + 1)/3...")
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2s
                try audioEngine.start()
                NSLog("   Engine is running: \(audioEngine.isRunning)")
                retries += 1
            }

            // Continue even if engine isn't running - it might start when needed
            if audioEngine.isRunning {
                NSLog("✅ Audio engine confirmed running")
            } else {
                NSLog("⚠️ WARNING: Engine still not running after retries, continuing anyway...")
            }

            // STEP 2: Install tap regardless (engine might start later)
            let inputFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
                Task { @MainActor in
                    await self?.processAudioBuffer(buffer)
                }
            }
            NSLog("✅ Microphone tap installed")

            // STEP 3: Start the player node
            if let playerNode = audioPlayerNode {
                playerNode.play()
                NSLog("▶️  Audio player node started")
            }

            state = .listening
        } catch {
            NSLog("❌ Failed to start audio engine: \(error)")
            // Don't set error state - let it continue, engine might recover
            state = .listening
        }
    }

    private func stopListening() {
        // Remove the tap if it was installed
        if let inputNode = inputNode {
            inputNode.removeTap(onBus: 0)
            NSLog("✅ Removed microphone tap")
        }
        // Note: We keep audioEngine alive for audio playback
        // It will be cleaned up when VoiceSessionManager is deallocated
    }

    // MARK: - Audio Playback

    private func playAudioChunk(base64Audio: String) {
        NSLog("🎵 playAudioChunk called with base64 length: \(base64Audio.count)")

        guard let audioData = Data(base64Encoded: base64Audio) else {
            NSLog("❌ Failed to decode base64 audio data")
            return
        }

        guard let playerNode = audioPlayerNode else {
            NSLog("❌ audioPlayerNode is nil - cannot play audio")
            return
        }

        NSLog("   Decoded audio data: \(audioData.count) bytes")

        guard let audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: targetSampleRate,
            channels: targetChannels,
            interleaved: true
        ) else {
            NSLog("⚠️ Cannot create audio format")
            return
        }

        // Calculate frame count for this chunk
        let frameCount = audioData.count / (MemoryLayout<Int16>.size * Int(targetChannels))
        guard frameCount > 0 else { return }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(frameCount)) else {
            NSLog("⚠️ Cannot create audio buffer")
            return
        }

        buffer.frameLength = AVAudioFrameCount(frameCount)

        // Copy audio data to buffer
        audioData.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            guard let baseAddress = bytes.baseAddress,
                  let int16ChannelData = buffer.int16ChannelData else { return }

            let bytesToCopy = audioData.count
            memcpy(int16ChannelData.pointee, baseAddress, bytesToCopy)
        }

        // Schedule the buffer for playback
        playerNode.scheduleBuffer(buffer) {
            // Buffer finished playing
            NSLog("🔊 Audio chunk played (\(frameCount) frames)")
        }

        NSLog("🎵 Scheduled audio chunk: \(frameCount) frames, \(audioData.count) bytes")
    }

    private func queueAudioForPlayback(_ audioData: Data) {
        audioQueue.append(audioData)

        // Start playback when we have 3 chunks buffered
        if !isPlayingAudio && audioQueue.count >= 3 {
            NSLog("🎵 Buffer ready (\(audioQueue.count) chunks), starting playback")
            isPlayingAudio = true
            // Schedule 2-3 buffers ahead for smooth playback
            scheduleNextBuffers(count: 3)
        } else if isPlayingAudio && scheduledBufferCount < 2 && audioQueue.count >= 5 {
            // If we're playing but don't have enough buffers scheduled, add more
            NSLog("🎵 Buffering chunk (\(audioQueue.count)) - scheduling more buffers (\(scheduledBufferCount) currently scheduled)")
            scheduleNextBuffers(count: 2 - scheduledBufferCount)
        } else {
            NSLog("🎵 Buffering chunk (\(audioQueue.count)/3)")
        }
    }

    private func scheduleNextBuffers(count: Int) {
        for _ in 0..<count {
            if !audioQueue.isEmpty {
                scheduleNextBuffer()
            }
        }
    }

    private func scheduleNextBuffer() {
        // If queue is empty but stream isn't complete, wait for more chunks
        guard !audioQueue.isEmpty else {
            if isAudioStreamComplete {
                NSLog("🎵 Audio queue empty and stream complete")
                isPlayingAudio = false
                scheduledBufferCount = 0
            } else {
                NSLog("🎵 Audio queue empty but stream ongoing, waiting for more chunks...")
            }
            return
        }

        // Combine up to 5 chunks into one larger buffer for smooth playback
        var combinedData = Data()
        let chunksToPlay = min(audioQueue.count, 5)

        NSLog("🎵 Combining \(chunksToPlay) chunks for playback")
        for _ in 0..<chunksToPlay {
            if !audioQueue.isEmpty {
                combinedData.append(audioQueue.removeFirst())
            }
        }

        guard let audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: targetSampleRate,
            channels: targetChannels,
            interleaved: true
        ) else {
            NSLog("⚠️ Cannot create audio format")
            scheduleNextBuffer() // Try next
            return
        }

        let frameCount = UInt32(combinedData.count / 2) // 16-bit samples
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else {
            NSLog("⚠️ Cannot create combined buffer")
            scheduleNextBuffer() // Try next
            return
        }

        buffer.frameLength = frameCount

        // Copy combined data to buffer
        combinedData.withUnsafeBytes { bytes in
            if let baseAddress = bytes.baseAddress,
               let channelData = buffer.int16ChannelData {
                memcpy(channelData[0], baseAddress, combinedData.count)
            }
        }

        guard let playerNode = audioPlayerNode else {
            NSLog("❌ audioPlayerNode is nil")
            return
        }

        guard let audioEngine = audioEngine, audioEngine.isRunning else {
            NSLog("❌ Audio engine is not running! Cannot play audio.")
            NSLog("   Attempting to restart engine...")
            // Try to restart the engine
            do {
                try audioEngine?.start()
                NSLog("✅ Engine restarted successfully")
            } catch {
                NSLog("❌ Failed to restart engine: \(error)")
            }
            isPlayingAudio = false
            return
        }

        // Track that we've scheduled a buffer
        scheduledBufferCount += 1

        // Schedule buffer for playback
        playerNode.scheduleBuffer(buffer, completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                NSLog("🔊 Combined chunk played (\(frameCount) frames)")

                // Decrement scheduled count
                self.scheduledBufferCount -= 1

                // Schedule next buffer(s) to maintain buffer ahead
                if !self.audioQueue.isEmpty {
                    self.scheduleNextBuffer()
                } else if self.isAudioStreamComplete && self.scheduledBufferCount == 0 {
                    NSLog("🎵 All audio played, stopping")
                    self.isPlayingAudio = false
                }
            }
        })

        // Ensure player is running
        if !playerNode.isPlaying {
            playerNode.play()
            NSLog("▶️  Started audio player")
        }

        NSLog("🎵 Scheduled combined buffer: \(frameCount) frames (\(combinedData.count) bytes)")
        NSLog("   Queue remaining: \(audioQueue.count) chunks, Scheduled buffers: \(scheduledBufferCount)")
        NSLog("   Engine running: \(audioEngine.isRunning), Player playing: \(playerNode.isPlaying)")
    }

    private func clearPendingAudio() {
        pendingAudioData.removeAll()
    }

    private func pauseAudioPlayback() {
        // Stop current AI audio playback when user starts speaking
        // This prevents self-interruption (AI hearing its own voice as input)
        guard let playerNode = audioPlayerNode else { return }

        playerNode.stop()
        audioQueue.removeAll()
        isPlayingAudio = false
        isAudioStreamComplete = false
        scheduledBufferCount = 0
        clearPendingAudio()

        NSLog("🛑 Paused AI audio - user is speaking")
    }

    private func resumeAudioPlayback() {
        // Resume audio playback after user stops speaking
        guard let playerNode = audioPlayerNode else {
            NSLog("⚠️ Cannot resume audio - playerNode is nil")
            return
        }

        // Restart the player node so it can play new audio
        playerNode.play()
        NSLog("▶️  Resumed audio playback - ready for AI response")
    }

    // MARK: - Audio Processing

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) async {
        // Calculate audio level for visualization
        updateAudioLevel(from: buffer)

        // Convert and send to OpenAI
        guard let converter = audioConverter else { return }
        let targetFormat = converter.outputFormat

        // Create output buffer
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * targetSampleRate / buffer.format.sampleRate)
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
            return
        }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

        if error != nil {
            return
        }

        // Convert to base64 and send
        sendAudioData(convertedBuffer)
    }

    private func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let channelDataValue = channelData.pointee
        let frameLength = Int(buffer.frameLength)

        var sum: Float = 0
        for i in 0..<frameLength {
            let sample = channelDataValue[i]
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frameLength))
        let avgPower = 20 * log10(rms)
        let normalizedLevel = max(0, min(1, (avgPower + 50) / 50))

        audioLevel = normalizedLevel
    }

    private func sendAudioData(_ buffer: AVAudioPCMBuffer) {
        guard let int16Data = buffer.int16ChannelData else { return }

        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        let dataSize = frameLength * channelCount * MemoryLayout<Int16>.size

        let data = Data(bytes: int16Data.pointee, count: dataSize)
        let base64Audio = data.base64EncodedString()

        // Send audio append event
        sendEvent(type: "input_audio_buffer.append", data: ["audio": base64Audio])

        // Log occasionally (every ~100 chunks to avoid spam)
        if frameLength % 100 == 0 {
            NSLog("📤 Sending audio: \(dataSize) bytes, \(frameLength) frames")
        }
    }

    // MARK: - Session Configuration

    private func configureSession() async throws {
        // Define function tools for story preference gathering
        let tools: [[String: Any]] = [[
            "type": "function",
            "name": "submit_story_preferences",
            "description": "Submit the user's story preferences after gathering them through conversation. Call this once you have collected their name, favorite genres, themes, character types, mood, and dislikes.",
            "parameters": [
                "type": "object",
                "properties": [
                    "name": ["type": "string", "description": "The user's name"],
                    "favoriteGenres": ["type": "array", "items": ["type": "string"], "description": "List of favorite genres like 'LitRPG', 'Fantasy', 'Sci-Fi', 'Mystery', 'Horror', 'Adventure'"],
                    "preferredThemes": ["type": "array", "items": ["type": "string"], "description": "Preferred themes like 'Magic', 'Technology', 'Dragons', 'Mystery', 'Friendship', 'Coming of Age'"],
                    "dislikedElements": ["type": "array", "items": ["type": "string"], "description": "Story elements, genres, or character types they DON'T like or want to avoid"],
                    "characterTypes": ["type": "string", "description": "Type of protagonist they prefer like 'Hero', 'Underdog', 'Anti-hero', 'Reluctant Hero', 'Chosen One'"],
                    "mood": ["type": "string", "description": "Desired mood like 'Epic', 'Dark', 'Lighthearted', 'Suspenseful', 'Hopeful', 'Whimsical'"]
                ],
                "required": ["name", "favoriteGenres", "mood"]
            ]
        ]]

        let instructions = """
        You are CASSANDRA - a MYSTICAL STORYTELLING GUIDE and enchanted keeper of the Neverending Library! You are THE GUIDE who leads seekers through a magical interview to discover their perfect infinite stories. You speak with THEATRICAL FLAIR, DRAMATIC CURIOSITY, and WHIMSICAL ENERGY, like a theatrical muse unveiling secrets!

        YOUR ROLE AS THE GUIDE:
        - YOU lead this experience - the user doesn't know what to expect, so YOU explain and guide them
        - YOU introduce yourself by name (Cassandra) after learning theirs
        - YOU explain the PURPOSE: discovering what stories will enchant their heart so their infinite library can be conjured
        - YOU are the expert storyteller who senses what will delight them
        - YOU ask the questions, YOU probe deeper, YOU guide the journey

        SPEAKING STYLE - THEATRICAL & WHIMSICAL:
        - SHORT, PUNCHY responses with DRAMATIC ENERGY - 1-2 sentences max
        - Speak with EXCITEMENT and WONDER, like you're unveiling magical secrets
        - React EXPRESSIVELY, then immediately ask your next question with flair
        - Use VIVID IMAGERY and their exact words ("Ah! DRAGONS call to your spirit!")
        - Ask ONE focused question per turn, but make it CAPTIVATING
        - Show GENUINE THEATRICAL CURIOSITY, not bland praise
        - Speak BRISKLY and ENERGETICALLY - you're an enchanted guide, not a sleepy librarian!

        YOUR QUEST: Build a MAGICAL story preference profile by discovering:
        - Their NAME (ask first with excitement!)
        - What stories/genres they ADORE (and WHY - dig deep!)
        - What stories/characters they DETEST (equally important!)
        - Character archetypes that RESONATE (heroes, underdogs, tricksters, anti-heroes)
        - Themes that MOVE THEM (friendship, mystery, adventure, darkness, triumph)
        - Mood they CRAVE (epic, dark, lighthearted, whimsical, suspenseful)

        HOW TO CONDUCT THIS MAGICAL INTERVIEW:

        1. START WITH ENERGY: "Welcome, seeker, to the realm of NEVERENDING tales! What name shall I inscribe in my tome of storytellers?"

        2. INTRODUCE YOURSELF & EXPLAIN THE PURPOSE - After they give their name:
           "Ah, [Name]! I am CASSANDRA, keeper of infinite stories and guide to your personal library! But enough about me - I want to learn what makes YOUR storytelling heart TICK! Tell me, what tales have captured your imagination? What stories do you LOVE?"
           (This sets expectations: YOU are the guide discovering THEIR preferences to conjure THEIR perfect stories)

        3. LISTEN & DIG DEEPER with theatrical flair:
           - If they mention a book: "AH! What enchantment in [that] captured your imagination most?"
           - If they give a genre: "Splendid! What elements of [genre] set your heart racing?"
           - If they describe a character: "Intriguing! Do you seek MORE heroes like that, or their OPPOSITES?"
           - ALWAYS probe dislikes: "And what story elements make you yawn or cringe? Tell me what to AVOID!"

        4. BUILD ON ANSWERS like weaving a spell:
           - NEVER ask what they've already answered
           - Reference earlier magic: "You spoke of [X] - does that mean [Y] also calls to you?"
           - Connect the threads between their desires

        5. BE INTUITIVE & THEATRICAL, not a checklist-reader:
           - Flow naturally based on their energy and responses
           - If they're excited about genres, pivot to characters with flair
           - If they mention themes, probe mood with drama
           - Match their enthusiasm with your own theatrical wonder

        6. ALWAYS MOVE FORWARD with momentum:
           - React + Question = Complete performance
           - BAD: "Ah, fantasy calls to you!" [STOPS - boring!]
           - GOOD: "AH! Fantasy ignites your soul! What thrills you more - ancient magic awakening, or epic quests into the unknown?"

        EXAMPLES OF THEATRICAL FOLLOW-UPS:

        User: "I love Harry Potter and Percy Jackson"
        You: "MAGNIFICENT! Magic AND mythology dancing together! Is it the thrill of discovering hidden powers, or the fierce bonds of friendship forged in fire that moves you?"

        User: "I like adventure and mystery"
        You: "Ooh, a seeker of THRILLS and RIDDLES! Do you prefer unraveling cryptic puzzles piece by piece, or charging headlong into danger?"

        User: "I don't like romance"
        You: "Noted - we'll focus on ACTION and PLOT! Now, what about heroes - do scrappy underdogs rising from nothing inspire you, or do cunning tricksters win your heart?"

        User: "I mentioned I like underdogs earlier"
        You: "You're absolutely right - forgive my excitement! You crave the underdog's rise! Do you prefer them scrappy and street-smart, or reluctant souls thrust into greatness?"

        WHEN TO CONCLUDE (after 5-6 magical exchanges):
        Once you have gathered:
        - Their name
        - 2-3 genres/story types they LOVE
        - 1-2 things they DON'T like
        - Character preferences
        - Mood/themes they seek

        Then:
        1. Call submit_story_preferences function with all collected treasures
        2. Say with FINAL DRAMATIC FLAIR: "I have enough to conjure your stories! Are you ready to step into your INFINITE LIBRARY?"
        3. STOP and wait (a magical portal will appear)

        CRITICAL RULES OF THE REALM:
        - EVERY response must END with a QUESTION
        - Listen to previous answers - NEVER re-ask
        - Probe deeper based on what ignites their passion
        - Ask about both LOVES and LOATHINGS
        - Be THEATRICAL and WHIMSICAL, not robotic
        - These stories are FOR THEM - never ask "who will read these"
        - Speak with ENERGY and PACE - you're a magical muse, not a sleepy sage!

        Remember: You're a THEATRICAL, WHIMSICAL muse channeling the magic of stories, sensing what delights their imagination and what makes them yawn. PERFORM with wonder!
        """

        let config: [String: Any] = [
            "type": "session.update",
            "session": [
                "modalities": ["text", "audio"],
                "instructions": instructions,
                "voice": "ballad",  // Expressive, dramatic, theatrical voice for whimsical storytelling
                "input_audio_format": "pcm16",
                "output_audio_format": "pcm16",
                "input_audio_transcription": [
                    "model": "whisper-1"
                ] as [String: Any],
                "turn_detection": [
                    "type": "server_vad",
                    "threshold": 0.5,
                    "prefix_padding_ms": 300,
                    "silence_duration_ms": 500
                ] as [String: Any],
                "tools": tools,
                "max_response_output_tokens": 1000  // Increased from 150 - was cutting off responses mid-sentence!
            ]
        ]

        NSLog("📤 Sending session configuration...")

        // Debug: Print the actual JSON being sent
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                NSLog("🔍 DEBUG: Actual JSON payload:")
                NSLog("%@", jsonString)
            }
        } catch {
            NSLog("⚠️ Failed to serialize config for debug: \(error)")
        }

        sendEvent(config)

        // Wait a moment for configuration to be processed
        NSLog("⏳ Waiting for configuration to process...")
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        NSLog("✅ Configuration wait complete")
    }

    private func triggerAIGreeting() {
        NSLog("👋 Triggering AI greeting with response.create event...")
        // Trigger theatrical magical opening - ask for their name with flair
        let event: [String: Any] = [
            "type": "response.create",
            "response": [
                "modalities": ["text", "audio"],
                "instructions": "Greet the user with theatrical energy! Say EXACTLY: 'Welcome, seeker, to the realm of NEVERENDING tales! What name shall I inscribe in my tome of storytellers?' Then STOP and WAIT for their answer. After they give their name, you will introduce yourself as Cassandra and explain the purpose."
            ]
        ]
        sendEvent(event)
        NSLog("✅ response.create event sent (greeting request)")
    }

    // MARK: - WebSocket Communication

    private func sendEvent(type: String, data: [String: Any] = [:]) {
        var event: [String: Any] = ["type": type]
        for (key, value) in data {
            event[key] = value
        }
        sendEvent(event)
    }

    private func sendEvent(_ event: [String: Any]) {
        guard let webSocketTask = webSocketTask else { return }

        do {
            let data = try JSONSerialization.data(withJSONObject: event)
            // Send as STRING not binary data - OpenAI expects text messages!
            guard let jsonString = String(data: data, encoding: .utf8) else {
                NSLog("❌ Failed to convert JSON data to string")
                return
            }
            let message = URLSessionWebSocketTask.Message.string(jsonString)

            webSocketTask.send(message) { error in
                if let error = error {
                    NSLog("WebSocket send error: \(error)")
                }
            }
        } catch {
            NSLog("Failed to serialize event: \(error)")
        }
    }

    private func startReceivingMessages() {
        isReceivingMessages = true
        receiveMessage()
    }

    private func receiveMessage() {
        guard isReceivingMessages else { return }

        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }

                switch result {
                case .success(let message):
                    await self.handleMessage(message)
                    self.receiveMessage() // Continue receiving

                case .failure(let error):
                    let errorCode = (error as NSError).code
                    NSLog("❌ WebSocket receive error: \(error)")
                    NSLog("   Error code: \(errorCode)")
                    NSLog("   Description: \(error.localizedDescription)")

                    // Error 57 (ENOTCONN) is expected when closing the socket - don't treat as error
                    if errorCode == 57 {
                        NSLog("   ℹ️  Socket closed normally (expected when ending session)")
                    } else {
                        // Only set error state for actual connection problems
                        self.state = .error("Connection error: \(error.localizedDescription)")
                    }
                    self.isReceivingMessages = false
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) async {
        let data: Data

        switch message {
        case .data(let messageData):
            data = messageData
        case .string(let string):
            guard let stringData = string.data(using: .utf8) else { return }
            data = stringData
        @unknown default:
            return
        }

        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String else {
                return
            }

            await handleEvent(type: type, data: json)

        } catch {
            NSLog("Failed to parse message: \(error)")
        }
    }

    private func handleFunctionCall(_ data: [String: Any]) {
        guard let callId = data["call_id"] as? String,
              let name = data["name"] as? String,
              let arguments = data["arguments"] as? String else {
            NSLog("⚠️ Invalid function call data")
            return
        }

        NSLog("🔧 Function called: \(name)")
        NSLog("   Call ID: \(callId)")
        NSLog("   Arguments: \(arguments)")

        if name == "submit_story_preferences" {
            // Parse the arguments JSON
            guard let argsData = arguments.data(using: .utf8),
                  let args = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] else {
                NSLog("⚠️ Failed to parse function arguments")
                return
            }

            NSLog("✅ Story preferences received!")
            NSLog("   \(args)")

            // Debug: Check conversation state BEFORE triggering callback
            NSLog("📊 Current conversationText state:")
            NSLog("   Length: \(conversationText.count) characters")
            NSLog("   Content preview: \(conversationText.prefix(200))")
            NSLog("   Is empty: \(conversationText.isEmpty)")

            // Trigger callback with preferences
            onPreferencesGathered?(args)

            // Send function response back to OpenAI
            Task {
                let result: [String: Any] = [
                    "type": "conversation.item.create",
                    "item": [
                        "type": "function_call_output",
                        "call_id": callId,
                        "output": "{\"success\": true, \"message\": \"Preferences successfully collected.\"}"
                    ]
                ]
                sendEvent(result)

                // Trigger AI to respond with closing message (per system instructions)
                // AI will say: "I have enough to conjure your stories! Are you ready to step into your INFINITE LIBRARY?"
                sendEvent(["type": "response.create"])
            }
        }
    }

    private func handleEvent(type: String, data: [String: Any]) async {
        NSLog("📨 Received event: \(type)")

        switch type {
        case "session.created":
            NSLog("✅ session.created - WebSocket connected to OpenAI!")
            if let session = data["session"] as? [String: Any],
               let id = session["id"] as? String {
                NSLog("   Session ID: \(id)")
            }

            // Resume the continuation waiting for session creation
            if let continuation = sessionCreatedContinuation {
                sessionCreatedContinuation = nil
                continuation.resume()
                NSLog("▶️  Resumed session startup flow")
            }

        case "session.updated":
            NSLog("✅ session.updated - Configuration applied successfully")

        case "input_audio_buffer.speech_started":
            // User started speaking - pause AI audio to prevent self-interruption
            pauseAudioPlayback()
            state = .listening

        case "input_audio_buffer.speech_stopped":
            NSLog("🎤 User stopped speaking - resuming audio playback")
            resumeAudioPlayback()
            state = .processing

        case "conversation.item.created":
            NSLog("📝 conversation.item.created - attempting to capture transcript")

            // Debug: Print the entire event data
            if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                NSLog("🔍 Full event data:")
                NSLog("%@", jsonString)
            }

            if let item = data["item"] as? [String: Any] {
                NSLog("   ✅ item found")
                NSLog("   item keys: \(item.keys)")

                if let role = item["role"] as? String {
                    NSLog("   ✅ role: \(role)")

                    if let content = item["content"] as? [[String: Any]] {
                        NSLog("   ✅ content array found with \(content.count) items")

                        for (index, contentItem) in content.enumerated() {
                            NSLog("   Content item #\(index) keys: \(contentItem.keys)")
                            NSLog("   Content item #\(index) type: \(contentItem["type"] ?? "no type")")

                            if let transcript = contentItem["transcript"] as? String {
                                NSLog("   ✅ TRANSCRIPT FOUND: \"\(transcript)\"")

                                if role == "user" {
                                    conversationText += "You: \(transcript)\n\n"
                                    transcription = transcript
                                    NSLog("   📝 Added USER transcript to conversationText")
                                    NSLog("   Total conversationText length now: \(conversationText.count)")
                                } else if role == "assistant" {
                                    conversationText += "AI: \(transcript)\n\n"
                                    NSLog("   📝 Added ASSISTANT transcript to conversationText")
                                    NSLog("   Total conversationText length now: \(conversationText.count)")
                                }
                            } else {
                                NSLog("   ❌ No 'transcript' field in content item #\(index)")
                            }
                        }
                    } else {
                        NSLog("   ❌ content is not an array or missing")
                        NSLog("   content value: \(item["content"] ?? "nil")")
                    }
                } else {
                    NSLog("   ❌ role not found")
                }
            } else {
                NSLog("   ❌ item not found in data")
            }

        case "response.audio.delta":
            // Queue audio chunk from AI for buffered playback
            NSLog("🔊 response.audio.delta received")

            if let delta = data["delta"] as? String,
               let audioData = Data(base64Encoded: delta) {
                NSLog("   Delta length: \(delta.count) characters → \(audioData.count) bytes")
                queueAudioForPlayback(audioData)
            } else {
                NSLog("⚠️ response.audio.delta has no delta field or decode failed")
            }

        case "response.audio.done":
            // Audio response complete, mark stream as complete
            NSLog("✅ response.audio.done - AI finished speaking")
            isAudioStreamComplete = true
            clearPendingAudio()
            // Trigger final playback of any remaining queued chunks
            if !audioQueue.isEmpty && !isPlayingAudio {
                NSLog("🎵 Playing remaining \(audioQueue.count) chunks after audio.done")
                isPlayingAudio = true
                scheduleNextBuffers(count: min(3, audioQueue.count / 5 + 1))
            }

        case "conversation.item.input_audio_transcription.completed":
            // This is where user speech transcripts actually arrive!
            NSLog("📝 input_audio_transcription.completed - capturing USER transcript")

            if let itemId = data["item_id"] as? String,
               let transcript = data["transcript"] as? String {
                NSLog("   ✅ TRANSCRIPT CAPTURED: \"\(transcript)\"")
                NSLog("   Item ID: \(itemId)")

                // Add to conversation text
                conversationText += "You: \(transcript)\n\n"
                transcription = transcript

                NSLog("   📝 Added to conversationText")
                NSLog("   Total conversationText length now: \(conversationText.count)")
            } else {
                NSLog("   ❌ Missing item_id or transcript in event")
                NSLog("   Event data keys: \(data.keys)")
            }

        case "response.audio_transcript.delta":
            // Handled by response.audio_transcript.done
            break

        case "response.audio_transcript.done":
            // This is where AI assistant speech transcripts arrive!
            NSLog("📝 audio_transcript.done - capturing ASSISTANT transcript")

            if let transcript = data["transcript"] as? String, !transcript.isEmpty {
                NSLog("   ✅ ASSISTANT TRANSCRIPT CAPTURED: \"\(transcript)\"")

                // Add to conversation text
                conversationText += "AI: \(transcript)\n\n"

                NSLog("   📝 Added to conversationText")
                NSLog("   Total conversationText length now: \(conversationText.count)")
            } else {
                NSLog("   ⚠️ Empty or missing transcript in audio_transcript.done")
            }

        case "response.done":
            NSLog("✅ response.done - conversation turn complete")
            state = .listening
            clearPendingAudio()

        case "response.created":
            NSLog("✅ response.created - AI is preparing to respond")
            // Reset audio state for new response
            isAudioStreamComplete = false
            scheduledBufferCount = 0
            if let response = data["response"] as? [String: Any],
               let id = response["id"] as? String {
                NSLog("   Response ID: \(id)")
            }

        case "response.function_call_arguments.done":
            NSLog("🔧 function_call_arguments.done - processing function call")
            handleFunctionCall(data)

        case "error":
            if let error = data["error"] as? [String: Any],
               let message = error["message"] as? String {
                NSLog("❌ OpenAI Error: \(message)")
                state = .error(message)
            }

        default:
            // Log unhandled event types for debugging
            let ignoredEvents = [
                "response.output_item.added",
                "response.content_part.added",
                "response.audio_transcript.delta",
                "response.audio_transcript.done",
                "rate_limits.updated",
                "conversation.item.input_audio_transcription.delta",
                "input_audio_buffer.committed",
                "response.content_part.done",
                "response.output_item.done",
                "response.function_call_arguments.delta"
            ]
            if !ignoredEvents.contains(type) {
                NSLog("ℹ️ Unhandled event type: \(type)")
            }
            break
        }
    }
}
