# Neverending Story - iOS App

A premium iOS reading app that generates never-ending AI-powered books. Built with SwiftUI, featuring Apple Books-style reading experience with beautiful typography and smooth animations.

## Project Structure

```
NeverendingStory/
├── NeverendingStoryApp.swift      # Main app entry point
├── Config/
│   └── AppConfig.swift            # API keys and configuration
├── Models/
│   ├── User.swift
│   ├── Story.swift
│   ├── Chapter.swift
│   └── Premise.swift
├── Services/
│   ├── AuthManager.swift          # Supabase authentication
│   ├── APIManager.swift           # Railway backend API
│   ├── ReadingStateManager.swift  # Reading progress tracking
│   └── VoiceSessionManager.swift  # OpenAI Realtime API
├── Views/
│   ├── LaunchView.swift
│   ├── Auth/
│   │   └── LoginView.swift
│   ├── Onboarding/
│   │   ├── OnboardingView.swift
│   │   └── PremiseSelectionView.swift
│   ├── Reader/
│   │   ├── BookReaderView.swift
│   │   └── ReaderSettingsView.swift
│   ├── Library/
│   │   ├── LibraryView.swift
│   │   └── FeedbackModalView.swift
│   └── Components/
│       ├── LoadingView.swift
│       ├── StoryCard.swift
│       └── PremiseCard.swift
└── Resources/
    └── Assets.xcassets
```

## Setup Instructions

### 1. Create Xcode Project

1. Open Xcode
2. File > New > Project
3. Choose "iOS" > "App"
4. Product Name: `NeverendingStory`
5. Organization Identifier: `com.yourname` (or your preference)
6. Interface: SwiftUI
7. Language: Swift
8. Save in the parent directory of these files

### 2. Add Source Files to Project

1. In Xcode, delete the default `ContentView.swift` and `NeverendingStoryApp.swift` that Xcode created
2. In Finder, drag the entire `NeverendingStory` folder into your Xcode project
3. Make sure "Copy items if needed" is checked
4. Select "Create groups"
5. Click Finish

### 3. Configure Dependencies (SPM)

1. In Xcode, select your project in the navigator
2. Select the "NeverendingStory" target
3. Go to "Package Dependencies" tab
4. Click the "+" button to add packages:

**Supabase Swift:**
- URL: `https://github.com/supabase/supabase-swift`
- Version: 2.0.0 or later
- Add to target: NeverendingStory

**OpenAI Swift (Optional - for voice features):**
- URL: `https://github.com/MacPaw/OpenAI`
- Version: 0.2.0 or later
- Add to target: NeverendingStory

### 4. Add Info.plist Entries

1. In your project, select the `Info.plist` file
2. Add the following keys (or copy from the provided Info.plist):

**Microphone Usage:**
- Key: `NSMicrophoneUsageDescription`
- Value: "We use your voice to understand your story preferences and create personalized book recommendations."

**URL Schemes (for OAuth):**
- Add a new URL Type with:
  - URL Schemes: `neverendingstory`
  - Role: Editor

### 5. Configure API Keys

1. Open `Config/AppConfig.swift`
2. Replace the placeholder values with your actual keys:

```swift
static let supabaseAnonKey = "YOUR_ACTUAL_SUPABASE_ANON_KEY"
static let openAIAPIKey = "YOUR_ACTUAL_OPENAI_API_KEY"
```

**To get your Supabase Anon Key:**
- Go to your Supabase project dashboard
- Settings > API
- Copy the `anon` `public` key

**To get your OpenAI API Key:**
- Go to https://platform.openai.com/api-keys
- Create a new API key

### 6. Build and Run

1. Select your target device or simulator
2. Press Cmd+R to build and run
3. The app should launch successfully

## Backend Configuration

The app connects to:
- **API Backend**: https://neverending-story-api-production.up.railway.app
- **Supabase**: https://hszuuvkfgdfqgtaycojz.supabase.co

Make sure these services are running and accessible.

## Features

### Authentication
- Google OAuth via Supabase
- Sign in with Apple
- Session persistence

### Onboarding
- Voice conversation with OpenAI Realtime API
- Visual audio feedback
- Manual premise selection option
- Choose from 3 AI-generated story premises

### Reading Experience
- Apple Books-style typography
- Customizable font size (14-24pt)
- Line spacing options (Compact, Normal, Relaxed)
- Theme options (Light, Dark, Auto)
- Swipe navigation between chapters
- Progress tracking and sync
- Pre-loading for seamless reading

### Library
- Active story card with "Continue Reading"
- Grid view of past stories
- Quick feedback system
- Start new story flow

## Testing Checklist

- [ ] Launch app → Shows splash screen
- [ ] First launch → Routes to login
- [ ] Google Sign In → OAuth flow works
- [ ] Apple Sign In → Authentication works
- [ ] Voice onboarding → Microphone permission
- [ ] Voice onboarding → Audio visualization
- [ ] Premise selection → Shows 3 options
- [ ] Select premise → Creates story
- [ ] Reader view → Displays chapter
- [ ] Reader view → Swipe navigation works
- [ ] Settings → Font size changes apply
- [ ] Settings → Theme switching works
- [ ] Library → Shows active story
- [ ] Library → Shows past stories
- [ ] Dark mode → All views look good
- [ ] Different screen sizes → Responsive layout

## Known Limitations

1. **OpenAI Realtime API**: The voice session implementation is a placeholder. Full WebSocket integration with OpenAI Realtime API requires:
   - Proper WebSocket connection with authentication
   - Audio format conversion (PCM to required format)
   - Bidirectional streaming
   - Response parsing and handling

2. **OAuth Callbacks**: The OAuth callback handling is implemented but needs testing with actual OAuth flows.

3. **Offline Support**: Currently requires internet connection. Future enhancement: Core Data for offline chapter caching.

4. **Chapter Pre-loading**: Basic implementation exists but could be optimized with predictive loading.

## Future Enhancements

- Offline chapter caching with Core Data/SwiftData
- Reading statistics and achievements
- Social features (share quotes, recommendations)
- Custom themes and font options
- Accessibility features (VoiceOver, Dynamic Type)
- iPad optimization with split view
- macOS version with Catalyst

## Troubleshooting

**Build Errors:**
- Make sure all SPM packages are resolved (File > Packages > Resolve Package Versions)
- Clean build folder (Cmd+Shift+K)
- Restart Xcode if needed

**Runtime Errors:**
- Check that API keys are set in AppConfig.swift
- Verify backend services are running
- Check network connectivity
- Review console logs for specific error messages

**Authentication Issues:**
- Verify Supabase project settings
- Check OAuth redirect URLs are configured
- Ensure URL scheme matches in Info.plist

## Support

For issues or questions:
1. Check the console logs for detailed error messages
2. Verify all configuration steps were completed
3. Test with the backend API directly (use curl or Postman)
4. Review Supabase authentication logs

---

Built with ❤️ using SwiftUI, Supabase, and OpenAI
