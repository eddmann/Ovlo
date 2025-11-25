import Foundation
import os
import SwiftUI
import WatchConnectivity

private let logger = Logger(subsystem: "com.ovlo.app", category: "SessionControl")

/// View model for iOS app that controls breathing sessions on the watch.
///
/// Handles:
/// - Sending start/stop commands to the watch
/// - Managing connection state
/// - Tracking current session state
@MainActor
@Observable
public final class SessionControlViewModel {
    // MARK: - Published State
    private(set) var isConnected: Bool = false
    private(set) var isSessionActive: Bool = false
    private(set) var connectionError: String?

    // MARK: - Dependencies
    private let connectivity: WatchConnectivityProtocol

    // MARK: - Task Management
    // Note: nonisolated(unsafe) is required for Task properties that need cleanup in deinit
    // since deinit runs in a nonisolated context. Task.cancel() is thread-safe.
    private nonisolated(unsafe) var connectionPollingTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(connectivity: WatchConnectivityProtocol) {
        self.connectivity = connectivity
        observeConnectionState()
    }

    // MARK: - Public API

    public func startSession(durationMinutes: Int, inhale: Int, exhale: Int) {
        guard !isSessionActive else { return }

        let message: [String: Any] = [
            ConnectivityMessageKey.command: ConnectivityCommand.start.rawValue,
            ConnectivityMessageKey.duration: durationMinutes,
            ConnectivityMessageKey.inhale: inhale,
            ConnectivityMessageKey.exhale: exhale
        ]

        connectivity.sendMessage(
            message,
            replyHandler: { [weak self] _ in
                Task { @MainActor in
                    self?.isSessionActive = true
                    self?.connectionError = nil
                    logger.info("Session started successfully")
                }
            },
            errorHandler: { [weak self] error in
                Task { @MainActor in
                    self?.connectionError = "Failed to start session: \(error.localizedDescription)"
                    self?.isSessionActive = false
                    logger.error("Failed to start session: \(error.localizedDescription)")
                }
            }
        )

        isSessionActive = true
    }

    public func stopSession() {
        guard isSessionActive else { return }

        let message: [String: Any] = [
            ConnectivityMessageKey.command: ConnectivityCommand.stop.rawValue
        ]

        connectivity.sendMessage(
            message,
            replyHandler: { [weak self] _ in
                Task { @MainActor in
                    self?.isSessionActive = false
                    self?.connectionError = nil
                    logger.info("Session stopped successfully")
                }
            },
            errorHandler: { [weak self] error in
                Task { @MainActor in
                    self?.connectionError = "Failed to stop session: \(error.localizedDescription)"
                    logger.error("Failed to stop session: \(error.localizedDescription)")
                }
            }
        )

        isSessionActive = false
    }

    // MARK: - Private Implementation

    private func observeConnectionState() {
        #if os(iOS)
        if WCSession.isSupported() {
            let session = WCSession.default
            isConnected = session.isPaired && session.isWatchAppInstalled && session.isReachable
        }

        connectionPollingTask?.cancel()
        connectionPollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))

                guard let self = self else { break }

                if WCSession.isSupported() {
                    let session = WCSession.default
                    self.isConnected = session.isPaired && session.isWatchAppInstalled && session.isReachable
                }
            }
        }
        #endif
    }

    deinit {
        connectionPollingTask?.cancel()
    }
}
