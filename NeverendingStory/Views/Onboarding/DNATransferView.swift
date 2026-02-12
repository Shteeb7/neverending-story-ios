//
//  DNATransferView.swift
//  NeverendingStory
//
//  Touch-activated particle ceremony that bridges onboarding to premise selection
//

import SwiftUI
import CoreHaptics
import UIKit

// MARK: - Particle Emitter View

struct ParticleEmitterView: UIViewRepresentable {
    var emissionPoint: CGPoint
    var intensity: CGFloat  // 0.0 to 1.0
    var isActive: Bool

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        // Create emitter layer
        let emitterLayer = CAEmitterLayer()
        emitterLayer.emitterShape = .point
        emitterLayer.renderMode = .additive

        // Create particle image (white circle)
        let particleImage = createParticleImage()

        // Create emitter cell
        let cell = CAEmitterCell()
        cell.contents = particleImage.cgImage
        cell.birthRate = 5
        cell.lifetime = 2.0
        cell.velocity = 30
        cell.velocityRange = 10
        cell.emissionRange = .pi / 4
        cell.spin = 0
        cell.spinRange = .pi * 2
        cell.scale = 0.2
        cell.scaleSpeed = -0.1
        cell.alphaSpeed = -0.3
        cell.color = UIColor(red: 0.63, green: 0.77, blue: 1.0, alpha: 1.0).cgColor

        emitterLayer.emitterCells = [cell]

        view.layer.addSublayer(emitterLayer)

        // Store emitter layer in context for updates
        context.coordinator.emitterLayer = emitterLayer
        context.coordinator.emitterCell = cell

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let emitterLayer = context.coordinator.emitterLayer,
              let cell = context.coordinator.emitterCell else { return }

        // Update emitter position
        emitterLayer.emitterPosition = emissionPoint

        if isActive {
            // Calculate properties based on intensity
            let birthRate: Float = 5 + Float(intensity) * 75  // 5→80
            let lifetime: Float = 2.0 + Float(intensity) * 2.0  // 2→4
            let velocity: CGFloat = 30 + intensity * 120  // 30→150
            let scale: CGFloat = 0.2 + intensity * 0.6  // 0.2→0.8

            // Emission range expands to full sphere at 0.5 intensity
            let emissionRange: CGFloat = (.pi / 4) + min(intensity * 2, 1.0) * (.pi * 2 - .pi / 4)

            // Color transitions based on intensity
            let color: UIColor
            if intensity < 0.3 {
                // Blue-white
                color = UIColor(red: 0.63, green: 0.77, blue: 1.0, alpha: 1.0)
            } else if intensity < 0.7 {
                // Lerp to gold
                let t = (intensity - 0.3) / 0.4
                color = UIColor(
                    red: 0.63 + (1.0 - 0.63) * t,
                    green: 0.77 + (0.84 - 0.77) * t,
                    blue: 1.0 - 1.0 * t,
                    alpha: 1.0
                )
            } else {
                // Lerp to white-purple
                let t = (intensity - 0.7) / 0.3
                color = UIColor(
                    red: 1.0 - (1.0 - 0.91) * t,
                    green: 0.84 + (0.85 - 0.84) * t,
                    blue: 0.0 + 0.93 * t,
                    alpha: 1.0
                )
            }

            // Update cell properties
            cell.birthRate = birthRate
            cell.lifetime = lifetime
            cell.velocity = velocity
            cell.emissionRange = emissionRange
            cell.scale = scale
            cell.color = color.cgColor

        } else {
            // Idle state
            cell.birthRate = 2
            cell.velocity = 20
            cell.emissionRange = .pi / 4
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var emitterLayer: CAEmitterLayer?
        var emitterCell: CAEmitterCell?
    }

    private func createParticleImage() -> UIImage {
        let size = CGSize(width: 8, height: 8)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - DNA Transfer View

struct DNATransferView: View {
    let userId: String
    let onComplete: () -> Void

    // Phase management
    enum TransferPhase {
        case waiting      // Instruction text, waiting for touch
        case transferring // Finger down, particles + haptics escalating
        case sustaining   // Ceremony done, waiting for premises
        case complete     // Premises ready, exit animation
    }

    @State private var phase: TransferPhase = .waiting
    @State private var touchPoint: CGPoint = .zero
    @State private var transferProgress: CGFloat = 0.0  // 0.0 to 1.0 over 10 seconds
    @State private var transferTimer: Timer?
    @State private var premiseTimer: Timer?
    @State private var hapticEngine: CHHapticEngine?
    @State private var hapticPlayer: CHHapticPatternPlayer?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var totalElapsed: Double = 0.0
    @State private var fingerLifted = false
    @State private var showClimaxFlash = false
    @State private var pulseRings: [PulseRing] = []
    @State private var breathingOpacity: Double = 0.7

    struct PulseRing: Identifiable {
        let id = UUID()
        var scale: CGFloat = 1.0
        var opacity: Double = 0.3
    }

    var body: some View {
        ZStack {
            // Background
            Color(white: 0.05)
                .ignoresSafeArea()

            // Edge glow (appears at intensity > 0.5)
            if transferProgress > 0.5 {
                RadialGradient(
                    colors: [
                        Color.clear,
                        Color.accentColor.opacity(0.1 * Double(transferProgress - 0.5) * 2)
                    ],
                    center: .center,
                    startRadius: 100,
                    endRadius: 500
                )
                .ignoresSafeArea()
            }

            // Particle system
            if phase == .transferring || phase == .sustaining {
                ParticleEmitterView(
                    emissionPoint: touchPoint,
                    intensity: phase == .transferring ? transferProgress : 0.3,
                    isActive: phase == .transferring
                )
                .ignoresSafeArea()
            }

            // Pulse rings at touch point
            if phase == .transferring {
                ForEach(pulseRings) { ring in
                    Circle()
                        .stroke(Color.accentColor, lineWidth: 2)
                        .frame(width: 60, height: 60)
                        .scaleEffect(ring.scale)
                        .opacity(ring.opacity)
                        .position(touchPoint)
                }
            }

            // Climax flash
            if showClimaxFlash {
                Color.white
                    .opacity(0.8)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            // Content based on phase
            VStack(spacing: 32) {
                Spacer()

                switch phase {
                case .waiting:
                    waitingView

                case .transferring:
                    if fingerLifted {
                        Text("Don't let go...")
                            .font(.system(size: 20, design: .serif))
                            .foregroundColor(.white.opacity(0.7))
                            .transition(.opacity)
                    }

                case .sustaining:
                    sustainingView

                case .complete:
                    completeView
                }

                Spacer()

                // Error UI
                if showError {
                    errorView
                }
            }
            .padding(.horizontal, 32)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleTouchDown(at: value.location)
                }
                .onEnded { _ in
                    handleTouchUp()
                }
        )
        .onAppear {
            setupHapticEngine()
            startBreathingAnimation()
        }
        .onDisappear {
            cleanup()
        }
    }

    // MARK: - Phase Views

    private var waitingView: some View {
        VStack(spacing: 24) {
            Text("Place your finger on the screen and hold it there.")
                .font(.system(size: 20, design: .serif))
                .foregroundColor(.white.opacity(breathingOpacity))
                .multilineTextAlignment(.center)

            Text("Don't lift it until the transfer is complete.")
                .font(.system(size: 18, design: .serif))
                .foregroundColor(.white.opacity(breathingOpacity * 0.8))
                .multilineTextAlignment(.center)
        }
        .transition(.opacity)
    }

    private var sustainingView: some View {
        Text("Your stories are taking shape...")
            .font(.system(size: 20, design: .serif))
            .foregroundColor(.white.opacity(breathingOpacity))
            .multilineTextAlignment(.center)
            .transition(.opacity)
    }

    private var completeView: some View {
        Text("Your stories await.")
            .font(.system(size: 24, design: .serif))
            .foregroundColor(.white.opacity(0.9))
            .multilineTextAlignment(.center)
            .transition(.opacity)
    }

    private var errorView: some View {
        VStack(spacing: 20) {
            Text("Something went wrong conjuring your stories.")
                .font(.body)
                .foregroundColor(.red.opacity(0.9))
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button(action: retryGeneration) {
                    Text("Retry")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                Button(action: { onComplete() }) {
                    Text("Return to Library")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.secondary)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(white: 0.1))
        .cornerRadius(16)
    }

    // MARK: - Touch Handling

    private func handleTouchDown(at location: CGPoint) {
        touchPoint = location
        fingerLifted = false

        if phase == .waiting {
            // Transition to transferring
            phase = .transferring
            startTransferTimer()
            startHapticSequence()
            startPulseRings()
        } else if phase == .transferring {
            // Finger returned after lifting
            if transferTimer == nil {
                startTransferTimer()
                startHapticSequence()
            }
        }
    }

    private func handleTouchUp() {
        fingerLifted = true

        if phase == .transferring {
            // Pause timer and haptics
            transferTimer?.invalidate()
            transferTimer = nil
            try? hapticPlayer?.stop(atTime: CHHapticTimeImmediate)
        }
    }

    // MARK: - Transfer Timer

    private func startTransferTimer() {
        transferTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            transferProgress += 0.01  // 10 seconds = 1.0 progress

            if transferProgress >= 1.0 {
                transferProgress = 1.0
                transferTimer?.invalidate()
                transferTimer = nil
                completeTransfer()
            }
        }
    }

    private func completeTransfer() {
        // Climax flash
        withAnimation(.easeOut(duration: 0.5)) {
            showClimaxFlash = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.5)) {
                showClimaxFlash = false
            }
        }

        // Stop haptics
        try? hapticPlayer?.stop(atTime: CHHapticTimeImmediate)

        // Transition to sustaining
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            phase = .sustaining
            startPremisePolling()
        }
    }

    // MARK: - Haptic Engine

    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            NSLog("⚠️ Device does not support haptics")
            return
        }

        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            NSLog("✅ Haptic engine started")
        } catch {
            NSLog("❌ Failed to start haptic engine: \(error)")
        }
    }

    private func startHapticSequence() {
        guard let engine = hapticEngine else { return }

        // Calculate remaining time based on current progress
        let remainingTime = (1.0 - transferProgress) * 10.0  // seconds

        var events: [CHHapticEvent] = []
        var currentTime: Double = 0.0

        // Generate events for remaining time
        while currentTime < remainingTime {
            let normalizedProgress = (10.0 - remainingTime + currentTime) / 10.0

            let intensity: Float
            let sharpness: Float
            let interval: Double

            if normalizedProgress < 0.3 {
                intensity = 0.2
                sharpness = 0.3
                interval = 0.4
            } else if normalizedProgress < 0.6 {
                intensity = 0.5
                sharpness = 0.5
                interval = 0.25
            } else if normalizedProgress < 0.8 {
                intensity = 0.7
                sharpness = 0.7
                interval = 0.15
            } else {
                intensity = 1.0
                sharpness = 0.9
                interval = 0.08
            }

            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ],
                relativeTime: currentTime
            )
            events.append(event)
            currentTime += interval
        }

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            hapticPlayer = try engine.makePlayer(with: pattern)
            try hapticPlayer?.start(atTime: 0)
            NSLog("✅ Haptic sequence started")
        } catch {
            NSLog("❌ Failed to start haptic pattern: \(error)")
        }
    }

    // MARK: - Pulse Rings

    private func startPulseRings() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            guard phase == .transferring else {
                timer.invalidate()
                return
            }

            addPulseRing()
        }

        // Staggered initial rings
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            addPulseRing()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            addPulseRing()
        }
    }

    private func addPulseRing() {
        let ring = PulseRing()
        pulseRings.append(ring)

        withAnimation(.easeOut(duration: 2.0)) {
            if let index = pulseRings.firstIndex(where: { $0.id == ring.id }) {
                pulseRings[index].scale = 3.0
                pulseRings[index].opacity = 0.0
            }
        }

        // Remove after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            pulseRings.removeAll { $0.id == ring.id }
        }
    }

    // MARK: - Premise Polling

    private func startPremisePolling() {
        // Fire one immediate check
        checkForPremises()

        // Then poll every 2.5 seconds
        premiseTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
            checkForPremises()
        }
    }

    private func checkForPremises() {
        Task {
            do {
                let result = try await APIManager.shared.getPremises(userId: userId)

                if !result.premises.isEmpty {
                    await MainActor.run {
                        premiseTimer?.invalidate()
                        premiseTimer = nil
                        finishCeremony()
                    }
                }
            } catch {
                NSLog("⚠️ Premise polling error: \(error)")
                // Silently retry on next poll
            }

            // Timeout after 60 seconds total
            await MainActor.run {
                totalElapsed += 2.5
                if totalElapsed > 60 {
                    premiseTimer?.invalidate()
                    premiseTimer = nil
                    showError = true
                    errorMessage = "Timeout waiting for premises"
                }
            }
        }
    }

    private func finishCeremony() {
        phase = .complete

        // Wait 1 second, then fade and call onComplete
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                // Trigger navigation
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onComplete()
            }
        }
    }

    // MARK: - Error Handling

    private func retryGeneration() {
        showError = false
        totalElapsed = 0.0
        phase = .sustaining

        Task {
            do {
                try await APIManager.shared.generatePremises()
                NSLog("✅ Premise generation retry started")
                await MainActor.run {
                    startPremisePolling()
                }
            } catch {
                NSLog("❌ Retry failed: \(error)")
                await MainActor.run {
                    showError = true
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Animations

    private func startBreathingAnimation() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            breathingOpacity = 0.5
        }
    }

    // MARK: - Cleanup

    private func cleanup() {
        transferTimer?.invalidate()
        premiseTimer?.invalidate()
        try? hapticPlayer?.stop(atTime: CHHapticTimeImmediate)
        hapticEngine?.stop()
    }
}

#Preview {
    DNATransferView(
        userId: "preview-user",
        onComplete: {
            print("DNA Transfer complete")
        }
    )
}
