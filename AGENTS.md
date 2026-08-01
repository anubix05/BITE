# AI Meal Tracker – Development Guide

> This document is the single source of truth for every AI coding agent working on this project.

---

# Product Vision

Build a beautiful, premium, AI-powered nutrition tracking application that feels effortless.

The application should feel less like a calorie tracker and more like chatting with an intelligent nutrition assistant.

The user should never feel like they are filling out forms.

The primary goal is:

> **Describe what you ate. Let the AI do the rest.**

Every design and engineering decision should reduce friction.

Whenever implementing a feature, ask:

> **Can this be made simpler for the user?**

If yes, redesign it.

---

# Core Philosophy

The application must be:

* Local-first
* Offline-first
* Privacy-first
* AI-assisted
* Fast
* Beautiful
* Minimal
* Beginner-friendly

The application should work well for someone who has never used a calorie tracker before.

---

# Primary UX Philosophy

The UX should be inspired by applications like Journable.

DO NOT copy the UI.

Instead, copy the philosophy.

Users should type naturally.

Examples:

* One plate chicken biryani
* Two eggs and toast
* Half bowl oats
* One banana
* Chicken shawarma and Pepsi
* Ate pizza around 8 PM
* One Starbucks cappuccino

The app should understand these naturally.

Never force users to fill complicated forms.

---

# Input Methods

The application supports four ways to log meals.

## 1. Natural Language (Primary)

Users simply type.

Examples:

"I had one full plate chicken biryani."

"2 dosa and sambar."

"Half bowl oats."

"One glass milk."

This should be the primary experience.

---

## 2. Photo

Users can take a picture.

AI analyzes the meal.

---

## 3. Photo + Description

Users may optionally add context.

Example

Photo

*

"One full plate with extra chicken and less rice."

Both image and text are analyzed.

---

## 4. Voice

Users can speak naturally.

Speech

↓

Text

↓

Gemini

↓

Meal

No additional work required from users.

---

# AI Philosophy

AI is an assistant.

AI is NOT authoritative.

Users always have the final decision.

Every AI-generated result must be editable.

Never permanently save AI output before user confirmation.

---

# Portion Understanding

The AI should understand natural serving sizes.

Examples

Half plate

Full plate

Large plate

Small bowl

Large bowl

One bowl

Glass

Cup

Slice

Packet

Serving

Handful

Palm-sized

One banana

Two eggs

Medium apple

If ambiguous,

estimate reasonably.

Return confidence.

---

# Smart Follow-up Questions

Do NOT ask unnecessary questions.

Only ask when required.

Example

User:

Chicken biryani

AI:

Was it

• Small plate

• Medium plate

• Large plate

Keep follow-up questions minimal.

---

# Gemini Integration

Gemini is used only for:

* Food recognition
* Portion estimation
* Nutrition estimation
* Natural language understanding

Gemini should always return strict JSON.

Never markdown.

Never explanations.

Never prose.

Always use a predefined JSON schema.

---

# Data Privacy

User data belongs to the user.

Never upload:

Meal history

Statistics

Goals

Settings

Analytics

Historical meals

Only send information required for AI analysis.

---

# Offline First

Everything except AI analysis must work offline.

Offline features:

Meal history

Dashboard

Statistics

Search

Import

Export

Settings

Editing meals

Charts

Calendar

---

# Local Storage

Use Isar.

Store locally:

Meals

Meal items

Settings

Goals

Preferences

Images

Notes

History

No cloud database.

---

# Image Storage

Store images locally.

Compress before saving.

Remove EXIF metadata.

Store only image paths in the database.

---

# Meal Model

Each meal stores:

* id
* createdAt
* updatedAt
* date
* time
* mealType
* originalUserInput
* aiInterpretation
* imagePath
* notes
* aiConfidence
* totalCalories
* totalProtein
* totalCarbs
* totalFat
* totalFiber
* totalSugar
* totalSodium

Meal Items

Each item stores:

* name
* servingDescription
* estimatedWeight
* calories
* protein
* carbs
* fat
* fiber
* sugar
* sodium

---

# Preserve Original Input

Always save:

What the user typed.

Example

Original

"One plate chicken biryani"

AI Interpretation

Chicken Biryani

1 Full Plate

520 g

890 kcal

This allows future AI improvements.

---

# User Corrections

If users modify AI results,

save both:

Original AI output

AND

Final edited values.

User edits always win.

---

# Dashboard

The Home screen should immediately answer:

How much have I eaten today?

How much is left?

Am I on track?

No scrolling should be required.

---

# Nutrition Goals

Users can configure:

Daily Calories

Daily Protein

Daily Carbs

Daily Fat

Future

Fiber

Sugar

Sodium

Water

Goals are stored locally.

---

# Settings

Settings should contain:

Nutrition Goals

Theme

Backup

Restore

Image Compression

AI Settings

Units

About

Future notification settings

---

# Daily Tracking

Meals are grouped by local calendar date.

Store:

Date

Time

Timestamp

Meal Type

Display:

Breakfast

Lunch

Dinner

Snacks

Late Night

Automatically infer meal type using time.

Users can change it.

---

# Nutrition Snapshot

At the top of the dashboard display:

Today's Calories

Remaining Calories

Protein

Carbs

Fat

Large progress indicators.

Example

Calories

1700 / 2200 kcal

Protein

120 / 150 g

Carbs

180 / 220 g

Fat

55 / 70 g

This should be visible immediately when opening the app.

---

# Progress Indicators

Animate progress.

Show:

Calories

Protein

Carbs

Fat

Use circular indicators.

Progress colors

Below goal

Primary color

Near goal

Success color

Exceeded goal

Warning color

Never shame users.

---

# Meal Timeline

Display meals chronologically.

Example

08:15

Breakfast

Eggs

Toast

320 kcal

---

13:10

Lunch

Chicken Biryani

890 kcal

---

19:40

Dinner

Grilled Chicken

Rice

620 kcal

The timeline should feel like a journal.

---

# History

Users can:

Search

Edit

Delete

Duplicate

Favorite meals

History should remain smooth with thousands of meals.

---

# Analytics

Support

Daily

Weekly

Monthly

Analytics include:

Calories

Protein

Carbs

Fat

Average intake

Most eaten foods

Meal frequency

Streaks (future)

Calendar view

---

# Historical Recalculation

Editing any meal should automatically recalculate:

Daily totals

Weekly averages

Monthly averages

Charts

Macro totals

Progress indicators

History should always remain accurate.

---

# Calendar

Calendar colors

Green

Goal achieved

Yellow

Near goal

Gray

No meals

Selecting a day opens that day's journal.

---

# Import & Export

Users own their data.

Support full backup.

Backup format

ZIP

Contents

meals.json

images/

settings.json

version.json

Support:

Export

Import

Merge

Restore

Never overwrite without confirmation.

---

# Performance

Cold start under two seconds.

Scrolling should remain smooth with over 10,000 meals.

Never block the UI thread.

Use isolates where appropriate.

---

# UI Design

Use Material 3.

Premium.

Modern.

Minimal.

Lots of whitespace.

Rounded corners.

Smooth animations.

Support:

Light Mode

Dark Mode

System Theme

Inspiration:

Apple Health

Linear

Notion

Journable's simplicity

---

# Animations

Use subtle animations.

Examples:

Fade

Scale

Hero

Slide

Avoid excessive motion.

---

# Accessibility

Support:

Large fonts

Screen readers

High contrast

Large touch targets

Semantic labels

---

# Code Standards

Flutter

Latest stable version

State Management

Riverpod

Navigation

GoRouter

Networking

Dio

Charts

fl_chart

Architecture

Feature-first

Composition over inheritance.

Repository pattern.

SOLID principles.

Keep widgets small.

Functions should have a single responsibility.

Avoid duplicate logic.

---

# Security

Never expose Gemini API keys.

Use a secure backend proxy for Gemini requests.

Validate every AI response.

Never trust external input.

---

# Error Handling

If AI confidence is low,

ask for clarification.

Never fabricate meals.

Never silently fail.

Always explain errors clearly.

---

# Future Features

Barcode Scanner

Recipe Builder

Restaurant Database

Water Tracking

Weight Tracking

Workout Tracking

Nutrition Labels

Widgets

Wear OS

Apple Watch

Cloud Sync (optional)

Family Profiles

Macro Coaching

Meal Suggestions

AI Nutrition Insights

---

# Things AI Must Never Do

Never overwrite user edits.

Never delete data automatically.

Never upload history.

Never expose secrets.

Never fabricate nutritional values without making it clear they are estimates.

Never perform irreversible actions without confirmation.

Never make the user fill unnecessary forms.

Never prioritize technical convenience over user experience.

---

# Golden Rule

Every feature should satisfy this principle:

**"A first-time user should be able to log a meal in under 10 seconds without reading instructions."**

If a feature increases friction instead of reducing it, redesign it until it feels effortless.

---

# Implemented Features Status (v2.0.0)

The following features have been fully implemented, built, and verified in the codebase:

### 1. Meal Logging & AI Parsing
- [x] **Natural Language Text Logging**: Flexible input parsing (e.g. *"1 plate chicken biryani and Pepsi"*).
- [x] **Photo & Multimodal Logging**: Camera/Gallery photo analysis with optional context instructions.
- [x] **Smart Meal Memory**: Favorite and save meals to local memory for instant 1-tap re-logging.
- [x] **Strict JSON AI Integration**: Structured response mapping via Gemini 2.5 Flash API with user-editable results.

### 2. Dashboard & Navigation
- [x] **Nutrition Snapshot**: Macro progress indicators (Calories, Protein, Carbs, Fat) vs local daily goals with progress colors.
- [x] **Journal Timeline**: Chronological daily meal list with quick edit, favorite toggle, and delete options.
- [x] **Jump to Today Button**: Instant date reset across Dashboard, History, and Calendar headers.

### 3. History & Analytics
- [x] **Searchable Meal History**: Real-time keyword filtering, date range navigation, and swipe-to-delete with undo.
- [x] **Interactive Macro Trends**: 7-day, 4-week, and 3-month charts powered by `fl_chart` with average intake metrics.

### 4. Calendar View
- [x] **Google Calendar Style Month Slider**: Smooth, real-time horizontal `PageView.builder` month sliding with haptic feedback.
- [x] **Selected Date Auto-Focus**: Calendar automatically focuses on the active selected date's month.
- [x] **Color-Coded Status Tiles**: Green (within goal), Red (exceeded goal), Gray (no data).

### 5. Settings, Themes & Data Privacy
- [x] **Nutrition Goals Config**: Customizable daily targets (Calories, Protein, Carbs, Fat) via expressive sliders or direct numeric entry.
- [x] **Material 3 Expressive Design**: System, Light, and Dark mode support + 9 custom theme color accents with clean Light Mode indicators.
- [x] **Gemini API Key Management**: Custom API key override setting saved securely in local preferences.
- [x] **Offline-First & Local Storage**: 100% local database powered by Isar DB; zero cloud analytics or history uploads.
- [x] **ZIP Export & Import**: Native Android Storage Access Framework file saving menu + smart deduplicating backup restoration.
