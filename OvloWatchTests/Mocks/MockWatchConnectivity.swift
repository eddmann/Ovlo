import Foundation
@testable import OvloWatch

/// Mock watch connectivity for testing message passing.
///
/// Records all messages sent and allows tests to simulate
/// incoming messages and connection states.
@MainActor
public final class MockWatchConnectivity: WatchConnectivityProtocol {
    // MARK: - Recorded State

    /// All messages that were sent
    private(set) var sentMessages: [[String: Any]] = []

    /// Whether activate() was called
    private(set) var activateCalled = false

    /// Simulated reachability state
    public var isReachable = true

    /// Error to return when sending messages (if any)
    public var sendError: Error?

    /// Reply to return when sending messages
    public var replyMessage: [String: Any] = [:]

    // MARK: - Message Handler

    private var messageHandler: (([String: Any]) -> [String: Any]?)?

    // MARK: - WatchConnectivityProtocol

    public init() {}

    public func activate() {
        activateCalled = true
    }

    public func sendMessage(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)?,
        errorHandler: ((Error) -> Void)?
    ) {
        sentMessages.append(message)

        if let error = sendError {
            errorHandler?(error)
        } else if isReachable {
            replyHandler?(replyMessage)
        } else {
            let error = NSError(
                domain: "MockWatchConnectivity",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Not reachable"]
            )
            errorHandler?(error)
        }
    }

    public func setMessageHandler(_ handler: @escaping ([String: Any]) -> [String: Any]?) {
        self.messageHandler = handler
    }

    // MARK: - Test Helpers

    /// Simulates receiving a message from the counterpart device.
    /// - Parameter message: The message to simulate
    /// - Returns: The reply from the message handler
    public func simulateReceivingMessage(_ message: [String: Any]) -> [String: Any]? {
        return messageHandler?(message)
    }

    /// Returns the last message that was sent, if any.
    public var lastSentMessage: [String: Any]? {
        sentMessages.last
    }

    /// Resets all recorded state.
    public func reset() {
        sentMessages.removeAll()
        activateCalled = false
        isReachable = true
        sendError = nil
        replyMessage = [:]
    }

    /// Extracts the command from a message.
    /// - Parameter message: The message dictionary
    /// - Returns: The command, if present
    public func extractCommand(from message: [String: Any]) -> ConnectivityCommand? {
        guard let commandString = message[ConnectivityMessageKey.command] as? String else {
            return nil
        }
        return ConnectivityCommand(rawValue: commandString)
    }

    /// Extracts the duration from a message.
    /// - Parameter message: The message dictionary
    /// - Returns: The duration in minutes, if present
    public func extractDuration(from message: [String: Any]) -> Int? {
        return message[ConnectivityMessageKey.duration] as? Int
    }
}
