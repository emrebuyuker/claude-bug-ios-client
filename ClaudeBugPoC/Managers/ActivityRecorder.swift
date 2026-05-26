//
//  ActivityRecorder.swift
//  ClaudeBugPoC
//

import Foundation

/// In-memory ring buffer of recent user/network activity. The buffer is dumped
/// into the bug report payload so the backend Claude agent can see what the
/// user was doing before tapping "Gönder".
///
/// Buffer policy:
/// - Hard cap: 50 events
/// - Time cap: 60 seconds (older entries pruned on read)
/// - Format: compact single-line "[T-Xs] TYPE target | k=v" timeline
/// - PII redaction: Authorization headers / token / password fields stripped
final class ActivityRecorder {

    static let shared = ActivityRecorder()

    // MARK: - Config
    private let maxEvents = 50
    private let maxAgeSeconds: TimeInterval = 60
    private let maxPayloadChars = 120

    // MARK: - Storage
    private struct Event {
        let timestamp: Date
        let type: String      // NET / SCREEN / NAV / TAP / ALERT
        let target: String
        let extras: [String: String]
    }

    private var events: [Event] = []
    private let queue = DispatchQueue(label: "com.claudebug.activity", attributes: .concurrent)

    private init() {}

    // MARK: - Public API
    func recordNetwork(method: String, path: String, status: Int?, durationMs: Int, error: String? = nil) {
        var extras: [String: String] = [
            "method": method,
            "ms": "\(durationMs)",
        ]
        if let status { extras["status"] = "\(status)" }
        if let error, !error.isEmpty {
            extras["err"] = ActivityRecorder.truncate(error, max: 80)
        }
        append(type: "NET", target: path, extras: extras)
    }

    func recordScreen(_ name: String) {
        append(type: "SCREEN", target: name, extras: [:])
    }

    func recordNavigation(from: String, to: String) {
        append(type: "NAV", target: "\(from) → \(to)", extras: [:])
    }

    func recordTap(_ identifier: String, context: String? = nil) {
        var extras: [String: String] = [:]
        if let context { extras["ctx"] = ActivityRecorder.truncate(context, max: 40) }
        append(type: "TAP", target: identifier, extras: extras)
    }

    func recordAlert(title: String, message: String? = nil) {
        var extras: [String: String] = [:]
        if let message { extras["msg"] = ActivityRecorder.truncate(message, max: 80) }
        append(type: "ALERT", target: ActivityRecorder.truncate(title, max: 40), extras: extras)
    }

    /// Build the compact timeline string for sending to the backend. Returns nil
    /// if there's nothing to report (so callers can skip the payload field).
    func exportTimeline(now: Date = Date()) -> String? {
        let snapshot = queue.sync { events }
        let recent = snapshot.filter { now.timeIntervalSince($0.timestamp) <= maxAgeSeconds }
        guard !recent.isEmpty else { return nil }

        let lines = recent.map { event -> String in
            let delta = now.timeIntervalSince(event.timestamp)
            let header = "[T-\(String(format: "%.1f", delta))s]"
            let extras = event.extras
                .sorted(by: { $0.key < $1.key })
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: " ")
            return extras.isEmpty
                ? "\(header) \(event.type) \(event.target)"
                : "\(header) \(event.type) \(event.target) | \(extras)"
        }
        return lines.joined(separator: "\n")
    }

    func clear() {
        queue.async(flags: .barrier) { self.events.removeAll() }
    }

    // MARK: - Private
    private func append(type: String, target: String, extras: [String: String]) {
        let event = Event(
            timestamp: Date(),
            type: type,
            target: ActivityRecorder.truncate(target, max: maxPayloadChars),
            extras: redact(extras)
        )
        queue.async(flags: .barrier) {
            // Skip identical back-to-back entries (collapse duplicates).
            if let last = self.events.last,
               last.type == event.type,
               last.target == event.target,
               last.extras == event.extras,
               event.timestamp.timeIntervalSince(last.timestamp) < 1.0 {
                return
            }
            self.events.append(event)
            if self.events.count > self.maxEvents {
                self.events.removeFirst(self.events.count - self.maxEvents)
            }
        }
    }

    private func redact(_ extras: [String: String]) -> [String: String] {
        let sensitiveKeys: Set<String> = [
            "authorization", "token", "access_token", "refresh_token",
            "password", "email", "phone", "ssn",
        ]
        var redacted: [String: String] = [:]
        for (key, value) in extras {
            if sensitiveKeys.contains(key.lowercased()) {
                redacted[key] = "[REDACTED]"
            } else {
                redacted[key] = value
            }
        }
        return redacted
    }

    private static func truncate(_ value: String, max: Int) -> String {
        if value.count <= max { return value }
        return String(value.prefix(max)) + "…"
    }
}
