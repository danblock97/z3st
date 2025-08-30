# Z3st — Setup, Tests, Supabase SQL, and Manual QA

This guide helps you run unit tests, configure environment variables, initialize Supabase (tables, RLS, storage, delete-account RPC), and manually test the app end‑to‑end including widgets, reminders, Health, and offline behavior.

## 1) Prerequisites

- Xcode 16+ and iOS 16+ simulator/device
  - iOS 16+: Charts, Widgets (static), App Intents framework available (used by intents; widget uses deep link fallback)
  - iOS 17+: Quick Log widget uses AppIntent buttons (background logging)
- Swift Package: supabase-swift (2.x+)
  - Xcode → Project → Package Dependencies → + → https://github.com/supabase-community/supabase-swift

## 2) Run Unit Tests

- In Xcode: select the Z3st scheme → Product → Test (Cmd‑U).
- Or CLI (example):
  - xcodebuild -project Z3st.xcodeproj -scheme Z3st -destination 'platform=iOS Simulator,name=iPhone 15' test

What’s covered:
- Quiet hours window logic and date adjustment
- Reminder suggestions + filtering
- Units (mL/oz) conversions
- CSV export format
- History range date math
- Offline pending logs enqueue/remove

## 3) Environment Variables and Capabilities

Set these for the App target (and Widget where relevant):

- Required (App target → Run scheme → Environment Variables)
  - SUPABASE_URL = https://<your-project>.supabase.co
  - SUPABASE_ANON_KEY = <anon-key>
  - SUPABASE_STORAGE_BUCKET = profile-pictures
- App Groups (for widget sharing today’s total and unit)
  - Create an App Group, e.g. group.com.yourteam.z3st
  - Signing & Capabilities → add App Groups to App and Widget targets → enable same group ID
  - Provide the group ID one of two ways:
    - Preferred: Set “AppGroupID” Info key on both targets to your group id; for the widget this is already in Z3stWidget/Info.plist. For the App, build settings inject it; set the $(APP_GROUP_ID) value (Build Settings → User‑Defined or set as an environment variable in your Run scheme) to your group id so it resolves into Info.
    - Alternative: Set APP_GROUP_ID in both targets’ Run scheme Environment Variables.
- Background Tasks
  - App target → Signing & Capabilities → Background Modes → enable “Background fetch” (used for adaptive reminders + offline sync).
- HealthKit
  - App target → Signing & Capabilities → add HealthKit.
- URL Scheme (deep link fallback for widget quick log)
  - Already added via build settings: scheme is z3st. No action required unless you changed product bundle.
- Notifications
  - No extra capability needed; app requests permission on first launch.

## 4) Supabase SQL (run in order)

Open Supabase Dashboard → SQL Editor and run each file’s contents in this order:

1. supabase/01_tables.sql
   - Creates public.users linked to auth.users (onboarding profile) and public.water_entries
   - Enables RLS on both tables
2. supabase/02_storage.sql
   - Creates public storage bucket profile-pictures (public read)
   - RLS so users can write/manage files only in their <uid>/ folder
3. supabase/03_policies.sql
   - RLS for users and water_entries (user‑only access)
4. supabase/04_delete_account.sql
   - SECURITY DEFINER function public.delete_current_user() calling auth.delete_user(auth.uid())
   - Grants EXECUTE to authenticated
5. supabase/05_water_source.sql
   - Adds source text column to water_entries (default 'app')
   - Unique index on (user_id, created_at, volume_ml, source) to avoid Health import duplicates

Notes:
- Ensure your tables show Row Level Security ON for users and water_entries.
- The storage bucket is public‑read by design; write/delete restricted to the owner’s folder.

## 5) First Run (App)

- Ensure supabase-swift is added and env vars are set (see section 3).
- Build and run on simulator or device.
- Authentication
  - Sign up or sign in. On success you’ll be routed into onboarding.
  - Email confirmation handling:
    - Dev: If you disable confirmations in Supabase, sign-up returns a session and proceeds to onboarding.
    - Prod: With confirmations enabled, the app shows a “Check your email” screen. Tapping the email link returns to the app/site and creates a session.
- Onboarding
  - Add full name, daily goal (mL), and optionally upload a profile photo (stored at profile-pictures/<uid>/profile.jpg).
- Dashboard
  - See Today summary and history; pick a range (7D/30D/1Y/All).
  - Chart toggle (Line/Area) persists between launches.
  - Share icon exports the visible range as CSV via share sheet.
- Logging
  - Use preset buttons or segmented picker to log amounts. Offline logs queue and sync on reconnection or background refresh.
- Reminders
  - Enable reminders, set inactivity nudge hours, Apply Schedule.
  - Settings → Quiet hours: set your window; Apply Schedule filters times outside this window.
  - “Recompute now” uses your last 30 days to propose times and respects quiet hours.
- Health Sync (optional)
  - Settings → enable “Sync with Apple Health”. You can “Import last 30 days” once to pull water from Health. No continuous backfill beyond that.
- Profile
  - Edit profile (name/goal/photo). Delete Account performs a self‑service deletion via SQL function.

## 6) Widgets (and Quick Log)

- Add the “Z3st Water” widget to your Home/Lock Screen
  - Displays today’s total (shared via App Group).
  - iOS 17: Quick log buttons use AppIntentButton to log in background.
  - iOS 16: Buttons use deep links; app opens and logs immediately.
- “Z3st Quick Log” (iOS 17+)
  - Add the configurable widget, choose two quick log amounts (in mL). Labels adapt to your selected unit.

If totals don’t show:
- Verify App Group is enabled for both app and widget and the ID is provided (Info key or APP_GROUP_ID environment variable).

## 7) Manual QA Checklist

- Auth → Onboarding: Create user, set name/goal, upload avatar → profile row created, avatar loads.
- Log water: Preset quick logs, segmented picker log; Today total updates; inactivity nudge scheduled.
- History: Switch ranges; chart updates; CSV export downloads correct dates and totals.
- Reminders: Enable, Apply; check system notification schedule; set Quiet hours and Apply; “Recompute now” adapts from history, filtered by Quiet.
- Health: Enable sync and import last 30 days; confirm no duplicates; turn off sync if desired.
- Offline: Disable network, log water; re‑enable network, launch app; queued logs sync.
- Widget: Add widgets; confirm Today total matches app; tap Quick Log → entry logged (deep link opens the app and logs immediately).
- Delete Account: Profile → Delete Account → account removed; sign‑in requires a new account.

## 8) Troubleshooting

- Supabase 401/403
  - Check SUPABASE_URL and SUPABASE_ANON_KEY environment variables are set on the Run scheme.
  - RLS must be enabled; policies from 03_policies.sql must be present.

## 10) Auth Redirects (Custom Scheme)

- Redirect target used by the app when signing up or resending confirmation:
  - Env var: `SUPABASE_AUTH_REDIRECT`
    - Recommended value: `z3st://auth-callback`
    - Set this on the Run scheme (Edit Scheme → Run → Arguments → Environment Variables).

- Custom URL scheme in Xcode:
  - In your app target → Info → URL Types, add a URL scheme `z3st`.
  - The app already handles `z3st://auth-callback` in `onOpenURL` to exchange the URL for a Supabase session.

- Supabase Auth settings:
  - Add `z3st://auth-callback` to “Additional Redirect URLs”.
  - The client passes `redirectTo` on sign-up and when resending confirmation, so the email links return to the app.

- Email templates:
  - Supabase uses the client-provided `redirectTo` value for confirmation links. No extra hosting or Universal Links are required.
- Avatars not loading
  - Ensure profile-pictures bucket exists and public read policy is applied; file path is <uid>/profile.jpg.
- Widget shows 0 mL
  - Ensure App Group is enabled for both targets and group ID is provided (Info key or APP_GROUP_ID var).
  - Open the app to refresh Today total; it writes to shared defaults.
- Background refresh timing
  - iOS schedules app refresh opportunistically; manual “Recompute now” is available in Reminders.

## 9) Security & Privacy

- All sensitive keys are read from environment variables at runtime (no checked‑in secrets).
- RLS limits data access to the authenticated user.
- Avatar bucket is public‑read by design; write/delete restricted to the owner’s folder.
- Health data access is user‑consented; only dietary water is read/written.

---

You’re ready to: run tests → set env vars → run SQL → build and test the app. If you want CI for tests or signed archive steps, I can add a minimal Fastlane/GitHub Actions setup next.

## 10) Current Widget Embedding Status (important)

- To keep builds green without provisioning, the app target is currently NOT embedding the widget extension.
- You can still build the widget target itself (Z3stWidget) to validate it compiles.
- When you’re ready to embed the widget (after your App ID quota resets or provisioning is configured):
  1) Ensure bundle identifiers
     - App: `app.z3st.z3st.Z3st`
     - Widget: `app.z3st.z3st.Z3st.Z3stWidget` (must be prefixed by the app’s ID)
     - Both targets use the same Team (Signing & Capabilities)
  2) Re‑add embed phase
     - Z3st target → Build Phases → + → New Copy Files Phase
     - Name: “Embed App Extensions”, Destination: PlugIns
     - Add `Z3stWidget.appex`; tick “Code Sign On Copy”
  3) Clean build folder (Shift+Cmd+K) and build
  4) If Xcode shows provisioning warnings for the widget, either:
     - Let Xcode manage signing once your App ID limit resets, or
     - Create a provisioning profile for the widget ID in the Developer portal and select it in Signing

Notes on AppIntents/Configurable widget:
- The widget currently uses deep links for Quick Log (reliable and zero entitlements).
- If you later want iOS 17 background logging (AppIntentButton), I can introduce a tiny shared module to host the intent and logging client that both app and widget import, then switch the widget buttons back to AppIntentButton.
