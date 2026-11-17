//
//  TimerSync.swift
//  OneMinute
//

import Foundation
import WatchConnectivity

/// Keeps the timer on iPhone and Apple Watch in step: starting or stopping it on one starts or
/// stops it on the other, counting from the same moment. Shared by both apps.
@Observable
final class TimerSync: NSObject {
    static let shared = TimerSync()

    /// The timer starting or stopping on one of the devices.
    nonisolated struct Event: Equatable {
        enum Kind: String { case start, stop }

        var kind: Kind
        /// When the timer started or stopped.
        var date: Date

        init(kind: Kind, date: Date) {
            self.kind = kind
            self.date = date
        }

        init?(message: [String: Any]) {
            guard let kind = (message["kind"] as? String).flatMap(Kind.init),
                  let date = message["date"] as? Double else { return nil }
            self.init(kind: kind, date: Date(timeIntervalSince1970: date))
        }

        var message: [String: Any] {
            ["kind": kind.rawValue, "date": date.timeIntervalSince1970]
        }
    }

    /// The latest start or stop from the other device, for the timer to follow.
    private(set) var received: Event?

    private var session: WCSession? { WCSession.isSupported() ? .default : nil }

    /// Connects to the other device. Called at launch, so messages that launch the app arrive.
    func activate() {
        guard let session, session.delegate == nil else { return }
        session.delegate = self
        session.activate()
    }

    /// Tells the other device the timer started or stopped.
    func send(_ event: Event) {
        guard let session, session.activationState == .activated else { return }
        // Straight away if the other app is running; and kept for when it next opens, in case
        // it isn't. The receiver ignores the copy it already followed.
        if session.isReachable {
            session.sendMessage(event.message, replyHandler: nil)
        }
        try? session.updateApplicationContext(event.message)
    }

    private func receive(_ event: Event?) {
        guard let event else { return }
        received = event
    }
}

extension TimerSync: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // Catch up on what the other device sent while this app wasn't running.
        let event = Event(message: session.receivedApplicationContext)
        Task { @MainActor in receive(event) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let event = Event(message: message)
        Task { @MainActor in receive(event) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let event = Event(message: applicationContext)
        Task { @MainActor in receive(event) }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Reconnects after switching to another Apple Watch.
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
