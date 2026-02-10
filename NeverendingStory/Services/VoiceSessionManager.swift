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

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var webSocketTask: URLSessionWebSocketTask?
    private var audioConverter: AVAudioConverter?
    private var isReceivingMessages = false
    private var sessionToken: String?

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

        // Step 1: Get ephemeral session token from backend
        NSLog("🔐 VoiceSession: Requesting session token from backend...")
        sessionToken = try await getSessionToken()
        NSLog("✅ VoiceSession: Session token received")

        // Step 2: Setup audio engine
        try setupAudioEngine()

        // Step 3: Create WebSocket connection using session token
        var urlComponents = URLComponents(string: "wss://api.openai.com/v1/realtime")!
        urlComponents.queryItems = [
            URLQueryItem(name: "model", value: "gpt-4o-realtime-preview-2024-12-17")
        ]

        guard let url = urlComponents.url else {
            throw NSError(domain: "VoiceSession", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid WebSocket URL"])
        }

        var request = URLRequest(url: url)
        // Use ephemeral session token instead of API key
        request.setValue("Bearer \(sessionToken!)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")

        NSLog("🔌 Connecting to OpenAI WebSocket...")
        NSLog("   URL: \(url.absoluteString)")
        NSLog("   Token: \(sessionToken!.prefix(20))...")

        webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask?.resume()

        NSLog("✅ WebSocket task created and resumed")

        // Start receiving messages
        startReceivingMessages()
        NSLog("✅ Started receiving messages")

        // Configure the session
        NSLog("⚙️ Configuring session...")
        try await configureSession()
        NSLog("✅ Session configured")

        state = .connected
        NSLog("✅ State set to connected")

        // Start audio streaming
        startListening()
        NSLog("🎤 Audio streaming started")
    }

    private func getSessionToken() async throws -> String {
        // Call backend to get ephemeral OpenAI session token
        struct SessionResponse: Codable {
            let success: Bool
            let sessionId: String
            let clientSecret: String
            let expiresAt: Int?
        }

        return try await APIManager.shared.createVoiceSession()
    }

    func endSession() {
        stopListening()

        // Send session end event
        if webSocketTask != nil {
            sendEvent(type: "input_audio_buffer.commit")
        }

        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isReceivingMessages = false
        state = .idle
    }

    // MARK: - Audio Engine Setup

    private func setupAudioEngine() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [])
        try audioSession.setActive(true)

        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode

        guard let inputNode = inputNode else {
            throw NSError(domain: "VoiceSession", code: -2, userInfo: [NSLocalizedDescriptionKey: "No input node available"])
        }

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

        // Install tap with smaller buffer for lower latency
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            Task { @MainActor in
                await self?.processAudioBuffer(buffer)
            }
        }
    }

    private func startListening() {
        guard let audioEngine = audioEngine else { return }

        do {
            try audioEngine.start()
            state = .listening
        } catch {
            state = .error("Failed to start audio engine: \(error.localizedDescription)")
        }
    }

    private func stopListening() {
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        audioEngine = nil
        inputNode = nil
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
    }

    // MARK: - Session Configuration

    private func configureSession() async throws {
        let instructions = """
        You are a creative writing assistant helping users discover their perfect story.
        Your goal is to have a natural, friendly conversation to understand:
        1. What genres they enjoy (mystery, sci-fi, romance, fantasy, thriller, etc.)
        2. What kind of characters they like (heroic, flawed, relatable, etc.)
        3. What themes interest them (redemption, discovery, love, survival, etc.)
        4. The mood they're in (dark and intense, light and fun, emotional, adventurous, etc.)

        Keep the conversation natural and conversational - don't just ask a list of questions.
        Be enthusiastic and encouraging. After gathering enough information (2-3 exchanges),
        let them know you're generating personalized story premises based on their preferences.

        Keep your responses concise and conversational - 1-2 sentences at a time.
        """

        let config: [String: Any] = [
            "type": "session.update",
            "session": [
                "modalities": ["text", "audio"],
                "instructions": instructions,
                "voice": "alloy",
                "input_audio_format": "pcm16",
                "output_audio_format": "pcm16",
                "input_audio_transcription": [
                    "model": "whisper-1"
                ],
                "turn_detection": [
                    "type": "server_vad",
                    "threshold": 0.5,
                    "prefix_padding_ms": 300,
                    "silence_duration_ms": 500
                ],
                "temperature": 0.8,
                "max_response_output_tokens": 150
            ]
        ]

        NSLog("📤 Sending session configuration...")
        sendEvent(config)

        // Wait a moment for configuration to be processed
        NSLog("⏳ Waiting for configuration to process...")
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        NSLog("✅ Configuration wait complete")
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
            let message = URLSessionWebSocketTask.Message.data(data)

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
        case "session.created", "session.updated":
            NSLog("✅ Session configured successfully")

        case "input_audio_buffer.speech_started":
            state = .listening

        case "input_audio_buffer.speech_stopped":
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

        case "response.done":
            state = .listening

        case "error":
            if let error = data["error"] as? [String: Any],
               let message = error["message"] as? String {
                state = .error(message)
            }

        default:
            // Handle other event types as needed
            break
        }
    }
}
