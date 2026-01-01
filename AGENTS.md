# AGENTS.md

Guidance for AI agents working with this codebase.

## Build Commands

```bash
# Build iOS
xcodebuild -project Ovlo.xcodeproj -scheme OvloPhone -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Build watchOS
xcodebuild -project Ovlo.xcodeproj -scheme OvloWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (42mm)' build

# Run iOS tests
xcodebuild -project Ovlo.xcodeproj -scheme OvloPhoneTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# Run watchOS tests
xcodebuild -project Ovlo.xcodeproj -scheme OvloWatchTests -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (42mm)' test

# Run single test class
xcodebuild ... test -only-testing:OvloPhoneTests/BreathingEngineTests
```

## Architecture

Ovlo is a breathing and meditation app for iOS (18.6+) and watchOS (11.6+).

### Session Types (iOS)
- **Breathe** - Guided breathing with animated circle
- **Guided** - Play meditation audio (duration from file length)
- **Music** - Ambient music with optional affirmations

watchOS only supports Breathe mode.

### Project Structure

```
Shared/Models/          - BreathingSession (shared between platforms)
OvloPhone/
  Domain/               - Business logic (engines, controllers, managers)
  ViewModels/           - State management (@Observable, @MainActor)
  Views/                - SwiftUI components
  Resources/            - Audio config JSON files
OvloWatch/              - Mirrors iOS structure (breathing only)
```

### Key Components

| Component | Purpose |
|-----------|---------|
| `BreathingEngine` | Actor managing breathing state machine (ready→inhaling→exhaling→completed) |
| `BreathingViewModel` | Coordinates engine, haptics, music for breathing sessions |
| `AmbientMusicViewModel` | Timed music playback with affirmations |
| `GuidedMeditationViewModel` | Single-play audio with progress tracking |
| `MusicController` | AVAudioPlayer wrapper with fade-out support |
| `AudioController` | Phase transition chime playback |
| `SettingsManager` | UserDefaults persistence (singleton) |

### Audio Configuration

Audio files are gitignored. Configure via JSON:

| File | Location | Purpose |
|------|----------|---------|
| `chimes.json` | `Resources/Chimes/` | Phase transition sounds |
| `music.json` | `Resources/Music/` | Ambient tracks (iOS) |
| `meditations.json` | `Resources/Meditations/` | Guided audio (iOS) |

Format: `[{"id": "file-name", "title": "Display Name"}]`

### Concurrency Model

- `BreathingEngine` is an **actor** for thread-safe state
- ViewModels use `@MainActor` + `@Observable`
- State distributed via `AsyncStream<BreathingState>`
- Task cancellation handled in deinit

### Testing

Dependency injection enables fast, deterministic tests:
- `TestClock` - Instant sleep() for timing tests
- `MockHapticController` - Records feedback calls
- `MockMusicController` - Simulates playback
- `MockExtendedRuntimeController` (watchOS) - Background execution

### watchOS Specifics

- `ExtendedRuntimeController` - WKExtendedRuntimeSession for background breathing
- Only chimes (no music/meditations)
- Same BreathingEngine architecture
