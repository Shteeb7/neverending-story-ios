//
//  VoiceSessionManager.swift
//  NeverendingStory
//
//  Manages OpenAI Realtime API voice sessions
//

import Foundation
import AVFoundation
import Combine

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

    // Continuation to wait for session.created event
    private var sessionCreatedContinuation: CheckedContinuation<Void, Never>?

    // Audio playback
    private var audioPlayerNode: AVAudioPlayerNode?
    private var audioMixerNode: AVAudioMixerNode?
    private var pendingAudioData = Data()

    // Audio buffering (prevents choppy/silent audio)
    private var audioQueue: [Data] = []
    private var isPlayingAudio = false

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
        startListening()
        NSLog("🎤 Audio streaming started")

        // Send initial greeting to start conversation
        triggerAIGreeting()
        NSLog("👋 AI greeting triggered")
    }

    func endSession() {
        stopListening()

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

        // Submit conversation to backend if we have content
        if !conversationText.isEmpty {
            Task {
                await submitConversationToBackend()
            }
        }

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
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker])
        try audioSession.setActive(true)

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

        // Install tap with smaller buffer for lower latency
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            Task { @MainActor in
                await self?.processAudioBuffer(buffer)
            }
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

        // Start the player node
        playerNode.play()
        NSLog("✅ Audio player node started")
    }

    private func startListening() {
        guard let audioEngine = audioEngine else {
            NSLog("⚠️ startListening: audioEngine is nil")
            return
        }

        NSLog("🎤 Starting audio engine...")
        do {
            try audioEngine.start()
            NSLog("✅ Audio engine started successfully")
            NSLog("   Engine is running: \(audioEngine.isRunning)")
            state = .listening
        } catch {
            NSLog("❌ Failed to start audio engine: \(error)")
            state = .error("Failed to start audio engine: \(error.localizedDescription)")
        }
    }

    private func stopListening() {
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        audioEngine = nil
        inputNode = nil
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

        // Wait for 3 chunks to buffer before starting playback
        if !isPlayingAudio && audioQueue.count >= 3 {
            NSLog("🎵 Buffer ready (\(audioQueue.count) chunks), starting playback")
            playNextAudioChunk()
        } else {
            NSLog("🎵 Buffering chunk (\(audioQueue.count)/3)")
        }
    }

    private func playNextAudioChunk() {
        guard !audioQueue.isEmpty else {
            NSLog("🎵 Audio queue empty, stopping playback")
            isPlayingAudio = false
            return
        }

        isPlayingAudio = true

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
            playNextAudioChunk() // Try next
            return
        }

        let frameCount = UInt32(combinedData.count / 2) // 16-bit samples
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else {
            NSLog("⚠️ Cannot create combined buffer")
            playNextAudioChunk() // Try next
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

        // Schedule combined buffer
        playerNode.scheduleBuffer(buffer) { [weak self] in
            DispatchQueue.main.async {
                NSLog("🔊 Combined chunk played (\(frameCount) frames)")
                self?.playNextAudioChunk() // Chain to next chunk
            }
        }

        // Ensure player is running
        if !playerNode.isPlaying {
            playerNode.play()
            NSLog("▶️  Started audio player")
        }

        NSLog("🎵 Scheduled combined buffer: \(frameCount) frames (\(combinedData.count) bytes)")
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
        // SIMPLIFIED for debugging - use minimal working config like test script
        let instructions = "You are a helpful assistant. Greet the user warmly and ask what kind of story they would like to read."

        // SIMPLIFIED config matching working test script exactly
        let config: [String: Any] = [
            "type": "session.update",
            "session": [
                "modalities": ["text", "audio"],
                "instructions": instructions,
                "voice": "alloy",  // Using same voice as working test script
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
                ] as [String: Any]
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
        // Trigger mystical opening - sets the magical tone immediately
        let event: [String: Any] = [
            "type": "response.create",
            "response": [
                "modalities": ["text", "audio"],
                "instructions": "Greet the user with mystical warmth, as if you're a creative muse sensing their presence. Use your magical storytelling guide persona. Open with wonder and invitation. One sentence only."
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
                    NSLog("❌ WebSocket receive error: \(error)")
                    NSLog("   Error code: \(error._code)")
                    NSLog("   Description: \(error.localizedDescription)")
                    self.state = .error("Connection error: \(error.localizedDescription)")
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
            if let item = data["item"] as? [String: Any],
               let role = item["role"] as? String,
               let content = item["content"] as? [[String: Any]] {

                for contentItem in content {
                    if let transcript = contentItem["transcript"] as? String {
                        if role == "user" {
                            conversationText += "You: \(transcript)\n\n"
                            transcription = transcript
                        } else if role == "assistant" {
                            conversationText += "AI: \(transcript)\n\n"
                        }
                    }
                }
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
            // Audio response complete, clear any pending data
            NSLog("✅ response.audio.done - AI finished speaking")
            clearPendingAudio()

        case "response.audio_transcript.delta":
            // Handle audio transcript if needed (already handled in conversation.item.created)
            break

        case "response.done":
            NSLog("✅ response.done - conversation turn complete")
            state = .listening
            clearPendingAudio()

        case "response.created":
            NSLog("✅ response.created - AI is preparing to respond")
            if let response = data["response"] as? [String: Any],
               let id = response["id"] as? String {
                NSLog("   Response ID: \(id)")
            }

        case "error":
            if let error = data["error"] as? [String: Any],
               let message = error["message"] as? String {
                NSLog("❌ OpenAI Error: \(message)")
                state = .error(message)
            }

        default:
            // Log unhandled event types for debugging
            if !["response.output_item.added", "response.content_part.added", "response.audio_transcript.delta", "response.audio_transcript.done", "rate_limits.updated"].contains(type) {
                NSLog("ℹ️ Unhandled event type: \(type)")
            }
            break
        }
    }
}
