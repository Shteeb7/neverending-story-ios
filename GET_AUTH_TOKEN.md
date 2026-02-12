# How to Get Your Auth Token for Testing

## Option 1: From Xcode Logs (Easiest)

1. Launch the app in Xcode
2. Log in (if not already logged in)
3. Search the console for: `Added Authorization header`
4. You'll see a log like:
   ```
   ✅ Added Authorization header with Supabase access token
   ```
5. Add a temporary print statement to see the token (see below)

## Option 2: Add Temporary Debug Log

Add this to `APIManager.swift` around line 93:

```swift
request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
NSLog("🔑 DEBUG TOKEN: %@", accessToken)  // <-- ADD THIS LINE
request.setValue(userIdToUse, forHTTPHeaderField: "X-User-ID")
```

Then rebuild, launch app, and check console for `🔑 DEBUG TOKEN:`

## Option 3: Use the Test Script with Any Request

The auth token is in every API request. Look for logs like:
```
🌐 Making request to: https://neverending-story-api-production.up.railway.app/...
   Headers: ["Authorization": "Bearer eyJhbGc...", ...]
```

Copy the part after `Bearer ` (the `eyJhbGc...` part).

## Once You Have the Token:

Run the test script:
```bash
cd "neverending-story-api"
./test-onboarding-flow.sh
```

It will:
1. Ask for your token
2. Test health endpoint
3. Test authentication
4. Test /process-transcript
5. Test /generate-premises

This validates the ENTIRE backend flow in ~3 minutes without the voice interview!
