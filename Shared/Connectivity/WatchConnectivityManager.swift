import Foundation
import WatchConnectivity

/// Concrete implementation of WatchConnectivityProtocol using WatchConnectivity framework.
///
/// This class wraps the WatchConnectivity framework to provide a clean interface
/// for communication between iOS and watchOS apps. It handles session management
/// and message passing.
@MainActor
public final class WatchConnectivityManager: NSObject, WatchConnectivityProtocol {
    private let session: WCSession
    private var messageHandler: (([String: Any]) -> [String: Any]?)?

    /// Creates a new connectivity manager with the specified session.
    /// - Parameter session: The WCSession to use (defaults to .default)
    public init(session: WCSession = .default) {
        self.session = session
        super.init()
    }

    /// Activates the WatchConnectivity session
    public func activate() {
        guard WCSession.isSupported() else { return }

        session.delegate = self
        session.activate()
    }

    /// Sends a message to the counterpart device.
    /// - Parameters:
    ///   - message: Dictionary containing message data
    ///   - replyHandler: Optional handler for reply messages
    ///   - errorHandler: Optional handler for errors
    public func sendMessage(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)? = nil,
        errorHandler: ((Error) -> Void)? = nil
    ) {
        guard session.isReachable else {
            let error = NSError(
                domain: "WatchConnectivity",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Counterpart not reachable"]
            )
            errorHandler?(error)
            return
        }

        session.sendMessage(message, replyHandler: replyHandler, errorHandler: errorHandler)
    }

    /// Sets the handler for incoming messages.
    /// - Parameter handler: Closure called when messages are received
    public func setMessageHandler(_ handler: @escaping ([String: Any]) -> [String: Any]?) {
        self.messageHandler = handler
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // Required delegate method - activation state handled implicitly
    }

    public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        let reply = messageHandler?(message) ?? [:]
        replyHandler(reply)
    }

#if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {
        // Required delegate method for iOS
    }

    public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
#endif
}
