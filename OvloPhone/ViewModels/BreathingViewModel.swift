import Foundation
import os
import SwiftUI

private let logger = Logger(subsystem: "com.ovlo.phone", category: "BreathingViewModel")

/// View model for the iOS breathing interface.
///
/// Coordinates between:
/// - BreathingEngine (domain logic)
/// - SwiftUI views (UI updates)
@MainActor
@Observable
public final class BreathingViewModel {
    // MARK: - Published State
    private(set) var currentState: BreathingState = .ready
    private(set) var elapsedSeconds: Int = 0
    private(set) var totalSeconds: Int = 0
    private(set) var currentAffirmation: String?
    var selectedDuration: Int = 5
    var selectedInhale: Int = 4
    var selectedExhale: Int = 8

    var currentInhaleDuration: TimeInterval {
        currentSession?.inhaleDuration ?? TimeInterval(selectedInhale)
    }

    var currentExhaleDuration: TimeInterval {
        currentSession?.exhaleDuration ?? TimeInterval(selectedExhale)
    }

    // MARK: - Dependencies
    private let engine: BreathingEngine
    private let idleTimerController: IdleTimerControllerProtocol

    // MARK: - Private State
    private var currentSession: BreathingSession?
    private var sessionStartTime: Date?
    private var lastPhaseWasExhaling: Bool = false
    // Note: nonisolated(unsafe) is required for Task properties that need cleanup in deinit
    // since deinit runs in a nonisolated context. Task.cancel() is thread-safe.
    private nonisolated(unsafe) var stateTask: Task<Void, Never>?
    private nonisolated(unsafe) var progressTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Creates a new breathing view model.
    /// - Parameters:
    ///   - engine: The breathing engine
    ///   - idleTimerController: Controller for preventing screen lock during sessions
    public init(
        engine: BreathingEngine,
        idleTimerController: IdleTimerControllerProtocol = IdleTimerController()
    ) {
        self.engine = engine
        self.idleTimerController = idleTimerController
        startStateObservation()
    }

    // MARK: - Public API

    public func startSession(_ session: BreathingSession) async {
        currentSession = session
        totalSeconds = session.actualDurationSeconds
        elapsedSeconds = 0
        sessionStartTime = Date()
        lastPhaseWasExhaling = false

        // Initialize affirmation if enabled
        if SettingsManager.shared.isAffirmationsEnabled {
            AffirmationManager.shared.shuffle()
            currentAffirmation = AffirmationManager.shared.nextAffirmation()
        } else {
            currentAffirmation = nil
        }

        idleTimerController.disableIdleTimer()
        await engine.start(session: session)
        startProgressTracking()
    }

    public func startLocalSession() async {
        let session = BreathingSession(
            durationMinutes: selectedDuration,
            inhaleDuration: TimeInterval(selectedInhale),
            exhaleDuration: TimeInterval(selectedExhale)
        )
        await startSession(session)
    }

    public func stopSession() async {
        await engine.stop()
        progressTask?.cancel()
        progressTask = nil
        sessionStartTime = nil
        currentSession = nil
        elapsedSeconds = 0
        currentAffirmation = nil
        idleTimerController.enableIdleTimer()
    }

    /// Completes the session early, showing the completion screen instead of returning to ready.
    public func completeSessionEarly() async {
        await engine.stop()
        progressTask?.cancel()
        progressTask = nil
        currentState = .completed
        currentAffirmation = nil
        idleTimerController.enableIdleTimer()
    }

    // MARK: - Private Implementation

    private func startStateObservation() {
        stateTask = Task { [weak self] in
            guard let self = self else { return }

            let stream = await engine.stateStream

            for await state in stream {
                await MainActor.run {
                    self.updateAffirmationIfNeeded(for: state)
                    self.currentState = state
                    if state == .completed {
                        self.currentAffirmation = nil
                        self.idleTimerController.enableIdleTimer()
                    }
                }
            }
        }
    }

    /// Detects breath cycle boundaries and updates affirmation when a new cycle starts.
    private func updateAffirmationIfNeeded(for state: BreathingState) {
        // Detect cycle boundary: transitioning from exhaling to inhaling
        if case .inhaling = state, lastPhaseWasExhaling {
            if SettingsManager.shared.isAffirmationsEnabled {
                currentAffirmation = AffirmationManager.shared.nextAffirmation()
            }
        }
        lastPhaseWasExhaling = state.isExhaling
    }

    private func startProgressTracking() {
        progressTask?.cancel()

        progressTask = Task { @MainActor [weak self] in
            guard let self = self else { return }

            while !Task.isCancelled {
                if let startTime = self.sessionStartTime {
                    let elapsed = Int(Date().timeIntervalSince(startTime))
                    self.elapsedSeconds = elapsed
                }

                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    deinit {
        stateTask?.cancel()
        progressTask?.cancel()
    }
}
