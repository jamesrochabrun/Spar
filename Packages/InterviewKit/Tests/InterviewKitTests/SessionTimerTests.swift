//
//  SessionTimerTests.swift
//  InterviewKitTests
//

import Foundation
import Testing
@testable import InterviewKit

@MainActor
struct SessionTimerTests {

  @Test
  func remainingComputedFromDeadline() {
    let timer = SessionTimer()
    timer.start(duration: 120)
    let remaining = try? #require(timer.remaining)
    #expect(remaining! > 118 && remaining! <= 120)
    #expect(timer.isRunning)
    timer.stop()
    #expect(timer.remaining == nil)
  }

  @Test
  func expiredDeadlineFiresImmediately() {
    let timer = SessionTimer()
    var expired = false
    timer.onExpiry = { expired = true }
    timer.start(deadline: Date().addingTimeInterval(-5))
    #expect(expired)
    #expect(timer.remaining == nil)
  }

  @Test
  func expiryFiresAfterCountdown() async {
    let timer = SessionTimer()
    await confirmation("timer expires") { expiry in
      timer.onExpiry = { expiry() }
      timer.start(duration: 1.1)
      try? await Task.sleep(for: .seconds(2.5))
    }
  }

  @Test
  func pauseFreezesRemaining() async {
    let timer = SessionTimer()
    timer.start(duration: 60)
    timer.pause()
    let frozen = timer.remaining
    try? await Task.sleep(for: .milliseconds(1200))
    #expect(timer.remaining == frozen)
    #expect(timer.isPaused)

    timer.resume()
    #expect(!timer.isPaused)
    #expect(timer.isRunning)
    timer.stop()
  }

  @Test
  func formatting() {
    #expect(SessionTimer.formatted(1294) == "21:34")
    #expect(SessionTimer.formatted(3729) == "1:02:09")
    #expect(SessionTimer.formatted(59) == "0:59")
    #expect(SessionTimer.formatted(0) == "0:00")
  }

  @Test
  func fractionRemaining() {
    let timer = SessionTimer()
    timer.start(duration: 100)
    let fraction = timer.fractionRemaining
    #expect(fraction != nil && fraction! > 0.97 && fraction! <= 1.0)
    timer.stop()
    #expect(timer.fractionRemaining == nil)
  }
}
