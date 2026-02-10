# Neverending Story - Quick Setup Guide

Follow these steps to get the iOS app up and running.

## Step 1: Create Xcode Project

1. **Open Xcode**
2. **File > New > Project**
3. Select **iOS** tab, choose **App** template
4. Configure project:
   - **Product Name**: `NeverendingStory`
   - **Organization Identifier**: `com.yourname` (or your preference)
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Storage**: None (we'll handle this ourselves)
   - **Include Tests**: Optional
5. **Save location**: Choose the directory containing the `NeverendingStory` folder
   - The final structure should be:
     ```
     YourChosenDirectory/
     ├── NeverendingStory.xcodeproj
     └── NeverendingStory/
         ├── NeverendingStoryApp.swift
         ├── Models/
         ├── Views/
         ├── Services/
         └── ...
     ```

## Step 2: Replace Default Files

Xcode will create some default files. Replace them:

1. **Delete** the default `ContentView.swift` file Xcode created
2. **Delete** the default `NeverendingStoryApp.swift` file Xcode created
3. Your project should now reference the files we created

## Step 3: Add Files to Xcode Project

1. In Xcode, right-click on the `NeverendingStory` group in the navigator
2. Select **Add Files to "NeverendingStory"...**
3. Navigate to the `NeverendingStory` folder
4. Select **all folders** (Models, Views, Services, Config, Resources)
5. Make sure these options are checked:
   - ✅ **Copy items if needed**
   - ✅ **Create groups** (not folder references)
   - ✅ **Add to targets: NeverendingStory**
6. Click **Add**

## Step 4: Add Swift Package Dependencies

### Add Supabase Swift

1. In Xcode, select your **project** (blue icon at top of navigator)
2. Select the **NeverendingStory** target
3. Go to **Package Dependencies** tab
4. Click **+** button
5. Enter URL: `https://github.com/supabase/supabase-swift`
6. **Dependency Rule**: Up to Next Major Version: `2.0.0`
7. Click **Add Package**
8. Select **Supabase** library
9. Click **Add Package**

### Add OpenAI Swift (Optional - for voice features)

1. Click **+** button again
2. Enter URL: `https://github.com/MacPaw/OpenAI`
3. **Dependency Rule**: Up to Next Major Version: `0.2.0`
4. Click **Add Package**
5. Select **OpenAI** library
6. Click **Add Package**

## Step 5: Configure Info.plist

1. In Xcode project navigator, select **Info.plist**
2. Right-click and select **Open As > Source Code**
3. Copy the contents from the `Info.plist` file we created
4. Paste to replace the default content (or add the necessary keys)

Key entries needed:
- `NSMicrophoneUsageDescription`
- `CFBundleURLTypes` (for OAuth callbacks)

## Step 6: Add API Keys

1. Open `Config/AppConfig.swift`
2. Replace placeholder values:

```swift
static let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY_HERE"
static let openAIAPIKey = "YOUR_OPENAI_API_KEY_HERE"
```

### Get Your Supabase Anon Key:
1. Go to https://hszuuvkfgdfqgtaycojz.supabase.co
2. Click on your project
3. Go to **Settings** > **API**
4. Copy the **anon public** key

### Get Your OpenAI API Key:
1. Go to https://platform.openai.com/api-keys
2. Create a new secret key
3. Copy and save it (you won't see it again!)

## Step 7: Build and Run

1. Select a simulator or device (iPhone 15 Pro recommended)
2. Press **Cmd + B** to build
3. Fix any build errors (should compile cleanly)
4. Press **Cmd + R** to run
5. App should launch with splash screen

## Step 8: Test the Flow

1. **Launch** → Should show "Neverending Story" splash
2. **Login** → Should show Google/Apple sign-in buttons
3. **Authenticate** → Try Google or Apple Sign In
4. **Onboarding** → Should show voice session or skip to premises
5. **Premises** → Should show 3 story options
6. **Reader** → Should display chapter with beautiful typography
7. **Settings** → Test font size and theme changes
8. **Library** → Return to see your stories

## Common Issues & Fixes

### Build Error: "No such module 'Supabase'"
- Go to **File > Packages > Resolve Package Versions**
- Clean build folder: **Cmd + Shift + K**
- Restart Xcode

### Build Error: Missing files
- Make sure all files were added to the target
- Check **Target Membership** in File Inspector

### Runtime Error: "Invalid API key"
- Verify you added the real keys to `AppConfig.swift`
- Check for extra spaces or quotes

### OAuth Not Working
- Verify URL scheme in Info.plist matches: `neverendingstory`
- Check Supabase OAuth settings
- Make sure redirect URL is configured: `neverendingstory://auth/callback`

### Voice Session Not Working
- Grant microphone permission when prompted
- Check OpenAI API key is valid
- Note: Full WebSocket implementation may need additional work

## Project Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    NeverendingStoryApp                       │
│                     (App Entry Point)                        │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
                   LaunchView
                    │      │
          ┌─────────┘      └─────────┐
          ▼                          ▼
      LoginView                 LibraryView
          │                          │
          ▼                          ├─ StoryCard (Active)
   OnboardingView                    ├─ Start New Story Button
          │                          └─ Past Stories Grid
          ├─ Voice Session                    │
          └─ PremiseSelectionView             ▼
                    │                   BookReaderView
                    └────────────────────────┘
                                              │
                                              ├─ Chapter Content
                                              ├─ Swipe Navigation
                                              └─ ReaderSettingsView
```

## Key Managers

- **AuthManager**: Handles Supabase authentication (Google/Apple OAuth)
- **APIManager**: Communicates with Railway backend API
- **ReadingStateManager**: Tracks current chapter and reading progress
- **VoiceSessionManager**: Manages OpenAI Realtime API voice sessions
- **ReaderSettings**: Manages user reading preferences (font, theme)

## Backend Integration

The app connects to:
- **Backend API**: `https://neverending-story-api-production.up.railway.app`
- **Supabase**: `https://hszuuvkfgdfqgtaycojz.supabase.co`

Ensure both services are running before testing.

## Next Steps

After successful setup:

1. **Test authentication** with real OAuth providers
2. **Complete voice integration** with OpenAI Realtime API
3. **Add error handling** for edge cases
4. **Implement offline caching** with Core Data
5. **Polish animations** and transitions
6. **Add haptic feedback** for interactions
7. **Test on physical device** for performance
8. **Submit for TestFlight** beta testing

## Resources

- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Supabase Swift SDK](https://github.com/supabase/supabase-swift)
- [OpenAI API Documentation](https://platform.openai.com/docs)
- [Apple HIG](https://developer.apple.com/design/human-interface-guidelines/)

---

**Questions or Issues?**
Review the console logs in Xcode for detailed error messages and debug information.

Happy coding! 📚✨
