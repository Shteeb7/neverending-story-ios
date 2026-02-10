# Quick Start Guide

Get your iOS app running in 5 simple steps!

## 🚀 5-Minute Setup

### Step 1: Create Xcode Project (2 min)
```
1. Open Xcode
2. File > New > Project
3. Choose: iOS > App
4. Name: NeverendingStory
5. Interface: SwiftUI
6. Save in parent directory of the NeverendingStory folder
```

### Step 2: Add Source Files (1 min)
```
1. In Xcode, delete default ContentView.swift and NeverendingStoryApp.swift
2. Drag the NeverendingStory folder into your Xcode project
3. Check "Copy items if needed"
4. Select "Create groups"
5. Click Add
```

### Step 3: Add Dependencies (1 min)
```
1. Select project > Target > Package Dependencies
2. Click + button
3. Add: https://github.com/supabase/supabase-swift
4. Add: https://github.com/MacPaw/OpenAI
5. Wait for resolution (~30 seconds)
```

### Step 4: Configure API Keys (30 sec)
```
Open: Config/AppConfig.swift

Replace:
static let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY_HERE"
static let openAIAPIKey = "YOUR_OPENAI_API_KEY_HERE"

With your actual keys.
```

### Step 5: Build & Run (30 sec)
```
1. Select iPhone 15 Pro simulator
2. Press Cmd + R
3. App should launch with splash screen!
```

## 📋 Checklist

- [ ] Xcode project created
- [ ] Source files added to project
- [ ] Supabase Swift package installed
- [ ] OpenAI Swift package installed
- [ ] Info.plist configured (use provided one)
- [ ] API keys added to AppConfig.swift
- [ ] Project builds without errors
- [ ] App runs on simulator

## ⚡ First Run Test Flow

Once running, test this sequence:

1. **Launch** → See "Neverending Story" splash
2. **Login** → See Google/Apple sign-in buttons
3. **Tap Google** → OAuth flow should initiate
4. **After Auth** → Navigate to library (empty state)
5. **Tap "Start New Story"** → Go to onboarding
6. **Tap "Skip voice"** → Go to premise selection
7. **View 3 Premises** → Should load from API
8. **Select one** → Should create story
9. **Enter Reader** → See beautiful typography
10. **Tap Settings** → Adjust font size
11. **Swipe left** → Next chapter (if available)
12. **Tap back** → Return to library

## 🔑 Getting API Keys

### Supabase Anon Key
```
1. Go to: https://hszuuvkfgdfqgtaycojz.supabase.co
2. Select your project
3. Settings > API
4. Copy "anon public" key
```

### OpenAI API Key
```
1. Go to: https://platform.openai.com/api-keys
2. Create new secret key
3. Copy and save immediately
```

## 🐛 Quick Troubleshooting

**Build Error: "No such module 'Supabase'"**
```
Solution: File > Packages > Resolve Package Versions
Then: Cmd + Shift + K (Clean Build)
```

**Runtime Error: "Invalid API key"**
```
Solution: Check AppConfig.swift - make sure keys are correct
Remove any extra spaces or quotes
```

**OAuth Not Working**
```
Solution: Check Info.plist has URL scheme: neverendingstory
Verify Supabase OAuth settings
```

**Voice Session Crashes**
```
Solution: Grant microphone permission when prompted
Test on physical device (not simulator)
```

## 📱 Recommended Test Devices

- iPhone 15 Pro (simulator) - Primary testing
- iPhone SE (simulator) - Small screen testing
- Your physical iPhone - Real-world testing

## 🎯 What Should Work Immediately

✅ App launch and splash screen
✅ Navigation between views
✅ UI animations and transitions
✅ Dark mode switching
✅ Reading settings (font, theme)
✅ Library empty state
✅ All UI components and layouts

## 🔧 What Needs API Keys

🔑 Google/Apple authentication
🔑 Premise generation
🔑 Story creation
🔑 Chapter loading
🔑 Progress syncing
🔑 Voice conversation

## 📚 Documentation

Detailed guides:
- **README.md** - Complete overview
- **SETUP_GUIDE.md** - Detailed setup
- **IMPLEMENTATION_CHECKLIST.md** - Feature list
- **PROJECT_SUMMARY.md** - Technical details
- **STRUCTURE.txt** - File organization

## 💡 Pro Tips

1. **Use Xcode Previews**: Each view has `#Preview` for quick iteration
2. **Check Console**: Comprehensive logging for debugging
3. **Test Dark Mode**: Cmd+Shift+A to toggle appearance
4. **Hot Reload**: Cmd+R rebuilds and preserves state
5. **Breakpoints**: Add breakpoints for debugging auth flow

## 🎉 Success Indicators

You'll know it's working when:
- ✅ App builds without errors
- ✅ Splash screen shows on launch
- ✅ Login view displays auth buttons
- ✅ UI looks polished and smooth
- ✅ Animations are fluid
- ✅ Dark mode works correctly
- ✅ All fonts render properly

## 🚨 Common First-Run Issues

| Issue | Solution |
|-------|----------|
| White screen on launch | Check console for errors, verify files are added |
| Can't build project | Resolve SPM packages, clean build folder |
| OAuth buttons don't work | Add real API keys, check backend is running |
| No premises show | Verify API endpoint is accessible |
| Reader looks wrong | Check that fonts are using system defaults |
| Dark mode broken | Verify using semantic colors (.label, .systemBackground) |

## ⏱️ Estimated Times

- Xcode project creation: 2 minutes
- Adding files: 1 minute
- SPM package resolution: 1-2 minutes
- API key configuration: 1 minute
- First build: 2-3 minutes
- **Total: ~10 minutes**

## 🎬 Ready to Launch?

Once you've completed the 5 steps above:

1. Select simulator/device
2. Press Cmd + R
3. Wait for build
4. See your app come to life!

---

**Need help?** Check the detailed guides or console logs for errors.

**Everything working?** Time to add your API keys and test the full flow!

🎉 **Happy Coding!**
