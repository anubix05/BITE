<p align="center">
  <img src="assets/images/splash_logo_light.png" alt="Bite App Logo" width="200" />
</p>

# Bite

> Describe what you ate. Let the AI do the rest.

Bite is a privacy-first Flutter meal tracker that turns natural language, photos, and optional voice input into structured meal logs. It is built to feel fast, calm, and low-friction while keeping all user data local with Isar.

## What It Does

Bite focuses on four main experiences:

- Natural language meal logging like “one plate chicken biryani” or “2 eggs and toast”.
- Photo-based meal analysis with optional extra context.
- Daily nutrition tracking with calories and macro snapshots.
- Local history, analytics, calendar review, backup, and restore.

The app saves the original user input alongside the AI interpretation so edits can always be compared against the source text later.

## Verified Features

- Meal logging with text, photo, and photo-plus-description input.
- Gemini-based meal interpretation, portion estimation, and nutrition estimation.
- Low-confidence follow-up handling before saving AI output.
- Dashboard with today’s calories, remaining calories, protein, carbs, fat, and meal timeline.
- History screen with searchable logs and analytics tabs.
- Calendar month navigation with day-status coloring and drill-in to a selected day.
- Meal detail editing for values, date/time, favorites, deletion, and re-analysis.
- Onboarding for personal info, goals, permissions, and optional Gemini key setup.
- Settings for goals, personal info, theme, custom color, reminders, saved meals, backup/restore, and Gemini API key.
- ZIP export and import containing meals, settings, version metadata, and images.
- Local-first storage with Isar and no cloud meal database.

## Tech Stack

| Area | Stack |
|---|---|
| UI | Flutter, Material 3, Google Fonts, Dynamic Color |
| State | Riverpod |
| Navigation | GoRouter |
| Storage | Isar |
| AI | Google Gemini |
| Charts | fl_chart |
| Media | image_picker, flutter_svg, image compression utilities |
| Backup | archive, file_picker, share_plus |

## Project Structure

The codebase follows a feature-first layout:

```text
lib/
├── app.dart
├── main.dart
├── core/
│   ├── ai/
│   ├── database/
│   ├── models/
│   ├── router/
│   ├── services/
│   ├── theme/
│   └── widgets/
└── features/
    ├── analytics/
    ├── calendar/
    ├── dashboard/
    ├── history/
    ├── log_meal/
    ├── meal_detail/
    ├── onboarding/
    └── settings/
```

## Getting Started

### Prerequisites

- Flutter SDK 3.3 or newer
- Android Studio or VS Code with Flutter tooling
- A Gemini API key from Google AI Studio if you want AI meal parsing

### Setup

1. Install dependencies.
   ```bash
   flutter pub get
   ```

2. Generate code.
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

3. Optionally add a `.env` file in the project root.
   ```env
   GEMINI_API_KEY=your_gemini_api_key_here
   ```

4. Launch the app.
   ```bash
   flutter run
   ```

On Windows, `run.ps1` is also available for the Android workflow used in this workspace.

## Testing

Run the test suite with:

```bash
flutter test
```

The repository includes coverage for routing, onboarding, nutrition calculations, meal tracking, calendar status logic, backup import/export, settings migration, and widget screens.

## Build

Build a release APK with:

```bash
flutter build apk --release --split-per-abi
```

## Privacy

- Meals, settings, goals, and photos are stored locally on the device.
- The app does not use a cloud meal database.
- AI processing only receives the meal content needed for analysis.
- Users can export or restore their data through ZIP backup.

## Current Version

Version: 3.0.2+35

## License

Open source for personal use.
