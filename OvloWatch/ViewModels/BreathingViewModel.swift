import Foundation
import os
import SwiftUI

private let logger = Logger(subsystem: "com.ovlo.watch", category: "BreathingViewModel")

/// View model for the watch breathing interface.
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
    var selectedDuration: Int = SettingsManager.shared.breathingDuration
    var selectedInhale: Int = SettingsManager.shared.breathingInhale
    var selectedExhale: Int = SettingsManager.shared.breathingExhale

    var currentInhaleDuration: TimeInterval {
        currentSession?.inhaleDuration ?? TimeInterval(selectedInhale)
    }

    var currentExhaleDuration: TimeInterval {
        currentSession?.exhaleDuration ?? TimeInterval(selectedExhale)
    }

    // MARK: - Dependencies
    private let engine: BreathingEngine
    private let extendedRuntimeController: ExtendedRuntimeControllerProtocol?

    // MARK: - Private State
    private var currentSession: BreathingSession?
    private var sessionStartTime: Date?
    // Note: nonisolated(unsafe) is required for Task properties that need cleanup in deinit
    // since deinit runs in a nonisolated context. Task.cancel() is thread-safe.
    private nonisolated(unsafe) var stateTask: Task<Void, Never>?
    private nonisolated(unsafe) var progressTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Creates a new breathing view model.
    /// - Parameters:
    ///   - engine: The breathing engine
    ///   - extendedRuntimeController: Controller for background execution (optional)
    public init(
        engine: BreathingEngine,
        extendedRuntimeController: ExtendedRuntimeControllerProtocol? = nil
    ) {
        self.engine = engine
        self.extendedRuntimeController = extendedRuntimeController

        startStateObservation()
    }

    // MARK: - Public API

    public func startSession(_ session: BreathingSession) async {
        currentSession = session
        totalSeconds = session.actualDurationSeconds
        elapsedSeconds = 0
        sessionStartTime = Date()

        await extendedRuntimeController?.startSession()
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
        await extendedRuntimeController?.invalidateSession()
        progressTask?.cancel()
        progressTask = nil
        sessionStartTime = nil
        currentSession = nil
        elapsedSeconds = 0
    }

    /// Completes the session early, showing the completion screen instead of returning to ready.
    public func completeSessionEarly() async {
        await engine.stop()
        await extendedRuntimeController?.invalidateSession()
        progressTask?.cancel()
        progressTask = nil
        currentState = .completed
    }

    // MARK: - Private Implementation

    private func startStateObservation() {
        stateTask = Task { [weak self] in
            guard let self = self else { return }

            let stream = await engine.stateStream

            for await state in stream {
                await MainActor.run {
                    self.currentState = state
                }

                // Invalidate extended runtime when session completes naturally
                if state == .completed {
                    await self.extendedRuntimeController?.invalidateSession()
                }
            }
        }
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
