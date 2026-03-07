# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Jouzu is an iOS app for Japanese language learning. Users photograph Japanese text, which is OCR'd, tokenized, and enriched with dictionary/grammar data. Vocabulary can be saved to a spaced-repetition review system (SM-2 algorithm).

## Today's Update (March 7, 2026)

- Removed **Recognized Text** and **Translation** sections from the capture analysis screen.
- Added filtering so non-Japanese tokens are removed before word enrichment/display.
- Updated the **Words** section to show lexical words only and hide particles.

## Build & Run

This project uses **XcodeGen** for project generation and **Swift Package Manager** for dependencies.

```bash
# Regenerate Xcode project after changing project.yml
xcodegen generate

# List destinations on the local machine
xcodebuild -scheme Jouzu -showdestinations

# Build via command line using a valid destination from above
xcodebuild -scheme Jouzu -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## Tech Stack

- **Swift 6.0** / **SwiftUI** / **iOS 18.0+** minimum
- **SwiftData** for persistence (`VocabCard` model)
- **MeCab-Swift** (external) - Japanese morphological analysis + IPA dictionary
- **Vision** framework - OCR for Japanese text recognition
- **Translation** framework - on-device fallback translation for missing dictionary definitions (iOS 18+)
- **SQLite3** (C bindings) - dictionary lookups
- **AVFoundation** - camera capture

## Architecture

**MVVM with feature-based modules.** Each feature has its own View + ViewModel pair.

### Processing Pipeline

Image capture -> `OCRService` (Vision) -> `TokenizerService` (MeCab) -> `JapaneseTokenFilter` (Japanese tokens only, particles removed) -> `DictionaryService` (SQLite/in-memory fallback) + `GrammarService` -> optional Translation fallback -> displayed as color-coded word tokens with tap-for-detail popovers.

### Key Directories

- `Jouzu/App/` - App entry point (`JouzuApp.swift`) and root `ContentView` (3-tab TabView: Camera, Vocabulary, Review)
- `Jouzu/Features/` - Feature modules: `Camera/`, `Analysis/`, `Review/`, `VocabList/`
- `Jouzu/Models/` - `VocabCard` (SwiftData), `Token`, `AnalysisResult`, preview sample data
- `Jouzu/Services/` - `OCRService`, `TokenizerService`, `DictionaryService`, `GrammarService`
- `JouzuTests/` - Unit tests (SM-2 algorithm coverage)

### Important Patterns

- ViewModels use `@Observable` macro with `@MainActor`
- `TokenizerService` has a fallback to character-level tokenization when MeCab is unavailable
- `Token.PartOfSpeech` enum uses Japanese labels (for example `名詞`, `動詞`) matching MeCab output
- Capture analysis intentionally omits full recognized-text and full-translation sections; it shows the filtered words grid only
- Grammar highlighting is color-coded by part of speech
- `PreviewSampleData.swift` provides factory functions and an in-memory `ModelContainer` for previews

## Configuration

- `project.yml` - XcodeGen project spec (bundle ID: `com.jouzu.app`)
- Portrait orientation only
- Camera and photo library permissions declared in `project.yml` Info.plist settings
