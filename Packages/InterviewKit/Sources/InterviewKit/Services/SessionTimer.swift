//
//  SessionTimer.swift
//  InterviewKit
//

import Foundation
import Observation

/// Drift-free countdown timer: `remaining` is always computed from a fixed
/// deadline, the 1s tick loop only triggers observation updates. Restoring a
/// mid-attempt timer after relaunch is just `start(deadline:)` with the
/// persisted `started_at + planned_duration_seconds`.
@Observable @MainActor
public final class SessionTimer {

  public private(set) var deadline: Date?
  public private(set) var isPaused = false
  /// Bumped every tick so SwiftUI re-reads `remaining`.
  private var tick = 0
  private var tickTask: Task<Void, Never>?
  private var pausedRemaining: TimeInterval?

  public var onExpiry: (() -> Void)?

  public init() {}

  public var isRunning: Bool { deadline != nil && !isPaused }

  public var remaining: TimeInterval? {
    _ = tick
    if let pausedRemaining { return pausedRemaining }
    guard let deadline else { return nil }
    return max(0, deadline.timeIntervalSinceNow)
  }

  public var totalDuration: TimeInterval? {
    didSet { tick += 1 }
  }

  /// Fraction of time remaining in 0...1, or nil when untimed.
  public var fractionRemaining: Double? {
    guard let remaining, let totalDuration, totalDuration > 0 else { return nil }
    return min(1, max(0, remaining / totalDuration))
  }

  public func start(duration: TimeInterval) {
    start(deadline: Date().addingTimeInterval(duration), totalDuration: duration)
  }

  public func start(deadline: Date, totalDuration: TimeInterval? = nil) {
    stop()
    self.deadline = deadline
    self.totalDuration = totalDuration
    isPaused = false
    pausedRemaining = nil

    if deadline.timeIntervalSinceNow <= 0 {
      expire()
      return
    }

    tickTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1))
        guard let self, !Task.isCancelled else { return }
        self.tick += 1
        if let deadline = self.deadline, deadline.timeIntervalSinceNow <= 0 {
          self.expire()
          return
        }
      }
    }
  }

  public func pause() {
    guard let deadline, !isPaused else { return }
    pausedRemaining = max(0, deadline.timeIntervalSinceNow)
    isPaused = true
    tickTask?.cancel()
    tickTask = nil
  }

  public func resume() {
    guard isPaused, let pausedRemaining else { return }
    isPaused = false
    self.pausedRemaining = nil
    start(deadline: Date().addingTimeInterval(pausedRemaining), totalDuration: totalDuration)
  }

  public func stop() {
    tickTask?.cancel()
    tickTask = nil
    deadline = nil
    totalDuration = nil
    isPaused = false
    pausedRemaining = nil
  }

  private func expire() {
    tickTask?.cancel()
    tickTask = nil
    deadline = nil
    tick += 1
    onExpiry?()
  }

  /// "21:34" or "1:02:09" style formatting for the timer pill.
  nonisolated public static func formatted(_ interval: TimeInterval) -> String {
    let total = Int(interval.rounded())
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let seconds = total % 60
    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
    return String(format: "%d:%02d", minutes, seconds)
  }
}
