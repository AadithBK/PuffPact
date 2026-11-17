//
//  SessionClock.swift
//  PuffPact
//

import Foundation

/// Deadline-based timing keeps a session accurate when iOS suspends the app.
/// Pausing preserves the exact remaining duration; no background task is needed.
public struct SessionClock {
    public enum Phase: Equatable {
        case ready, running, paused, complete
    }

    public static let duration: TimeInterval = 180
    public private(set) var phase: Phase = .ready
    public private(set) var remaining: TimeInterval = Self.duration
    private var deadline: Date?

    public var progress: Double { remaining / Self.duration }
    public var elapsed: TimeInterval { Self.duration - remaining }

    public var timeLabel: String {
        let seconds = Int(ceil(max(0, remaining)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    public init() {}

    public mutating func start(at now: Date) {
        remaining = Self.duration
        deadline = now.addingTimeInterval(remaining)
        phase = .running
    }

    public mutating func update(at now: Date) {
        guard phase == .running, let deadline else { return }
        remaining = max(0, min(Self.duration, deadline.timeIntervalSince(now)))
        if remaining == 0 {
            phase = .complete
            self.deadline = nil
        }
    }

    public mutating func pause(at now: Date) {
        guard phase == .running else { return }
        update(at: now)
        guard phase == .running else { return }
        phase = .paused
        deadline = nil
    }

    public mutating func resume(at now: Date) {
        guard phase == .paused else { return }
        deadline = now.addingTimeInterval(remaining)
        phase = .running
    }

    public mutating func reset() {
        self = SessionClock()
    }
}
