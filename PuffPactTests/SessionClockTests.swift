//
//  SessionClockTests.swift
//  PuffPactTests
//

import XCTest
@testable import PuffPact

final class SessionClockTests: XCTestCase {
    private let origin = Date(timeIntervalSince1970: 1_000)

    func testStartsAtThreeMinutes() {
        var clock = SessionClock()
        clock.start(at: origin)
        XCTAssertEqual(clock.phase, .running)
        XCTAssertEqual(clock.remaining, 180)
        XCTAssertEqual(clock.timeLabel, "03:00")
    }

    func testElapsedTimeRatherThanTickCount() {
        var clock = SessionClock()
        clock.start(at: origin)
        clock.update(at: origin.addingTimeInterval(63))
        XCTAssertEqual(clock.remaining, 117)
        XCTAssertEqual(clock.timeLabel, "01:57")
        clock.update(at: origin.addingTimeInterval(900))
        XCTAssertEqual(clock.remaining, 0)
        XCTAssertEqual(clock.phase, .complete)
        XCTAssertEqual(clock.timeLabel, "00:00")
    }

    func testPauseAndResumePreserveTime() {
        var clock = SessionClock()
        clock.start(at: origin)
        clock.pause(at: origin.addingTimeInterval(60))
        XCTAssertEqual(clock.phase, .paused)
        clock.update(at: origin.addingTimeInterval(600))
        XCTAssertEqual(clock.remaining, 120)
        clock.resume(at: origin.addingTimeInterval(600))
        clock.update(at: origin.addingTimeInterval(610))
        XCTAssertEqual(clock.remaining, 110)
    }

    func testPauseAtExpiredDeadlineCompletes() {
        var clock = SessionClock()
        clock.start(at: origin)
        clock.pause(at: origin.addingTimeInterval(180))
        XCTAssertEqual(clock.phase, .complete)
        clock.resume(at: origin.addingTimeInterval(190))
        XCTAssertEqual(clock.phase, .complete)
    }

    func testResetAndRestart() {
        var clock = SessionClock()
        clock.start(at: origin)
        clock.update(at: origin.addingTimeInterval(90))
        clock.reset()
        XCTAssertEqual(clock.phase, .ready)
        XCTAssertEqual(clock.remaining, 180)
        clock.start(at: origin.addingTimeInterval(100))
        clock.update(at: origin.addingTimeInterval(101))
        XCTAssertEqual(clock.remaining, 179)
    }

    func testTimeLabelRoundsUp() {
        var clock = SessionClock()
        clock.start(at: origin)
        clock.update(at: origin.addingTimeInterval(179.9))
        XCTAssertEqual(clock.timeLabel, "00:01")
        XCTAssertGreaterThan(clock.progress, 0)
        clock.update(at: origin.addingTimeInterval(180))
        XCTAssertEqual(clock.timeLabel, "00:00")
    }
}
