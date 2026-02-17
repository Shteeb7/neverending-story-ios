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

// MARK: - Interview Types

enum InterviewType: Equatable {
    case onboarding                                         // First-time user
    case returningUser(context: ReturningUserContext)     // Wants new story
    case premiseRejection(context: PremiseRejectionContext) // Rejected all premises
    case bookCompletion(context: BookCompletionContext)   // Finished a book
    case bugReport(context: BugReportContext)             // Report a bug
    case suggestion(context: SuggestionContext)           // Suggest a feature
}

struct ReturningUserContext: Equatable {
    let userName: String
    let previousStoryTitles: [String]  // titles of books they've read
    let preferredGenres: [String]
    let discardedPremises: [(title: String, description: String, tier: String)]  // recently rejected premises

    static func == (lhs: ReturningUserContext, rhs: ReturningUserContext) -> Bool {
        return lhs.userName == rhs.userName &&
               lhs.previousStoryTitles == rhs.previousStoryTitles &&
               lhs.preferredGenres == rhs.preferredGenres
    }
}

struct PremiseRejectionContext: Equatable {
    let userName: String
    let discardedPremises: [(title: String, description: String, tier: String)]
    let existingPreferences: [String: Any]?  // What the first interview gathered (genres, themes, etc.)
    let hasReadBooks: Bool                    // true if they've completed any books before

    static func == (lhs: PremiseRejectionContext, rhs: PremiseRejectionContext) -> Bool {
        // Simple equality check ignoring existingPreferences since [String: Any] isn't Equatable
        return lhs.userName == rhs.userName &&
               lhs.hasReadBooks == rhs.hasReadBooks
    }
}

struct BookCompletionContext: Equatable {
    let userName: String
    let storyTitle: String
    let storyGenre: String?
    let premiseTier: String?
    let protagonistName: String?
    let centralConflict: String?
    let themes: [String]
    let lingeredChapters: [(chapter: Int, minutes: Int)]
    let skimmedChapters: [Int]
    let rereadChapters: [(chapter: Int, sessions: Int)]
    let checkpointFeedback: [(checkpoint: String, response: String)]
    let bookNumber: Int

    static func == (lhs: BookCompletionContext, rhs: BookCompletionContext) -> Bool {
        return lhs.userName == rhs.userName &&
               lhs.storyTitle == rhs.storyTitle &&
               lhs.storyGenre == rhs.storyGenre &&
               lhs.premiseTier == rhs.premiseTier &&
               lhs.protagonistName == rhs.protagonistName &&
               lhs.centralConflict == rhs.centralConflict &&
               lhs.themes == rhs.themes &&
               lhs.skimmedChapters == rhs.skimmedChapters &&
               lhs.bookNumber == rhs.bookNumber
    }
}

struct BugReportContext: Equatable {
    let userName: String?
    let currentScreen: String
    let metadata: [String: Any]?  // App state metadata

    static func == (lhs: BugReportContext, rhs: BugReportContext) -> Bool {
        return lhs.userName == rhs.userName &&
               lhs.currentScreen == rhs.currentScreen
    }
}

struct SuggestionContext: Equatable {
    let userName: String?
    let currentScreen: String

    static func == (lhs: SuggestionContext, rhs: SuggestionContext) -> Bool {
        return lhs.userName == rhs.userName &&
               lhs.currentScreen == rhs.currentScreen
    }
}

// MARK: - Voice Session Manager

@MainActor
class VoiceSessionManager: ObservableObject {
    @Published var state: VoiceSessionState = .idle
    @Published var audioLevel: Float = 0.0
    @Published var transcription: String = ""
    @Published var conversationText: String = "" // Full conversation for display
    @Published var isConversationComplete = false // Signals conversation end
    @Published var currentAudioRoute: String = "Speaker" // Current audio output device
    @Published var isUsingBluetooth: Bool = false // Whether Bluetooth audio is active

    var interviewType: InterviewType = .onboarding
    private var cachedGreeting: String? = nil // Cached greeting from backend

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
        // Safety: If a previous WebSocket exists, clean it up
        if webSocketTask != nil {
            NSLog("⚠️ VoiceSession: Previous WebSocket still exists - closing it")
            webSocketTask?.cancel(with: .goingAway, reason: nil)
            webSocketTask = nil
            isReceivingMessages = false
        }

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
        NSLog("🛑 Ending voice session - stopping all audio")

        // Stop microphone input
        stopListening()

        // IMPORTANT: Stop AI audio playback and clear buffer
        pauseAudioPlayback()

        // Stop the audio engine completely
        if let engine = audioEngine, engine.isRunning {
            engine.stop()
            NSLog("🔇 Audio engine stopped")
        }

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

        NSLog("✅ Voice session ended - all audio stopped, WebSocket closed")
    }

    // MARK: - Audio Route Management

    func updateAudioRouteInfo() {
        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs

        if let output = outputs.first {
            currentAudioRoute = output.portName
            isUsingBluetooth = output.portType == .bluetoothHFP ||
                              output.portType == .bluetoothA2DP ||
                              output.portType == .bluetoothLE
        } else {
            currentAudioRoute = "Unknown"
            isUsingBluetooth = false
        }

        NSLog("📱 Audio route: \(currentAudioRoute) (Bluetooth: \(isUsingBluetooth))")
    }

    func toggleAudioRoute() {
        let session = AVAudioSession.sharedInstance()

        do {
            if isUsingBluetooth {
                // Switch to speaker
                try session.overrideOutputAudioPort(.speaker)
                NSLog("🔊 Manually switched to speaker")
            } else {
                // Switch to Bluetooth if available
                if let btInput = session.availableInputs?.first(where: {
                    $0.portType == .bluetoothHFP || $0.portType == .bluetoothA2DP
                }) {
                    try session.overrideOutputAudioPort(.none) // Clear override
                    try session.setPreferredInput(btInput)
                    NSLog("🎧 Manually switched to Bluetooth: \(btInput.portName)")
                } else {
                    NSLog("⚠️ No Bluetooth devices available")
                }
            }

            // Update the published properties
            updateAudioRouteInfo()
        } catch {
            NSLog("❌ Failed to toggle audio route: \(error)")
        }
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
        // .default mode works better for speaker/Bluetooth routing than .voiceChat
        // .defaultToSpeaker: Routes to loudspeaker when no Bluetooth is connected
        // .allowBluetoothHFP: Enables Bluetooth HFP (Hands-Free Profile) for bidirectional audio with AirPods mic
        // .allowBluetoothA2DP: Routes to AirPods/Bluetooth with high-quality audio (takes priority over speaker)
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP, .allowBluetoothA2DP])
        try audioSession.setActive(true)

        // Observe audio route changes (e.g., AirPods connect/disconnect)
        NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { notification in
            guard let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let routeChangeReason = AVAudioSession.RouteChangeReason(rawValue: reason) else { return }

            NSLog("🔊 Audio route changed: \(routeChangeReason.rawValue)")

            let session = AVAudioSession.sharedInstance()
            let outputs = session.currentRoute.outputs

            // Log current route for debugging
            NSLog("   Current outputs: \(outputs.map { "\($0.portName) (\($0.portType.rawValue))" })")

            // Only auto-switch to Bluetooth if it was just inserted (user put AirPods IN their ears)
            // Don't switch if it's just connected but potentially sitting in a case
            if routeChangeReason == .newDeviceAvailable {
                NSLog("   New device available - iOS will route automatically based on user preference")
            } else if routeChangeReason == .oldDeviceUnavailable {
                // Bluetooth disconnected - fall back to speaker
                NSLog("   Device removed - falling back to speaker")
            }
        }

        // Smart audio routing: Default to speaker/mic unless Bluetooth is actively being used
        // Don't force Bluetooth just because it's connected - it might be in a case
        let currentOutputs = audioSession.currentRoute.outputs
        let isUsingBluetooth = currentOutputs.contains {
            $0.portType == .bluetoothHFP || $0.portType == .bluetoothA2DP || $0.portType == .bluetoothLE
        }

        if isUsingBluetooth {
            // Bluetooth is already the active route - respect that
            if let btInput = audioSession.availableInputs?.first(where: {
                $0.portType == .bluetoothHFP || $0.portType == .bluetoothA2DP
            }) {
                try? audioSession.setPreferredInput(btInput)
                NSLog("✅ Using Bluetooth (already active): \(btInput.portName)")
            }
        } else {
            // Use device speaker/mic (Bluetooth is connected but not actively being used)
            NSLog("✅ Using device speaker/mic (Bluetooth available but not active)")
        }

        // Debug: Log current audio route for verification
        NSLog("🔊 Current route outputs: \(audioSession.currentRoute.outputs.map { "\($0.portName) (\($0.portType.rawValue))" })")
        NSLog("🎤 Current route inputs: \(audioSession.currentRoute.inputs.map { "\($0.portName) (\($0.portType.rawValue))" })")

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

        // Update audio route info for UI (we're already on MainActor)
        DispatchQueue.main.async {
            self.updateAudioRouteInfo()
        }
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
            Task { @MainActor in
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
        switch interviewType {
        case .onboarding:
            try await configureOnboardingSession()
        case .returningUser(let context):
            try await configureReturningUserSession(context: context)
        case .premiseRejection(let context):
            try await configurePremiseRejectionSession(context: context)
        case .bookCompletion(let context):
            try await configureCompletionSession(context: context)
        case .bugReport(let context):
            try await configureBugReportSession(context: context)
        case .suggestion(let context):
            try await configureSuggestionSession(context: context)
        }
    }

    // MARK: - Onboarding Session Configuration

    private func configureOnboardingSession() async throws {
        // EXPANDED function tool with new preference fields
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
                    "mood": ["type": "string", "description": "Desired mood like 'Epic', 'Dark', 'Lighthearted', 'Suspenseful', 'Hopeful', 'Whimsical'"],
                    "ageRange": ["type": "string", "description": "Age of the reader - determines complexity and maturity level. Options: 'child' (8-12), 'teen' (13-17), 'young-adult' (18-25), 'adult' (25+). Keep for backward compatibility but readingLevel is now preferred."],
                    "emotionalDrivers": ["type": "array", "items": ["type": "string"], "description": "WHY they read (e.g. 'escape', 'feel deeply', 'intellectual challenge', 'thrill')"],
                    "belovedStories": ["type": "array", "items": ["type": "string"], "description": "Books, series, movies, or shows the reader mentioned loving. These determine reading level."],
                    "readingLevel": ["type": "string", "enum": ["early_reader", "middle_grade", "upper_middle_grade", "young_adult", "new_adult", "adult"], "description": "Derived from their favorite books/media AND their age. Use the anchor books table to calibrate: Magic Tree House/Wimpy Kid = early_reader, Percy Jackson/Harry Potter = middle_grade, Hunger Games/Eragon = upper_middle_grade, Six of Crows/Throne of Glass = young_adult, ACOTAR/Fourth Wing = new_adult, Sanderson/adult fantasy = adult"],
                    "readingMotivation": ["type": "string", "description": "Natural language summary of what drives their reading"],
                    "discoveryTolerance": ["type": "string", "description": "'low' (comfort-seeker), 'medium' (balanced), or 'high' (adventurer)"],
                    "pacePreference": ["type": "string", "description": "'fast' or 'slow' or 'varied'"]
                ],
                "required": ["name", "favoriteGenres", "mood", "readingLevel"]
            ]
        ]]

        // Fetch system prompt from backend
        let instructions: String
        do {
            let result = try await APIManager.shared.getSystemPrompt(
                interviewType: "onboarding",
                medium: "voice",
                context: nil
            )
            instructions = result.prompt
            cachedGreeting = result.greeting
            NSLog("✅ Fetched system prompt from backend (\(instructions.count) chars)")
        } catch {
            NSLog("⚠️ Failed to fetch Prospero prompt from backend, using fallback: \(error)")
            instructions = "You are Prospero, a warm and theatrical master storyteller. Conduct this interview with genuine curiosity and charm. Ask about their name, age, favorite stories, and what they love about them. Extract their preferences through conversation, not forms."
            cachedGreeting = "Welcome, seeker, to the realm of MYTHWEAVER! Before I can summon the tales that await you — what name shall I inscribe in my tome?"
        }

        let config: [String: Any] = [
            "type": "session.update",
            "session": [
                "modalities": ["text", "audio"],
                "instructions": instructions,
                "voice": "ballad",
                "input_audio_format": "pcm16",
                "output_audio_format": "pcm16",
                "input_audio_transcription": [
                    "model": "whisper-1"
                ] as [String: Any],
                "turn_detection": [
                    "type": "semantic_vad",
                    "eagerness": "medium"
                ] as [String: Any],
                "input_audio_noise_reduction": [
                    "type": "near_field"
                ] as [String: Any],
                "tools": tools,
                "max_response_output_tokens": 1000
            ]
        ]

        NSLog("📤 Sending onboarding session configuration...")
        sendEvent(config)

        try await Task.sleep(nanoseconds: 1_000_000_000)
        NSLog("✅ Onboarding configuration complete")
    }

    // MARK: - Returning User Session Configuration

    private func configureReturningUserSession(context: ReturningUserContext) async throws {
        let tools: [[String: Any]] = [[
            "type": "function",
            "name": "submit_new_story_request",
            "description": "Submit the user's request for a new story based on their current mood and direction.",
            "parameters": [
                "type": "object",
                "properties": [
                    "direction": ["type": "string", "description": "'comfort' (more of what they love), 'stretch' (something adjacent), 'wildcard' (surprise me), or 'specific' (they have a specific idea)"],
                    "moodShift": ["type": "string", "description": "What they're in the mood for now"],
                    "explicitRequest": ["type": "string", "description": "If they had a specific idea, capture it here"],
                    "newInterests": ["type": "string", "description": "Any new stories/genres they've mentioned since last time"]
                ],
                "required": ["direction"]
            ]
        ]]

        // Build context for backend prompt assembly
        let discardedPremises = context.discardedPremises.map { premise in
            ["title": premise.title, "description": premise.description, "tier": premise.tier]
        }

        let contextDict: [String: Any] = [
            "userName": context.userName,
            "previousStoryTitles": context.previousStoryTitles,
            "preferredGenres": context.preferredGenres,
            "discardedPremises": discardedPremises
        ]

        // Fetch system prompt from backend
        let instructions: String
        do {
            let result = try await APIManager.shared.getSystemPrompt(
                interviewType: "returning_user",
                medium: "voice",
                context: contextDict
            )
            instructions = result.prompt
            cachedGreeting = result.greeting
            NSLog("✅ Fetched returning_user system prompt from backend (\(instructions.count) chars)")
        } catch {
            NSLog("⚠️ Failed to fetch Prospero prompt from backend, using fallback: \(error)")
            let lastTitle = context.previousStoryTitles.last ?? "your last adventure"
            instructions = "You are Prospero. Welcome back \(context.userName)! You know this reader well. Ask what kind of story they want next - more of what they love, or something new?"
            cachedGreeting = "Ah, \(context.userName)! Back for more, I see. Fresh from \(lastTitle)! What calls to your spirit today — more of what you love, or shall I surprise you?"
        }

        let config: [String: Any] = [
            "type": "session.update",
            "session": [
                "modalities": ["text", "audio"],
                "instructions": instructions,
                "voice": "ballad",
                "input_audio_format": "pcm16",
                "output_audio_format": "pcm16",
                "input_audio_transcription": [
                    "model": "whisper-1"
                ] as [String: Any],
                "turn_detection": [
                    "type": "semantic_vad",
                    "eagerness": "medium"
                ] as [String: Any],
                "input_audio_noise_reduction": [
                    "type": "near_field"
                ] as [String: Any],
                "tools": tools,
                "max_response_output_tokens": 1000
            ]
        ]

        NSLog("📤 Sending returning user session configuration...")
        sendEvent(config)

        try await Task.sleep(nanoseconds: 1_000_000_000)
        NSLog("✅ Returning user configuration complete")
    }

    // MARK: - Premise Rejection Session Configuration

    private func configurePremiseRejectionSession(context: PremiseRejectionContext) async throws {
        // Use the same function tool as onboarding (full preference gathering)
        let tools: [[String: Any]] = [[
            "type": "function",
            "name": "submit_story_preferences",
            "description": "Submit the user's refined story preferences after diagnosing why the previous premises failed.",
            "parameters": [
                "type": "object",
                "properties": [
                    "name": ["type": "string", "description": "The user's name"],
                    "favoriteGenres": ["type": "array", "items": ["type": "string"], "description": "List of favorite genres like 'LitRPG', 'Fantasy', 'Sci-Fi', 'Mystery', 'Horror', 'Adventure'"],
                    "preferredThemes": ["type": "array", "items": ["type": "string"], "description": "Preferred themes like 'Magic', 'Technology', 'Dragons', 'Mystery', 'Friendship', 'Coming of Age'"],
                    "dislikedElements": ["type": "array", "items": ["type": "string"], "description": "Story elements, genres, or character types they DON'T like or want to avoid"],
                    "characterTypes": ["type": "string", "description": "Type of protagonist they prefer like 'Hero', 'Underdog', 'Anti-hero', 'Reluctant Hero', 'Chosen One'"],
                    "mood": ["type": "string", "description": "Desired mood like 'Epic', 'Dark', 'Lighthearted', 'Suspenseful', 'Hopeful', 'Whimsical'"],
                    "ageRange": ["type": "string", "description": "Age of the reader - determines complexity and maturity level. Options: 'child' (8-12), 'teen' (13-17), 'young-adult' (18-25), 'adult' (25+). Keep for backward compatibility but readingLevel is now preferred."],
                    "emotionalDrivers": ["type": "array", "items": ["type": "string"], "description": "WHY they read (e.g. 'escape', 'feel deeply', 'intellectual challenge', 'thrill')"],
                    "belovedStories": ["type": "array", "items": ["type": "string"], "description": "Books, series, movies, or shows the reader mentioned loving. These determine reading level."],
                    "readingLevel": ["type": "string", "enum": ["early_reader", "middle_grade", "upper_middle_grade", "young_adult", "new_adult", "adult"], "description": "Derived from their favorite books/media AND their age. Use the anchor books table to calibrate: Magic Tree House/Wimpy Kid = early_reader, Percy Jackson/Harry Potter = middle_grade, Hunger Games/Eragon = upper_middle_grade, Six of Crows/Throne of Glass = young_adult, ACOTAR/Fourth Wing = new_adult, Sanderson/adult fantasy = adult"],
                    "readingMotivation": ["type": "string", "description": "Natural language summary of what drives their reading"],
                    "discoveryTolerance": ["type": "string", "description": "'low' (comfort-seeker), 'medium' (balanced), or 'high' (adventurer)"],
                    "pacePreference": ["type": "string", "description": "'fast' or 'slow' or 'varied'"]
                ],
                "required": ["name", "favoriteGenres", "mood", "readingLevel"]
            ]
        ]]

        // Build context for backend prompt assembly
        let discardedPremises = context.discardedPremises.map { premise in
            ["title": premise.title, "description": premise.description]
        }

        var contextDict: [String: Any] = [
            "userName": context.userName,
            "discardedPremises": discardedPremises
        ]

        if let existingPrefs = context.existingPreferences {
            contextDict["existingPreferences"] = existingPrefs
        }

        // Fetch system prompt from backend
        let instructions: String
        do {
            let result = try await APIManager.shared.getSystemPrompt(
                interviewType: "premise_rejection",
                medium: "voice",
                context: contextDict
            )
            instructions = result.prompt
            cachedGreeting = result.greeting
            NSLog("✅ Fetched premise_rejection system prompt from backend (\(instructions.count) chars)")
        } catch {
            NSLog("⚠️ Failed to fetch Prospero prompt from backend, using fallback: \(error)")
            instructions = "You are Prospero. Welcome back \(context.userName). The stories I offered didn't resonate. Let's figure out what you're really looking for together."
            cachedGreeting = "\(context.userName)! You're back — and I'm GLAD. Those tales I conjured clearly weren't worthy of you. Help me understand what missed the mark, and I'll summon something far better."
        }

        let config: [String: Any] = [
            "type": "session.update",
            "session": [
                "modalities": ["text", "audio"],
                "instructions": instructions,
                "voice": "ballad",
                "input_audio_format": "pcm16",
                "output_audio_format": "pcm16",
                "input_audio_transcription": [
                    "model": "whisper-1"
                ] as [String: Any],
                "turn_detection": [
                    "type": "semantic_vad",
                    "eagerness": "medium"
                ] as [String: Any],
                "input_audio_noise_reduction": [
                    "type": "near_field"
                ] as [String: Any],
                "tools": tools,
                "max_response_output_tokens": 1000
            ]
        ]

        NSLog("📤 Sending premise rejection session configuration...")
        sendEvent(config)

        try await Task.sleep(nanoseconds: 1_000_000_000)
        NSLog("✅ Premise rejection configuration complete")
    }

    // MARK: - Book Completion Session Configuration

    private func configureCompletionSession(context: BookCompletionContext) async throws {
        let tools: [[String: Any]] = [[
            "type": "function",
            "name": "submit_completion_feedback",
            "description": "Submit the reader's feedback about the completed book.",
            "parameters": [
                "type": "object",
                "properties": [
                    "highlights": ["type": "array", "items": ["type": "string"], "description": "Moments/scenes they loved"],
                    "lowlights": ["type": "array", "items": ["type": "string"], "description": "Things that felt off or slow"],
                    "characterConnections": ["type": "string", "description": "Who they bonded with and why"],
                    "sequelDesires": ["type": "string", "description": "What they want in the next book"],
                    "satisfactionSignal": ["type": "string", "description": "Overall feeling (enthusiastic/satisfied/mixed/disappointed)"],
                    "preferenceUpdates": ["type": "string", "description": "Any shifts in taste revealed by the conversation"]
                ],
                "required": ["highlights", "sequelDesires", "satisfactionSignal"]
            ]
        ]]

        // Build context for backend prompt assembly
        let lingeredChapters = context.lingeredChapters.map { chapter in
            ["chapter": chapter.chapter, "minutes": chapter.minutes]
        }
        let rereadChapters = context.rereadChapters.map { chapter in
            ["chapter": chapter.chapter, "sessions": chapter.sessions]
        }
        let checkpointFeedback = context.checkpointFeedback.map { feedback in
            ["checkpoint": feedback.checkpoint, "response": feedback.response]
        }

        let contextDict: [String: Any] = [
            "userName": context.userName,
            "storyTitle": context.storyTitle,
            "bookNumber": context.bookNumber,
            "storyGenre": context.storyGenre ?? "",
            "premiseTier": context.premiseTier ?? "",
            "protagonistName": context.protagonistName ?? "",
            "centralConflict": context.centralConflict ?? "",
            "themes": context.themes,
            "lingeredChapters": lingeredChapters,
            "skimmedChapters": context.skimmedChapters,
            "rereadChapters": rereadChapters,
            "checkpointFeedback": checkpointFeedback
        ]

        // Fetch system prompt from backend
        let instructions: String
        do {
            let result = try await APIManager.shared.getSystemPrompt(
                interviewType: "book_completion",
                medium: "voice",
                context: contextDict
            )
            instructions = result.prompt
            cachedGreeting = result.greeting
            NSLog("✅ Fetched book_completion system prompt from backend (\(instructions.count) chars)")
        } catch {
            NSLog("⚠️ Failed to fetch Prospero prompt from backend, using fallback: \(error)")
            instructions = "You are Prospero. Celebrate that \(context.userName) just finished \"\(context.storyTitle)\"! Ask what they loved about it, what could be better, and what they want in the sequel."
            cachedGreeting = "\(context.userName)! You've journeyed through \"\(context.storyTitle)\"! The final page has turned, but before the ink dries — tell me, what moment seized your heart?"
        }

        let config: [String: Any] = [
            "type": "session.update",
            "session": [
                "modalities": ["text", "audio"],
                "instructions": instructions,
                "voice": "ballad",
                "input_audio_format": "pcm16",
                "output_audio_format": "pcm16",
                "input_audio_transcription": [
                    "model": "whisper-1"
                ] as [String: Any],
                "turn_detection": [
                    "type": "semantic_vad",
                    "eagerness": "medium"
                ] as [String: Any],
                "input_audio_noise_reduction": [
                    "type": "near_field"
                ] as [String: Any],
                "tools": tools,
                "max_response_output_tokens": 1000
            ]
        ]

        NSLog("📤 Sending book completion session configuration...")
        sendEvent(config)

        try await Task.sleep(nanoseconds: 1_000_000_000)
        NSLog("✅ Book completion configuration complete")
    }

    // MARK: - Bug Report Session Configuration

    private func configureBugReportSession(context: BugReportContext) async throws {
        let tools: [[String: Any]] = [[
            "type": "function",
            "name": "submit_bug_report",
            "description": "Submit the bug report after gathering details from the user.",
            "parameters": [
                "type": "object",
                "properties": [
                    "summary": ["type": "string", "description": "One-sentence description of the issue"],
                    "category": ["type": "string", "enum": ["navigation", "generation", "reading", "interview", "visual", "performance", "feature_request", "other"], "description": "Bug category"],
                    "severity_hint": ["type": "string", "enum": ["critical", "annoying", "cosmetic", "idea"], "description": "How severe is this issue"],
                    "user_description": ["type": "string", "description": "Full description of the issue in the user's own words"],
                    "steps_to_reproduce": ["type": "string", "description": "Steps to reproduce the issue, if described"],
                    "expected_behavior": ["type": "string", "description": "What the user expected to happen"],
                    "sign_off_message": ["type": "string", "description": "Peggy's warm closing line to the user"]
                ],
                "required": ["summary", "category", "user_description", "sign_off_message"]
            ]
        ]]

        // Build context for backend prompt assembly
        var contextDict: [String: Any] = [
            "currentScreen": context.currentScreen
        ]

        if let userName = context.userName {
            contextDict["userName"] = userName
        }

        if let metadata = context.metadata {
            contextDict["metadata"] = metadata
        }

        // Fetch system prompt from backend
        let instructions: String
        do {
            let result = try await APIManager.shared.getSystemPrompt(
                persona: "peggy",
                reportType: "bug_report",
                medium: "voice",
                context: contextDict
            )
            instructions = result.prompt
            cachedGreeting = result.greeting
            NSLog("✅ Fetched Peggy bug_report system prompt from backend (\(instructions.count) chars)")
        } catch {
            NSLog("⚠️ Failed to fetch Peggy prompt from backend, using fallback: \(error)")
            let userName = context.userName ?? "hon"
            instructions = """
            You are PEGGY — a no-nonsense 1950s phone operator from Long Island. Sarcastic, warm, sharp. You say "hon", "sugar", "aw jeez". Keep every response to 1 sentence max. You're taking a complaint about a busted switchboard line (the app). Get the facts fast: what happened, what should've happened. Then say "Thanks hon! We'll reach out if we need more info" and call submit_bug_report. Do NOT give long closings.
            """
            cachedGreeting = "Alright \(userName), sounds like the switchboard's actin' up. Tell me what happened."
        }

        let config: [String: Any] = [
            "type": "session.update",
            "session": [
                "modalities": ["text", "audio"],
                "instructions": instructions,
                "voice": "shimmer",
                "input_audio_format": "pcm16",
                "output_audio_format": "pcm16",
                "input_audio_transcription": [
                    "model": "whisper-1"
                ] as [String: Any],
                "turn_detection": [
                    "type": "semantic_vad",
                    "eagerness": "medium"
                ] as [String: Any],
                "input_audio_noise_reduction": [
                    "type": "near_field"
                ] as [String: Any],
                "tools": tools,
                "max_response_output_tokens": 200
            ]
        ]

        NSLog("📤 Sending bug report session configuration...")
        sendEvent(config)

        try await Task.sleep(nanoseconds: 1_000_000_000)
        NSLog("✅ Bug report configuration complete")
    }

    // MARK: - Suggestion Session Configuration

    private func configureSuggestionSession(context: SuggestionContext) async throws {
        let tools: [[String: Any]] = [[
            "type": "function",
            "name": "submit_bug_report",
            "description": "Submit the feature suggestion after gathering details from the user.",
            "parameters": [
                "type": "object",
                "properties": [
                    "summary": ["type": "string", "description": "One-sentence description of the issue"],
                    "category": ["type": "string", "enum": ["navigation", "generation", "reading", "interview", "visual", "performance", "feature_request", "other"], "description": "Bug category"],
                    "severity_hint": ["type": "string", "enum": ["critical", "annoying", "cosmetic", "idea"], "description": "How severe is this issue"],
                    "user_description": ["type": "string", "description": "Full description of the issue in the user's own words"],
                    "steps_to_reproduce": ["type": "string", "description": "Steps to reproduce the issue, if described"],
                    "expected_behavior": ["type": "string", "description": "What the user expected to happen"],
                    "sign_off_message": ["type": "string", "description": "Peggy's warm closing line to the user"]
                ],
                "required": ["summary", "category", "user_description", "sign_off_message"]
            ]
        ]]

        // Build context for backend prompt assembly
        var contextDict: [String: Any] = [
            "currentScreen": context.currentScreen
        ]

        if let userName = context.userName {
            contextDict["userName"] = userName
        }

        // Fetch system prompt from backend
        let instructions: String
        do {
            let result = try await APIManager.shared.getSystemPrompt(
                persona: "peggy",
                reportType: "suggestion",
                medium: "voice",
                context: contextDict
            )
            instructions = result.prompt
            cachedGreeting = result.greeting
            NSLog("✅ Fetched Peggy suggestion system prompt from backend (\(instructions.count) chars)")
        } catch {
            NSLog("⚠️ Failed to fetch Peggy prompt from backend, using fallback: \(error)")
            let userName = context.userName ?? "hon"
            instructions = """
            You are PEGGY — a no-nonsense 1950s phone operator from Long Island. Sarcastic, warm, sharp. You say "hon", "sugar", "aw jeez". Keep every response to 1 sentence max. You're collecting a feature suggestion. Get the idea, ask why it matters, then say "Love it, I'll pass it to the brass. Thanks hon!" and call submit_bug_report. Do NOT give long closings.
            """
            cachedGreeting = "Alright \(userName), I'm all ears. What's the big idea?"
        }

        let config: [String: Any] = [
            "type": "session.update",
            "session": [
                "modalities": ["text", "audio"],
                "instructions": instructions,
                "voice": "shimmer",
                "input_audio_format": "pcm16",
                "output_audio_format": "pcm16",
                "input_audio_transcription": [
                    "model": "whisper-1"
                ] as [String: Any],
                "turn_detection": [
                    "type": "semantic_vad",
                    "eagerness": "medium"
                ] as [String: Any],
                "input_audio_noise_reduction": [
                    "type": "near_field"
                ] as [String: Any],
                "tools": tools,
                "max_response_output_tokens": 200
            ]
        ]

        NSLog("📤 Sending suggestion session configuration...")
        sendEvent(config)

        try await Task.sleep(nanoseconds: 1_000_000_000)
        NSLog("✅ Suggestion configuration complete")
    }

    private func triggerAIGreeting() {
        NSLog("👋 Triggering AI greeting with response.create event...")

        // Use cached greeting from backend, or fallback to hardcoded greeting
        let greeting: String
        if let cached = cachedGreeting {
            greeting = cached
            NSLog("✅ Using cached greeting from backend")
        } else {
            NSLog("⚠️ No cached greeting, using fallback")
            switch interviewType {
            case .onboarding:
                greeting = "Welcome, seeker, to the realm of MYTHWEAVER! Before I can summon the tales that await you — what name shall I inscribe in my tome?"
            case .returningUser(let context):
                let lastTitle = context.previousStoryTitles.last ?? "your last adventure"
                greeting = "Ah, \(context.userName)! Back for more, I see. Fresh from \(lastTitle)! What calls to your spirit today — more of what you love, or shall I surprise you?"
            case .premiseRejection(let context):
                greeting = "\(context.userName)! You're back — and I'm GLAD. Those tales I conjured clearly weren't worthy of you. Help me understand what missed the mark, and I'll summon something far better."
            case .bookCompletion(let context):
                greeting = "\(context.userName)! You've journeyed through \"\(context.storyTitle)\"! The final page has turned, but before the ink dries — tell me, what moment seized your heart?"
            case .bugReport(let context):
                let userName = context.userName ?? "friend"
                greeting = "Hey \(userName)! I'm Peggy, your friendly bug catcher. Tell me what's going wrong, and I'll make sure the team knows about it!"
            case .suggestion(let context):
                let userName = context.userName ?? "friend"
                greeting = "Hey \(userName)! I'm Peggy! I LOVE hearing new ideas. What would you like to see in Mythweaver?"
            }
        }

        let greetingInstructions = "Say EXACTLY: '\(greeting)' Then STOP and WAIT for their answer."

        let event: [String: Any] = [
            "type": "response.create",
            "response": [
                "modalities": ["text", "audio"],
                "instructions": greetingInstructions
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

        // Parse the arguments JSON
        guard let argsData = arguments.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] else {
            NSLog("⚠️ Failed to parse function arguments")
            return
        }

        // Handle different function types
        switch name {
        case "submit_story_preferences":
            NSLog("✅ Story preferences received (onboarding)!")
            NSLog("   \(args)")

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

                // Trigger AI to respond with closing message
                sendEvent(["type": "response.create"])
            }

        case "submit_new_story_request":
            NSLog("✅ New story request received (returning user)!")
            NSLog("   \(args)")

            // Trigger callback with request data
            onPreferencesGathered?(args)

            // Send function response back to OpenAI
            Task {
                let result: [String: Any] = [
                    "type": "conversation.item.create",
                    "item": [
                        "type": "function_call_output",
                        "call_id": callId,
                        "output": "{\"success\": true, \"message\": \"New story request received.\"}"
                    ]
                ]
                sendEvent(result)

                // Trigger AI to respond with closing message
                sendEvent(["type": "response.create"])
            }

        case "submit_completion_feedback":
            NSLog("✅ Completion feedback received!")
            NSLog("   \(args)")

            // Trigger callback with feedback data
            onPreferencesGathered?(args)

            // Send function response back to OpenAI
            Task {
                let result: [String: Any] = [
                    "type": "conversation.item.create",
                    "item": [
                        "type": "function_call_output",
                        "call_id": callId,
                        "output": "{\"success\": true, \"message\": \"Feedback received with gratitude.\"}"
                    ]
                ]
                sendEvent(result)

                // Trigger AI to respond with closing message
                sendEvent(["type": "response.create"])
            }

        case "submit_bug_report":
            NSLog("✅ Bug report/suggestion received!")
            NSLog("   \(args)")

            // Trigger callback with bug report/suggestion data
            onPreferencesGathered?(args)

            // Send function response back to OpenAI
            Task {
                let result: [String: Any] = [
                    "type": "conversation.item.create",
                    "item": [
                        "type": "function_call_output",
                        "call_id": callId,
                        "output": "{\"success\": true, \"message\": \"Report captured! The team will review it.\"}"
                    ]
                ]
                sendEvent(result)

                // Trigger AI to respond with closing message
                sendEvent(["type": "response.create"])
            }

        default:
            NSLog("⚠️ Unknown function call: \(name)")
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
