# Bite 🍽️

> **Describe what you ate. Let the AI do the rest.**

A premium, AI-powered Flutter meal tracker. Local-first, offline-first, privacy-first. Powered by Gemini AI.

## Features

- **Natural language logging** — "One plate chicken biryani", "2 eggs and toast"
- **Photo recognition** — Snap a photo, AI identifies and estimates nutrition
- **Voice input** — Speak naturally
- **Real-time dashboard** — Animated macro rings showing progress vs. goals
- **Meal timeline** — Chronological journal-style view
- **History** — Searchable, swipe-to-delete
- **Analytics** — 7-day / 4-week / 3-month calorie & macro charts
- **Calendar** — Color-coded goal tracking
- **Privacy-first** — Everything stored locally via Isar. Only meal text/photo sent to Gemini.

## Setup

### 1. Gemini API Key

Get a free key from [Google AI Studio](https://aistudio.google.com).

Add it to `.env`:
```
GEMINI_API_KEY=your_key_here
```

### 2. Install dependencies & generate code
```sh
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Run
```sh
flutter run
```

## Architecture

Feature-first with Riverpod state management:

```
lib/
├── core/          # DB, AI, theme, router, shared widgets
└── features/
    ├── dashboard/     # Home, nutrition snapshot, timeline
    ├── log_meal/      # Text / photo / voice logging + AI result
    ├── meal_detail/   # View/edit a confirmed meal
    ├── history/       # Search & browse past meals
    ├── analytics/     # fl_chart nutrition trends
    ├── calendar/      # Color-coded monthly calendar
    └── settings/      # Goals, theme, AI key
```

## Tech Stack

| | |
|---|---|
| **Framework** | Flutter 3.44+ |
| **State** | Riverpod + riverpod_annotation |
| **Navigation** | GoRouter |
| **Database** | Isar (local) |
| **AI** | Google Gemini 2.5 Flash |
| **Charts** | fl_chart |
