# NursaFlow — Flutter App

AI Study Companion for Nursing Students. Built from the "Clinical Clarity" Stitch
design export, implemented as a fully responsive Flutter app (mobile + tablet +
desktop/web) using Riverpod + go_router.

## Getting started

```bash
flutter pub get
flutter run
```

This project was written without a local Flutter SDK available in the build
sandbox, so it has **not** been run through `flutter analyze` / `flutter build`.
Run those first thing after pulling it into your IDE:

```bash
flutter analyze
```

Likely first-run fixes:
- A few `Symbols.*` icon names (e.g. `stethoscope`, `clinical_notes`) come from
  the newer Material Symbols set — if `material_symbols_icons` hasn't caught up
  yet in your pinned version, swap for the closest `Icons.*` equivalent.
- If `IconButton.filled` or `NavigationRail` param names don't match, bump your
  Flutter SDK — this was written against a recent stable (3.24+).

## What's wired up vs. stubbed

**Fully built (UI only, mock data):**
- Onboarding (3-page swipeable intro)
- Sign Up / Log In (toggle, form validation)
- Home dashboard, Library (with course filter), Study hub
- Upload flow (file picker wired, course/tag selection)
- Document Summary, Flashcards (flip + swipe), Quiz (with results screen)
- AI Tutor chat (mock responses)
- Study Planner (weekly view, task checklist, add-exam sheet)
- Profile / Settings
- Subscription screen (Free vs Premium, monthly/annual toggle)

**Stubbed — look for `// TODO:` comments:**
- Firebase Auth (email + Google Sign-In) in `sign_up_screen.dart`
- Document upload → Storage → Cloud Function pipeline in `upload_screen.dart`
- AI Tutor responses (currently canned) in `ai_tutor_screen.dart`
- Paystack checkout call in `subscription_screen.dart`
- Firestore-backed documents/flashcards/quizzes (currently in
  `features/home/models/document.dart` and inline mock lists per screen)

## Backend wiring (Firebase Cloud Functions, per your Blaze decision)

1. `flutterfire configure` in the project root — generates `firebase_options.dart`
   and registers iOS/Android/Web apps against your Firebase project.
2. Uncomment the `Firebase.initializeApp(...)` lines in `lib/main.dart`.
3. Set a budget alert on the Blaze project immediately (Firebase Console →
   Usage and billing → Details & settings → Budget alert) — this is the thing
   that would've saved you the StreetSpoon surprise.
4. Suggested Cloud Functions to build next (names match the TODOs in code):
   - `analyzeDocument` — triggered on Storage upload, calls Gemini (via
     Firebase AI Logic) to produce summary/flashcards/quiz, writes to Firestore.
   - `askTutor` — callable function, forwards a chat turn + document context to
     Gemini, returns the response.
   - `paystack-initialize` / `paystack-webhook` — same HMAC-SHA512 verification
     pattern you already built for StreetSpoon, just pointed at subscription
     plans instead of order payments.

## Design system reference

Colors, spacing, and type scale live in `lib/core/theme/`. They were extracted
directly from the Stitch `DESIGN.md` — if the Stitch design changes, update
those three files rather than hunting through individual screens.

Responsive breakpoints (`lib/core/utils/responsive.dart`):
- Mobile: < 600px — single column, bottom tab bar
- Tablet: 600–1024px — 2-column grids, side NavigationRail
- Desktop: > 1024px — 3-column grids, content capped at 1200px, side NavigationRail

To get your debug SHA-1 (for local testing — you'll need a separate release SHA-1 later when you publish to Play Store)
cd ~/Downloads/nursaflow/android
./gradlew signingReport
