#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# TVTimeClone — Mac Setup Script
# Run once from the TVTimeClone/ directory:  ./setup.sh
# ─────────────────────────────────────────────────────────────────────────────
set -e
cd "$(dirname "$0")"

BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RESET="\033[0m"

step() { echo -e "\n${BOLD}${CYAN}▶ $1${RESET}"; }
ok()   { echo -e "${GREEN}  ✓ $1${RESET}"; }
warn() { echo -e "${YELLOW}  ⚠ $1${RESET}"; }

echo -e "\n${BOLD}Riffy iOS App — Setup${RESET}"

# ── 1. Xcode ──────────────────────────────────────────────────────────────────
step "Checking Xcode"
if ! xcode-select -p &>/dev/null; then
  echo "Xcode not found. Install it from the Mac App Store, then re-run this script."
  exit 1
fi
ok "Xcode found at $(xcode-select -p)"

# ── 2. Homebrew ───────────────────────────────────────────────────────────────
step "Checking Homebrew"
if ! command -v brew &>/dev/null; then
  warn "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
ok "Homebrew ready"

# ── 3. XcodeGen ───────────────────────────────────────────────────────────────
step "Checking XcodeGen"
if ! command -v xcodegen &>/dev/null; then
  warn "Installing XcodeGen..."
  brew install xcodegen
fi
ok "XcodeGen $(xcodegen --version 2>/dev/null || echo '') ready"

# ── 4. Supabase CLI (optional — for running migrations locally) ───────────────
step "Checking Supabase CLI"
if ! command -v supabase &>/dev/null; then
  warn "Installing Supabase CLI..."
  brew install supabase/tap/supabase
fi
ok "Supabase CLI ready"

# ── 5. Generate Xcode project ─────────────────────────────────────────────────
step "Generating Xcode project"
xcodegen generate
ok "TVTimeClone.xcodeproj created"

# ── 6. Check credentials ──────────────────────────────────────────────────────
step "Credential check"
CONFIG="Sources/TVTimeClone/App/Config.swift"

if grep -q "YOUR_PROJECT_ID" "$CONFIG"; then
  warn "Supabase credentials not set yet."
  echo "  → Create a free project at https://supabase.com"
  echo "  → Copy your URL + anon key from Project Settings → API"
  echo "  → Fill them into: $CONFIG"
else
  ok "Supabase credentials found"
fi

if grep -q "YOUR_GOOGLE_CLIENT_ID" "$CONFIG"; then
  warn "Google OAuth not configured yet."
  echo "  → console.cloud.google.com → APIs & Services → Credentials → New OAuth 2.0 Client (iOS)"
  echo "  → Bundle ID: com.rifat.tvtimeclone"
  echo "  → Copy Client ID into: $CONFIG"
  echo "  → Also add the reversed client ID to project.yml → GOOGLE_REVERSED_CLIENT_ID"
  echo "  → Then re-run: xcodegen generate"
else
  ok "Google OAuth credentials found"
fi

# ── 7. Supabase migration hint ────────────────────────────────────────────────
step "Database setup"
echo "  Run the migration in your Supabase dashboard:"
echo "  1. Go to https://supabase.com → your project → SQL Editor"
echo "  2. Paste and run: supabase/migrations/001_initial.sql"
echo ""
echo "  Or with the Supabase CLI (after 'supabase login'):"
echo "    supabase db push --project-ref YOUR_PROJECT_ID"

# ── 8. Open Xcode ─────────────────────────────────────────────────────────────
step "Opening Xcode"
if [ -d "TVTimeClone.xcodeproj" ]; then
  open TVTimeClone.xcodeproj
  ok "Xcode opened"
else
  warn "TVTimeClone.xcodeproj not found — xcodegen may have failed above."
fi

# ── Final instructions ────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}─────────────────────────────────────────────────────────${RESET}"
echo -e "${BOLD}What you still need to do in Xcode:${RESET}"
echo ""
echo "  1. Select the TVTimeClone target → Signing & Capabilities"
echo "     → Set your Team (your Apple ID)"
echo ""
echo "  2. Add the 'Sign in with Apple' capability"
echo "     (click + Capability → Sign in with Apple)"
echo ""
echo "  3. Fill in Supabase + Google credentials in Config.swift"
echo "     (if not done already)"
echo ""
echo "  4. Choose your iPhone/simulator and press ▶ to build"
echo -e "${BOLD}─────────────────────────────────────────────────────────${RESET}"
echo ""
