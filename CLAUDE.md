# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Test Commands

```bash
# List available simulators (useful for finding device names)
xcrun simctl list devices available

# Build for iOS simulator
xcodebuild -project Ovlo.xcodeproj -scheme OvloPhone -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Build for watchOS simulator
xcodebuild -project Ovlo.xcodeproj -scheme OvloWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (42mm)' build

# Run all tests
xcodebuild -project Ovlo.xcodeproj -scheme OvloWatchTests -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (42mm)' test

# Run a single test class
xcodebuild -project Ovlo.xcodeproj -scheme OvloWatchTests -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (42mm)' test -only-testing:OvloWatchTests/BreathingEngineTests

# Run a single test method
xcodebuild -project Ovlo.xcodeproj -scheme OvloWatchTests -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (42mm)' test -only-testing:OvloWatchTests/BreathingEngineTests/testInitialState
```

## Architecture Overview

Ovlo is a breathing exercise app with an iOS companion app and watchOS app. The watch runs the breathing exercise; the iOS app sends start/stop commands.

**Targets**: iOS 26.0+, watchOS 26.0+

### Multi-Target Structure

- **OvloPhone/** - iOS companion app (sends commands to watch)
- **OvloWatch/** - watchOS app (runs breathing exercises)
- **OvloWatchTests/** - Unit tests

Shared code lives in `Shared/` at the project root and is compiled into both iOS and watchOS targets directly (no framework).

### Domain Layer (Watch App)

- `BreathingEngine` - Actor that manages breathing state machine (ready → inhaling → exhaling → completed). Publishes state via `AsyncStream<BreathingState>`. Accepts injected `ClockProtocol` and `HapticControllerProtocol` for testability.
- `BreathingState` - Enum representing breathing phases with associated progress values (0.0-1.0)
- `BreathingSession` - Configuration for a session (duration, inhale/exhale timing)

### Communication (Shared)

- `WatchConnectivityProtocol` - Protocol abstracting WatchConnectivity for dependency injection
- `WatchConnectivityManager` - Production implementation using WCSession
- `ConnectivityCommand` - Commands sent between devices (start/stop)

### ViewModel Layer

- `BreathingViewModel` (Watch) - Coordinates engine, connectivity, and UI. Handles incoming iOS commands.
- `SessionControlViewModel` (iOS) - Sends start/stop commands to watch, tracks connection state.

### Concurrency Model

- Uses modern Swift concurrency (`async/await`, `Actor`)
- `BreathingEngine` is an actor for thread-safe state management
- ViewModels use `@MainActor` and `@Observable` macro for SwiftUI reactivity
- State published via `AsyncStream` with proper task cancellation

### Testing Approach

Tests use dependency injection with protocols:
- `TestClock` - Returns immediately from `sleep()` for fast tests
- `MockHapticController` - Records feedback calls without hardware
- `MockWatchConnectivity` (in OvloWatchTests/) - Simulates connectivity

The engine uses 60 steps per breathing phase for smooth animation. Tests validate state transitions and haptic feedback counts.
