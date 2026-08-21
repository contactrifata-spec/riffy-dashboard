# TVTimeClone — iOS Setup Guide

A native SwiftUI TV/movie tracking app with Supabase auth and TMDB data.

## Quick Start

### 1. Create an Xcode project

1. Open Xcode → **File → New → Project**
2. Choose **iOS → App**
3. Product Name: `TVTimeClone`
4. Interface: **SwiftUI**, Language: **Swift**
5. Minimum Deployment: **iOS 17.0**

### 2. Add Swift Package dependencies

In Xcode → File → Add Package Dependencies:

| Package | URL | Version |
|---------|-----|---------|
| Supabase Swift | `https://github.com/supabase/supabase-swift` | `≥ 2.0.0` |
| Google Sign-In | `https://github.com/google/GoogleSignIn-iOS` | `≥ 7.0.0` |

Select these products to add:
- **Supabase** (from supabase-swift)
- **Auth** (from supabase-swift)
- **GoogleSignIn** (from GoogleSignIn-iOS)

### 3. Copy source files

Copy all `.swift` files from `Sources/TVTimeClone/` into your Xcode project, preserving the folder structure.

### 4. Configure API Keys

**Supabase** (`SupabaseManager.swift`):
```swift
private let supabaseURL    = URL(string: "https://YOUR_PROJECT_ID.supabase.co")!
private let supabaseAnonKey = "YOUR_ANON_KEY"
```
Get these from: [supabase.com](https://supabase.com) → Your Project → Settings → API

**TMDB** (`TMDBService.swift`):
```swift
private let tmdbAPIKey = "YOUR_TMDB_API_KEY"
```
Get this from: [themoviedb.org](https://www.themoviedb.org) → Settings → API → Create (Developer)

### 5. Set up the database

In Supabase dashboard → SQL Editor, run the full contents of:
```
supabase/migrations/001_initial.sql
```

### 6. Configure Apple Sign In

In Xcode → Target → Signing & Capabilities:
- Click **+ Capability**
- Add **Sign In with Apple**

### 7. Configure Google Sign In

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create an OAuth 2.0 Client ID (iOS type)
3. Download `GoogleService-Info.plist` and add it to the Xcode project
4. Add the `GIDSignIn` URL scheme in Info.plist:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>YOUR_REVERSED_CLIENT_ID</string>
    </array>
  </dict>
</array>
```

5. In Supabase dashboard → Authentication → Providers → Google, add your Client ID and Secret

6. Wire up the sign-in button in `AuthView.swift`:
```swift
import GoogleSignIn

Button("Sign in with Google") {
    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let root = scene.windows.first?.rootViewController else { return }
    GIDSignIn.sharedInstance.signIn(withPresenting: root) { result, error in
        guard let user = result?.user,
              let idToken = user.idToken?.tokenString else { return }
        let nonce = authVM.prepareAppleSignIn() // reuses nonce helper
        Task { await authVM.signInWithGoogle(idToken: idToken, nonce: nonce) }
    }
}
```

### 8. Configure Supabase Auth Providers

In Supabase → Authentication → Providers:
- **Email**: enable, confirm emails optional for development
- **Apple**: add your Apple Team ID, Key ID, and private key (from [developer.apple.com](https://developer.apple.com))
- **Google**: add your Client ID and Secret

---

## Architecture Overview

```
TVTimeClone/
├── App/
│   ├── TVTimeCloneApp.swift      # App entry, session check
│   └── ContentView.swift         # TabView + custom tab bar
├── Theme/
│   └── AppTheme.swift            # Colors, animations, button styles
├── Services/
│   ├── SupabaseManager.swift     # Auth + all DB operations
│   └── TMDBService.swift         # TMDB API calls (shows, movies, search)
├── Models/
│   └── Models.swift              # All Codable models
├── Auth/
│   ├── AuthViewModel.swift       # Auth state + sign-in logic
│   └── AuthView.swift            # Login / Sign-up UI
├── Components/
│   └── HapticManager.swift       # UIKit haptic wrappers
└── Views/
    ├── Shows/
    │   ├── ShowsTab.swift         # Keep Watching + Up to Date grid
    │   ├── ShowsViewModel.swift   # Status logic (watching/upToDate/finished)
    │   └── ShowDetailView.swift   # Season accordion + episode marking
    ├── Movies/
    │   └── MoviesTab.swift        # Movie grid, add/detail
    ├── Discover/
    │   └── DiscoverTab.swift      # Trending + multi-search
    └── Profile/
        └── ProfileTab.swift       # Profile header, stats, watched history
```

## Show Status Logic

| Condition | Status | Where shown |
|-----------|--------|-------------|
| Has unwatched aired episodes | `watching` | **Keep Watching** (main Shows tab) |
| All aired eps watched, show returning | `up_to_date` | **Up to Date** grid (main Shows tab) |
| All eps watched, show ended/cancelled | `finished` | **Profile → Watched Shows** only |
| User manually dropped | `dropped` | **Profile → Watched Shows** (with badge) |

## Design Principles (Benji.org / iOS native)

- **Spring animations** everywhere: `response: 0.32–0.5`, `dampingFraction: 0.6–0.85`
- **Press-scale feedback**: 0.92–0.96 scale on every tappable card/button
- **Haptics**: light on navigation, medium on actions, success on confirmations
- **Matched geometry**: use `matchedGeometryEffect` for hero transitions (Show card → Detail)
- **Morphing**: transition between tabs with `.asymmetric` insertion/removal moves
