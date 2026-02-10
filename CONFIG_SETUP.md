# Local Configuration Setup

## API Keys Configuration

Your API keys are stored locally in `AppConfig.local.swift` which is **not committed to git** for security.

### Current Setup:

1. **AppConfig.swift** (committed to GitHub)
   - Contains placeholder values: `YOUR_SUPABASE_ANON_KEY` and `YOUR_OPENAI_API_KEY`
   - This is the public configuration file

2. **AppConfig.local.swift** (local only, in .gitignore)
   - Contains your actual API keys
   - This file is ignored by git and won't be pushed

### How to Use:

The app should work as-is on your local machine since `AppConfig.local.swift` exists with your real keys.

### For Other Developers:

When someone clones this repository, they need to:

1. Copy `AppConfig.local.swift.example` to `AppConfig.local.swift`
2. Add their own API keys to `AppConfig.local.swift`

### Your API Keys (saved locally):

- **Supabase Anon Key**: Configured in `AppConfig.local.swift`
- **OpenAI API Key**: Configured in `AppConfig.local.swift`

### Security Notes:

✅ API keys are NOT in git history
✅ AppConfig.local.swift is in .gitignore
✅ Safe to push to GitHub
✅ Your keys remain private

---

**Important**: The app in Xcode will use the placeholder values from `AppConfig.swift` unless you update it to use the local config extension.

Let me know if you want me to update the app to automatically use the local config when available!
