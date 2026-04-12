# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Jouzu is an iOS app for Japanese language learning. Users photograph Japanese text, which is OCR'd, tokenized, and enriched with dictionary/grammar data. Vocabulary can be saved to a spaced-repetition review system (SM-2 algorithm), and the app now includes a config-gated sync foundation for future Google Sheet syncing.

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
- **Translation** framework - on-device translation (iOS 18+)
- **SQLite3** (C bindings) - dictionary lookups
- **AVFoundation** - camera capture

## Architecture

**MVVM with feature-based modules.** Each feature has its own View + ViewModel pair.

### Processing Pipeline

Image capture -> `OCRService` (Vision) -> `TokenizerService` (MeCab) -> `DictionaryService` (SQLite/in-memory fallback) + `GrammarService` -> Translation session -> displayed as color-coded tokens with tap-for-detail popovers.

### Key Directories

- `Jouzu/App/` - App entry point (`JouzuApp.swift`) and root `ContentView` (3-tab TabView: Camera, Vocabulary, Review)
- `Jouzu/Features/` - Feature modules: `Camera/`, `Analysis/`, `Review/`, `VocabList/`
- `Jouzu/Features/Sync/` - Sync status UI shown from the Vocabulary screen
- `Jouzu/Models/` - `VocabCard` (SwiftData + sync metadata), `Token`, `AnalysisResult`, preview sample data
- `Jouzu/Services/` - `OCRService`, `TokenizerService`, `DictionaryService`, `GrammarService`, `GoogleSheetSyncService`, `AppUserIdentity`
- `JouzuTests/` - Unit tests (SM-2 algorithm coverage)

### Important Patterns

- ViewModels use `@Observable` macro with `@MainActor`
- `TokenizerService` has a fallback to character-level tokenization when MeCab is unavailable
- `Token.PartOfSpeech` enum uses Japanese labels (for example `名詞`, `動詞`) matching MeCab output
- Grammar highlighting is color-coded by part of speech
- `PreviewSampleData.swift` provides factory functions and an in-memory `ModelContainer` for previews
- Sync is local-first and config-gated; without sync config, the UI should remain disabled rather than attempting network requests

## Configuration

- `project.yml` - XcodeGen project spec (bundle ID: `com.jouzu.app`)
- Portrait orientation only
- Camera and photo library permissions declared in `project.yml` Info.plist settings
- Google Sheet sync config keys live in `Jouzu/Info.plist`:
  - `GOOGLE_SHEET_SYNC_BASE_URL`
  - `GOOGLE_SHEET_SYNC_API_KEY`
- Do not commit real sync secrets; keep committed values empty and use local overrides when testing a live backend
