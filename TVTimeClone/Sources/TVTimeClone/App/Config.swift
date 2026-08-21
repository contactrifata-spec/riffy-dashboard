import Foundation

/// Central credentials file.
/// Fill in your Supabase values after creating a free project at supabase.com
enum AppConfig {

    // ── Supabase ────────────────────────────────────────────────────────────
    // TODO: Replace with your values from:
    //   supabase.com → Your Project → Settings → API
    static let supabaseURL     = "https://YOUR_PROJECT_ID.supabase.co"
    static let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY"

    // ── TMDB ────────────────────────────────────────────────────────────────
    // Already set — themoviedb.org API v3 key
    static let tmdbAPIKey = "20c0d3d9d1860192cf158a49462bdc80"

    // ── Google Sign-In ──────────────────────────────────────────────────────
    // TODO: Replace after setting up Google OAuth in Google Cloud Console
    //   console.cloud.google.com → APIs & Services → Credentials → OAuth 2.0 Client (iOS)
    //   Then enable Google provider in Supabase → Authentication → Providers → Google
    static let googleClientID        = "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com"
    static let googleReversedClientID = "com.googleusercontent.apps.YOUR_GOOGLE_CLIENT_ID"
}
