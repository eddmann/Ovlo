import Foundation

/// Protocol defining the interface for watch connectivity communication.
///
/// This protocol abstracts WatchConnectivity to enable dependency injection
/// and testability. It provides methods for sending messages between iOS and watchOS.
public protocol WatchConnectivityProtocol: Sendable {
    /// Activates the connectivity session
    func activate()

    /// Sends a message to the counterpart device
    /// - Parameters:
    ///   - message: Dictionary containing the message data
    ///   - replyHandler: Optional handler called when a reply is received
    ///   - errorHandler: Optional handler called if an error occurs
    func sendMessage(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)?,
        errorHandler: ((Error) -> Void)?
    )

    /// Sets the handler for receiving messages
    /// - Parameter handler: Closure called when a message is received
    func setMessageHandler(_ handler: @escaping ([String: Any]) -> [String: Any]?)
}

/// Message keys used for watch connectivity communication
public enum ConnectivityMessageKey {
    public static let command = "command"
    public static let duration = "duration"
    public static let inhale = "inhale"
    public static let exhale = "exhale"
}

/// Commands that can be sent between devices
public enum ConnectivityCommand: String, Sendable {
    case start
    case stop
}
