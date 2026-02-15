//
//  BookReaderView.swift
//  NeverendingStory
//
//  Core reading experience using SwiftUI TabView for native page-turning
//  Features: Chapter pagination, tap zones, persistent toolbar, chapter menu
//

import SwiftUI

struct BookReaderView: View {
    let story: Story

    @StateObject private var readingState = ReadingStateManager.shared
    @StateObject private var readerSettings = ReaderSettings.shared

    @State private var showTopBar = true
    @State private var showSettings = false
    @State private var showChapterList = false
    @State private var topBarTimer: Timer?
    @State private var scrollProgress: Double = 0
    @State private var contentHeight: CGFloat = 0
    @State private var visibleHeight: CGFloat = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Feedback State (Adaptive Reading Engine)
    @State private var showProsperoCheckIn = false
    @State private var currentCheckpoint: String = ""
    @State private var checkedCheckpoints: Set<String> = []
    @State private var protagonistName: String = ""
    @State private var showCompletionInterview = false
    @State private var showSequelGeneration = false
    @State private var interviewPreferences: [String: Any] = [:]
    @State private var showGeneratingChapters = false
    @State private var generatingChapterNumber: Int = 0

    // MARK: - First Line Ceremony State
    @State private var showFirstLineCeremony = false
    @State private var firstLineCeremonyCompleted = false

    // MARK: - Next Chapter Alert State
    @State private var showNextChapterUnavailableAlert = false

    var body: some View {
        ZStack {
            // Main reading area with vertical scrolling
            if readingState.chapters.isEmpty {
                LoadingView("Loading chapters...")
            } else if let chapter = readingState.currentChapter {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            // Chapter title
                            Text(chapter.title)
                                .font(.system(size: 28, weight: .bold, design: .default))
                                .padding(.top, 60)
                                .padding(.bottom, 32)
                                .padding(.horizontal, 24)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .foregroundColor(readerSettings.textColor)
                                .id("chapter-top")

                            // Chapter content
                            Text(chapter.content)
                                .font(.system(
                                    size: readerSettings.fontSize,
                                    weight: .regular,
                                    design: readerSettings.fontDesign
                                ))
                                .lineSpacing(readerSettings.lineSpacing)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 40)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundColor(readerSettings.textColor)
                                .background(
                                    GeometryReader { geometry in
                                        Color.clear
                                            .preference(key: ScrollOffsetPreferenceKey.self,
                                                       value: geometry.frame(in: .named("scrollView")).minY)
                                            .preference(key: ContentHeightPreferenceKey.self,
                                                       value: geometry.size.height)
                                    }
                                )

                            // Next Chapter button
                            Button(action: handleNextChapterTap) {
                                HStack(spacing: 12) {
                                    Text("Next Chapter")
                                        .font(.headline)
                                    Image(systemName: "arrow.right")
                                        .font(.headline)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.accentColor)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 100)
                        }
                    }
                    .coordinateSpace(name: "scrollView")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        readingState.updateScrollPosition(Double(value))
                        // Calculate progress based on actual content height
                        if contentHeight > 0 {
                            // value is negative as we scroll down, so negate it
                            let scrolled = max(-value, 0)
                            let maxScroll = max(contentHeight - visibleHeight, 1)
                            let newProgress = min(scrolled / maxScroll, 1.0)

                            // Only update state when percentage actually changes (prevents scroll stuttering)
                            let newPercent = Int(newProgress * 100)
                            let currentPercent = Int(scrollProgress * 100)

                            if newPercent != currentPercent {
                                scrollProgress = Double(newPercent) / 100.0
                                readingState.updateScrollPercentage(Double(newPercent))
                            }
                        }
                        // Check for book completion as user scrolls through chapter 12
                        checkForFeedbackCheckpoint()
                    }
                    .onPreferenceChange(ContentHeightPreferenceKey.self) { value in
                        contentHeight = value
                    }
                    .background(
                        GeometryReader { geo in
                            Color.clear.onAppear {
                                visibleHeight = geo.size.height
                            }
                        }
                    )
                    .background(readerSettings.backgroundColor)
                    .onTapGesture {
                        showTopBarTemporarily()
                    }
                    .onChange(of: readingState.currentChapterIndex) {
                        // Scroll to top when chapter changes
                        withAnimation {
                            proxy.scrollTo("chapter-top", anchor: .top)
                        }
                        // Check for feedback checkpoint
                        checkForFeedbackCheckpoint()
                    }
                    .opacity(showFirstLineCeremony ? 0 : (firstLineCeremonyCompleted ? 1 : 1))
                    .animation(firstLineCeremonyCompleted ? .easeIn(duration: 0.8) : nil, value: showFirstLineCeremony)
                }
            }

            // Auto-hiding top bar (hidden during ceremony)
            VStack {
                if showTopBar && !showFirstLineCeremony {
                    HStack {
                        // Back button
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .foregroundColor(.primary)
                                .padding(12)
                                .background(Circle().fill(Color(.systemGray6).opacity(0.9)))
                        }

                        Spacer()

                        // Book title
                        Text(story.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Spacer()

                        // Settings button
                        Button(action: { showSettings = true }) {
                            Image(systemName: "textformat.size")
                                .font(.title3)
                                .foregroundColor(.primary)
                                .padding(12)
                                .background(Circle().fill(Color(.systemGray6).opacity(0.9)))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        readerSettings.backgroundColor
                            .opacity(0.95)
                            .ignoresSafeArea(edges: .top)
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()
            }

            // Compact bottom toolbar with progress (hidden during ceremony)
            VStack {
                Spacer()

                if !showFirstLineCeremony {
                    VStack(spacing: 0) {
                    // Progress bar (more visible)
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 3)

                            // Progress
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(width: geometry.size.width * scrollProgress, height: 3)
                        }
                    }
                    .frame(height: 3)

                    // Toolbar
                    HStack(spacing: 24) {
                        // Chapter menu button
                        Button(action: { showChapterList = true }) {
                            Image(systemName: "list.bullet")
                                .font(.title3)
                                .foregroundColor(readerSettings.textColor)
                        }

                        Spacer()

                        // Progress text
                        if let chapter = readingState.currentChapter {
                            VStack(spacing: 2) {
                                Text("Ch \(chapter.chapterNumber) of \(readingState.chapters.count)")
                                    .font(.caption)
                                    .foregroundColor(readerSettings.textColor.opacity(0.6))
                                // Show "more chapters on the way" only if actively generating
                                if let story = readingState.currentStory,
                                   let progress = story.generationProgress,
                                   progress.currentStep.hasPrefix("generating_") {
                                    Text("More chapters on the way...")
                                        .font(.caption2)
                                        .foregroundColor(readerSettings.textColor.opacity(0.4))
                                } else {
                                    Text("\(Int(scrollProgress * 100))% of chapter")
                                        .font(.caption2)
                                        .foregroundColor(readerSettings.textColor.opacity(0.4))
                                }
                            }
                        }

                        Spacer()

                        // Settings button
                        Button(action: { showSettings = true }) {
                            Image(systemName: "textformat.size")
                                .font(.title3)
                                .foregroundColor(readerSettings.textColor)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(
                        readerSettings.backgroundColor
                            .opacity(0.98)
                            .ignoresSafeArea(edges: .bottom)
                    )
                    }
                    .shadow(color: .black.opacity(0.1), radius: 4, y: -2)
                }
            }

            // First Line Ceremony Overlay
            if showFirstLineCeremony, let chapter = readingState.currentChapter {
                FirstLineCeremonyView(
                    firstLine: FirstLineCeremonyView.extractFirstLine(from: chapter.content),
                    readerSettings: readerSettings,
                    onComplete: {
                        firstLineCeremonyCompleted = true
                        showFirstLineCeremony = false
                        markCeremonyShown(for: story.id)
                    }
                )
                .transition(.opacity)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showSettings) {
            ReaderSettingsView()
        }
        .sheet(isPresented: $showChapterList) {
            ChapterListView(
                chapters: readingState.chapters,
                currentChapterIndex: $readingState.currentChapterIndex,
                onSelectChapter: { index in
                    readingState.goToChapter(index: index)
                    showChapterList = false
                }
            )
        }
        .fullScreenCover(isPresented: $showProsperoCheckIn) {
            ProsperoCheckInView(
                checkpoint: currentCheckpoint,
                protagonistName: protagonistName,
                onComplete: { pacing, tone, character in
                    handleProsperoCheckInComplete(pacing: pacing, tone: tone, character: character)
                }
            )
        }
        .fullScreenCover(isPresented: $showGeneratingChapters) {
            GeneratingChaptersView(
                storyId: story.id,
                storyTitle: story.title,
                nextChapterNumber: generatingChapterNumber,
                onChapterReady: {
                    showGeneratingChapters = false
                },
                // FIX 4: Wire up onNeedsFeedback callback
                onNeedsFeedback: {
                    // Dismiss generating view, show checkpoint instead
                    showGeneratingChapters = false
                    // Determine which checkpoint based on the chapter we were waiting for
                    let checkpointMap: [Int: String] = [4: "chapter_2", 7: "chapter_5", 10: "chapter_8"]
                    if let checkpoint = checkpointMap[generatingChapterNumber] {
                        Task {
                            await fetchProtagonistName()
                            await MainActor.run {
                                currentCheckpoint = checkpoint
                                // Small delay to let the generating view dismiss first
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    showProsperoCheckIn = true
                                }
                            }
                        }
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showCompletionInterview) {
            BookCompletionInterviewView(
                story: story,
                bookNumber: story.bookNumber ?? 1
            ) { preferences in
                NSLog("✅ Book completion interview finished with preferences: \(preferences)")
                // Start sequel generation
                interviewPreferences = preferences
                showSequelGeneration = true
            }
        }
        .fullScreenCover(isPresented: $showSequelGeneration) {
            SequelGenerationView(
                book1Story: story,
                bookNumber: (story.bookNumber ?? 1) + 1,
                userPreferences: interviewPreferences
            ) { book2 in
                NSLog("✅ Book 2 generated: \(book2.title)")
                // Navigate to Book 2 reader
                // For now, just dismiss back to library
                dismiss()
            }
        }
        .alert("Chapter Still Conjuring", isPresented: $showNextChapterUnavailableAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Prospero is still conjuring up your next chapter. Please return to the library.")
        }
        .task {
            do {
                try await readingState.loadStory(story)
                startTopBarTimer()
                // Start reading session for initial chapter
                readingState.startReadingSession()

                // Check if First Line Ceremony should play
                // Only for Chapter 1 of stories that haven't had their ceremony yet
                if readingState.currentChapterIndex == 0 && !hasShownCeremony(for: story.id) {
                    showFirstLineCeremony = true
                }

                // FIX 2: Check for pending checkpoint on view load
                // This catches cases where user restarts app while on a checkpoint chapter
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    checkForFeedbackCheckpoint()
                }
            } catch {
                print("Failed to load story: \(error)")
            }
        }
        .onDisappear {
            topBarTimer?.invalidate()
            // End reading session when leaving reader
            readingState.stopTracking()
            readingState.stopChapterPolling()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                // End session when app goes to background
                Task {
                    await readingState.endReadingSession()
                }
            case .active:
                // Restart session when app comes to foreground
                readingState.startReadingSession()
            case .inactive:
                // Do nothing on inactive (brief transition state)
                break
            @unknown default:
                break
            }
        }
    }

    private func showTopBarTemporarily() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showTopBar = true
        }
        startTopBarTimer()
    }

    private func startTopBarTimer() {
        topBarTimer?.invalidate()
        topBarTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showTopBar = false
            }
        }
    }

    private func handleNextChapterTap() {
        // Check if next chapter is available
        if readingState.canGoToNextChapter {
            // Next chapter exists - navigate to it
            readingState.goToNextChapter()
        } else {
            // FIX 1: Check if we're on a checkpoint chapter and feedback is needed
            let currentNum = readingState.currentChapter?.chapterNumber ?? 0

            // If we're on a checkpoint chapter (3, 6, 9), check if feedback is needed
            let checkpointMap: [Int: String] = [3: "chapter_2", 6: "chapter_5", 9: "chapter_8"]

            if let checkpoint = checkpointMap[currentNum] {
                // Always re-check feedback status when user hits end-of-chapter
                Task {
                    do {
                        let status = try await APIManager.shared.getFeedbackStatus(
                            storyId: story.id,
                            checkpoint: checkpoint
                        )
                        if !status.hasFeedback {
                            await fetchProtagonistName()
                            await MainActor.run {
                                currentCheckpoint = checkpoint
                                showProsperoCheckIn = true
                            }
                            return  // Don't show GeneratingChaptersView
                        }
                    } catch {
                        NSLog("❌ Checkpoint fallback check failed: \(error)")
                    }

                    // If feedback already submitted or check failed, show generating view
                    await MainActor.run {
                        let nextChapterNum = currentNum + 1
                        generatingChapterNumber = nextChapterNum
                        showGeneratingChapters = true
                    }
                }
            } else {
                // Not a checkpoint chapter — show generating view directly
                let nextChapterNum = currentNum + 1
                generatingChapterNumber = nextChapterNum
                showGeneratingChapters = true
            }
        }
    }

    // MARK: - Feedback Checkpoint Logic

    private func checkForFeedbackCheckpoint() {
        guard let currentChapter = readingState.currentChapter else { return }
        let chapterNum = currentChapter.chapterNumber

        // Check if book is complete (just finished chapter 12)
        if chapterNum == 12 && readingState.chapters.count >= 12 {
            // Check if we've scrolled to near the end of chapter 12
            if scrollProgress > 0.9 && !checkedCheckpoints.contains("chapter_12_complete") {
                checkedCheckpoints.insert("chapter_12_complete")

                // Show completion interview after a brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showCompletionInterview = true
                }
                return
            }
        }

        // Adaptive Reading Engine: checkpoint triggers at chapters 3, 6, 9 (after reading ch 2, 5, 8)
        var checkpoint: String?
        if chapterNum == 3 {
            checkpoint = "chapter_2"
        } else if chapterNum == 6 {
            checkpoint = "chapter_5"
        } else if chapterNum == 9 {
            checkpoint = "chapter_8"
        }

        guard let checkpoint = checkpoint else { return }

        // Don't show if already checked this session
        guard !checkedCheckpoints.contains(checkpoint) else { return }
        checkedCheckpoints.insert(checkpoint)

        // Check if feedback already submitted
        Task {
            do {
                let status = try await APIManager.shared.getFeedbackStatus(
                    storyId: story.id,
                    checkpoint: checkpoint
                )

                // Only show dialog if no feedback submitted yet
                if !status.hasFeedback {
                    // Fetch protagonist name for check-in
                    await fetchProtagonistName()

                    await MainActor.run {
                        currentCheckpoint = checkpoint
                        showProsperoCheckIn = true
                    }
                }
            } catch {
                NSLog("❌ Failed to check feedback status: \(error)")
            }
        }
    }

    // Adaptive Reading Engine: Handle dimension-based check-in completion
    private func handleProsperoCheckInComplete(pacing: String, tone: String, character: String) {
        Task {
            do {
                let _ = try await APIManager.shared.submitCheckpointFeedbackWithDimensions(
                    storyId: story.id,
                    checkpoint: currentCheckpoint,
                    pacing: pacing,
                    tone: tone,
                    character: character,
                    protagonistName: protagonistName
                )
                NSLog("✅ Submitted dimension feedback: pacing=\(pacing), tone=\(tone), character=\(character)")
            } catch {
                NSLog("❌ Failed to submit dimension feedback: \(error)")
            }
        }
    }

    // Set protagonist name for check-in
    // TODO: Fetch from story bible when backend endpoint is available
    private func fetchProtagonistName() async {
        await MainActor.run {
            self.protagonistName = "the protagonist"
        }
    }

    // DEPRECATED: Old feedback handling (kept for reference)
    private func handleMehFollowUpAction(_ action: String) {
        // This function is deprecated and should not be called
        switch action {
        case "different_story":
            // Submit feedback with follow-up action, then navigate to library
            submitFeedback(response: "Meh", followUpAction: "different_story")
            dismiss()

        case "keep_reading":
            // Submit feedback to trigger chapter generation
            submitFeedback(response: "Meh", followUpAction: "keep_reading")

        case "voice_tips":
            // TODO: Implement voice tips session
            // For now, just submit the feedback
            submitFeedback(response: "Meh", followUpAction: "voice_tips")
            NSLog("⚠️ Voice tips not yet implemented")

        default:
            break
        }
    }

    private func submitFeedback(response: String, followUpAction: String?) {
        Task {
            do {
                let result = try await APIManager.shared.submitCheckpointFeedback(
                    storyId: story.id,
                    checkpoint: currentCheckpoint,
                    response: response,
                    followUpAction: followUpAction
                )

                NSLog("✅ Feedback submitted: \(response) for \(currentCheckpoint)")
                NSLog("🚀 Generating chapters: \(result.generatingChapters)")

                // TODO: Show toast notification about chapter generation
            } catch {
                NSLog("❌ Failed to submit feedback: \(error)")
                // TODO: Show error alert
            }
        }
    }

    // MARK: - First Line Ceremony Helpers

    private func hasShownCeremony(for storyId: String) -> Bool {
        let shown = UserDefaults.standard.stringArray(forKey: "firstLineCeremonyShown") ?? []
        return shown.contains(storyId)
    }

    private func markCeremonyShown(for storyId: String) {
        var shown = UserDefaults.standard.stringArray(forKey: "firstLineCeremonyShown") ?? []
        if !shown.contains(storyId) {
            shown.append(storyId)
            UserDefaults.standard.set(shown, forKey: "firstLineCeremonyShown")
        }
    }
}

// MARK: - Scroll Position Tracking

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}


// MARK: - Chapter List View

struct ChapterListView: View {
    let chapters: [Chapter]
    @Binding var currentChapterIndex: Int
    let onSelectChapter: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(chapters.indices, id: \.self) { index in
                    Button(action: {
                        onSelectChapter(index)
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Chapter \(chapters[index].chapterNumber)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text(chapters[index].title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            if index == currentChapterIndex {
                                Image(systemName: "book.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Reader Settings

@MainActor
class ReaderSettings: ObservableObject {
    static let shared = ReaderSettings()

    @Published var fontSize: CGFloat
    @Published var lineSpacing: CGFloat
    @Published var fontDesign: Font.Design
    @Published var colorScheme: ReaderColorScheme

    init() {
        // Load from UserDefaults with defaults if not set
        let savedFontSize = CGFloat(UserDefaults.standard.float(forKey: "readerFontSize"))
        self.fontSize = savedFontSize == 0 ? AppConfig.defaultFontSize : savedFontSize

        let savedLineSpacing = CGFloat(UserDefaults.standard.float(forKey: "readerLineSpacing"))
        self.lineSpacing = savedLineSpacing == 0 ? AppConfig.defaultLineSpacing : savedLineSpacing

        let designRaw = UserDefaults.standard.integer(forKey: "readerFontDesign")
        self.fontDesign = ReaderSettings.fontDesignFromRaw(designRaw)

        let schemeRaw = UserDefaults.standard.integer(forKey: "readerColorScheme")
        self.colorScheme = ReaderColorScheme(rawValue: schemeRaw) ?? .auto
    }

    func save() {
        UserDefaults.standard.set(Float(fontSize), forKey: "readerFontSize")
        UserDefaults.standard.set(Float(lineSpacing), forKey: "readerLineSpacing")
        UserDefaults.standard.set(fontDesignRawValue, forKey: "readerFontDesign")
        UserDefaults.standard.set(colorScheme.rawValue, forKey: "readerColorScheme")
    }

    var backgroundColor: Color {
        switch colorScheme {
        case .light:
            return Color.white
        case .dark:
            return Color.black
        case .auto:
            return Color(.systemBackground)
        }
    }

    var textColor: Color {
        switch colorScheme {
        case .light:
            return Color.black
        case .dark:
            return Color.white
        case .auto:
            return Color(.label)
        }
    }

    private var fontDesignRawValue: Int {
        switch fontDesign {
        case .default: return 0
        case .serif: return 1
        case .rounded: return 2
        case .monospaced: return 3
        @unknown default: return 0
        }
    }

    private static func fontDesignFromRaw(_ raw: Int) -> Font.Design {
        switch raw {
        case 1: return .serif
        case 2: return .rounded
        case 3: return .monospaced
        default: return .default
        }
    }
}

enum ReaderColorScheme: Int {
    case light = 0
    case dark = 1
    case auto = 2
}

#Preview {
    BookReaderView(story: Story(
        id: "preview-story-1",
        userId: "preview-user",
        title: "Station Nine Is Forgetting",
        status: "active",
        premiseId: nil,
        bibleId: nil,
        generationProgress: nil,
        createdAt: Date(),
        chaptersGenerated: 6,
        seriesId: nil,
        bookNumber: 1,
        coverImageUrl: nil,
        genre: "Sci-Fi",
        description: "A mysterious space station adventure"
    ))
}
