//
//  BookReaderView.swift
//  NeverendingStory
//
//  Core reading experience - Apple Books style
//

import SwiftUI

struct BookReaderView: View {
    let story: Story

    @StateObject private var readingState = ReadingStateManager.shared
    @StateObject private var readerSettings = ReaderSettings.shared

    @State private var showControls = false
    @State private var showSettings = false
    @State private var scrollPosition: CGFloat = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Reading area
            ScrollView {
                ScrollViewReader { proxy in
                    VStack(alignment: .leading, spacing: 0) {
                        if let chapter = readingState.currentChapter {
                            // Chapter title
                            Text(chapter.title)
                                .font(.system(size: 28, weight: .bold, design: .default))
                                .padding(.top, 40)
                                .padding(.bottom, 32)
                                .padding(.horizontal, 24)
                                .frame(maxWidth: .infinity, alignment: .center)

                            // Chapter content
                            Text(chapter.content)
                                .font(.system(
                                    size: readerSettings.fontSize,
                                    weight: .regular,
                                    design: readerSettings.fontDesign
                                ))
                                .lineSpacing(readerSettings.lineSpacing)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 60)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("content")
                        } else {
                            LoadingView("Loading chapter...")
                        }
                    }
                    .background(
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: geometry.frame(in: .named("scroll")).minY
                            )
                        }
                    )
                }
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollPosition = value
                readingState.updateScrollPosition(Double(value))
            }
            .background(readerSettings.backgroundColor)
            .foregroundColor(readerSettings.textColor)

            // Top controls overlay
            if showControls {
                VStack {
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
                    .padding(.top, 8)

                    Spacer()
                }
                .transition(.opacity)
            }

            // Bottom progress indicator
            VStack {
                Spacer()

                if let chapter = readingState.currentChapter {
                    HStack {
                        Spacer()
                        Text("Chapter \(chapter.chapterNumber) of \(readingState.chapters.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color(.systemGray6).opacity(0.9)))
                        Spacer()
                    }
                    .padding(.bottom, 16)
                    .opacity(showControls ? 1 : 0.3)
                }
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: !showControls)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls.toggle()
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    // Swipe left for next chapter
                    if value.translation.width < -100 && readingState.canGoToNextChapter {
                        withAnimation {
                            readingState.goToNextChapter()
                        }
                    }
                    // Swipe right for previous chapter
                    else if value.translation.width > 100 && readingState.canGoToPreviousChapter {
                        withAnimation {
                            readingState.goToPreviousChapter()
                        }
                    }
                }
        )
        .sheet(isPresented: $showSettings) {
            ReaderSettingsView()
        }
        .task {
            do {
                try await readingState.loadStory(story)
            } catch {
                print("Failed to load story: \(error)")
            }
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
        id: "1",
        userId: "user1",
        title: "The Last Archive",
        genre: "Mystery",
        premise: "A mysterious archive...",
        currentChapter: 1,
        totalChapters: 15,
        createdAt: Date(),
        updatedAt: Date(),
        isActive: true
    ))
}
