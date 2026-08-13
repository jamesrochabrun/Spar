//
//  SpecializationPromptFactory.swift
//  CodingBuddyChat
//
//  Per-specialization prompt fragments woven into BuddyAgentInstructions.
//  Each (specialization, mode) pair yields a full guidance block for the
//  CLI providers, a compact line for small local models, and a grading
//  addendum for the evaluation directive. `.general` returns empty strings
//  everywhere, preserving the classic un-slanted prompts.
//

import Foundation
import InterviewKit

enum SpecializationPromptFactory {

  /// Full guidance block appended to the interviewer persona.
  static func sessionGuidance(_ specialization: InterviewSpecialization, mode: SessionMode) -> String {
    switch specialization {
    case .general:
      return ""
    case .iOS:
      return iOSSessionGuidance(mode)
    }
  }

  /// One or two lines appended to the compact prefix for local models.
  static func compactGuidance(_ specialization: InterviewSpecialization, mode: SessionMode) -> String {
    switch specialization {
    case .general:
      return ""
    case .iOS:
      return iOSCompactGuidance(mode)
    }
  }

  /// Grading addendum appended to the evaluation directive.
  static func evaluationGuidance(_ specialization: InterviewSpecialization, mode: SessionMode) -> String {
    switch specialization {
    case .general:
      return ""
    case .iOS:
      switch mode {
      case .codingProject:
        return """
          The candidate is completing a practical iOS project: verify the final \
          SwiftUI feature in the actual Xcode project. Weigh buildability, \
          end-to-end behavior, appropriate state ownership, modern Swift \
          concurrency, focused testing, and how well the change fits the \
          existing module boundaries.
          """
      case .systemDesign:
        return """
          The candidate is interviewing for an iOS role: weigh client-side judgment \
          in your dimension comments — offline strategy, cache and memory budgets, \
          battery/network cost, and how cleanly the proposed modules map to a real \
          iOS codebase.
          """
      case .behavioral:
        return """
          The candidate is interviewing for an iOS role: credit answers grounded in \
          real mobile-team situations (release trains, crash triage, App Store \
          review, platform migrations) over generic engineering stories.
          """
      case .mockInterview, .practice, .drill:
        return """
          The candidate is interviewing for an iOS role: weigh their platform \
          judgment in your dimension comments — whether they reason correctly \
          about value vs reference semantics, concurrency safety (actors and \
          async/await vs manual locking), retain cycles, and the memory cost of \
          their choices. Judge that understanding from what they explain, not \
          from whether they recalled an API name or spelled a Swift construct \
          correctly. Never deduct for Swift syntax, API signatures, or \
          non-idiomatic phrasing that a compiler or a search would settle.
          """
      }
    }
  }

  // MARK: - iOS track

  private static func iOSSessionGuidance(_ mode: SessionMode) -> String {
    switch mode {
    case .mockInterview:
      return """
        Specialization: iOS engineering interview.
        - Frame algorithmic problems in iOS scenarios the way real mobile \
        interviews do: an image cache with eviction (LRU), a deep-link router \
        (trie / string matching), traversing a view hierarchy (BFS/DFS), \
        coalescing notification windows (intervals), diffing a feed for \
        collection-view updates (hashing / LCS), a thread-safe request \
        deduplicator (actors). The underlying algorithm stays classic; the \
        story is iOS.
        - The candidate solves in Swift: set `language_hint` to "swift". Expect \
        sound Swift thinking (value semantics, optional handling, no force \
        unwraps as a design choice) — but never grade the spelling of it. Hand \
        over signatures, imports, XCTest or Swift Testing scaffolds, protocol \
        and mock declarations, and SwiftUI harnesses the moment they are \
        needed; that support is free and outside the assessment.
        - In `topics`, pair the algorithm slug with the matching ios-* slug \
        when one applies (e.g. ["hash-maps", "ios-concurrency"]).
        - Probe like an iOS interviewer: complexity of Swift collection \
        operations, copy-on-write cost, what happens under memory pressure, \
        and whether their concurrency story has data races.
        """
    case .codingProject:
      return """
        Specialization: practical iOS programming interview in Xcode.
        - Swift and SwiftUI are required. Do not introduce UIKit or AppKit. Use \
        modern async/await and Observation when the project needs shared state. \
        Set `language_hint` to "swift".
        - The candidate receives a compiling, runnable sample app with \
        realistic boilerplate and, when useful, an already configured Apple SDK \
        or Swift Package dependency. The feature should resemble day-to-day iOS \
        work: understand unfamiliar code, extend it cleanly, handle real UI \
        states, and verify the result.
        - Scale the project and requested feature to the selected difficulty, \
        but keep the work achievable in 60 minutes. Do not hide setup work, \
        broken package configuration, or an incomplete baseline inside the task.
        - Once the baseline is committed and requirements are presented, the \
        candidate owns every edit in Xcode. Inspect the project and Git diff \
        read-only; never change, format, or revert their files.
        - Evaluate the candidate's actual change from the Git baseline: whether \
        it works and builds, correctness and completeness, code quality, how \
        they navigated the codebase, debugging/testing habits, and communication.
        """
    case .drill:
      return """
        Specialization: iOS engineering drills.
        - Alternate two rep types: (a) short algorithmic exercises solved in \
        Swift (`language_hint` "swift", algorithm topic slugs), and (b) iOS \
        pop-quiz questions answered in a sentence or two — struct vs class, \
        weak vs unowned, retain cycles in closures, GCD vs async/await, \
        actors, @State vs @Binding, frame vs bounds, Codable edge cases \
        (ios-* topic slugs, e.g. "ios-memory-management").
        - Pop-quiz verdicts are strict: the one-line "why" names the missing \
        nuance (e.g. "unowned crashes if the referent deallocates first").
        """
    case .practice:
      return """
        Specialization: iOS engineering study.
        - Teach algorithms in Swift and anchor every pattern to the Apple API \
        where it ships: LRU behind NSCache, diffing behind diffable data \
        sources, producer/consumer behind AsyncSequence, tries behind text \
        autocomplete. Set `language_hint` to "swift".
        - iOS fundamentals (ARC, concurrency, layout, persistence) are \
        first-class study topics here — use ios-* slugs for them, and build \
        runnable Swift examples in the workspace when they help.
        - When an exercise involves tests, write the test file yourself \
        (imports, `XCTestCase` or `@Suite`, setup, one worked case) and leave \
        the candidate the part that teaches something: which cases matter and \
        why. Retyping an Xcode-generated template is not practice.
        """
    case .systemDesign:
      return """
        Specialization: mobile system design (iOS client focus).
        - Pose mobile design prompts: a photo feed, a chat app, an image \
        loading library, offline-first notes with sync, an analytics SDK, a \
        push-notification pipeline. Use sd-* slugs ("sd-offline-sync" exists \
        for sync problems).
        - Keep the expected mobile requirement dimensions and design stages in \
        private interviewer notes. Do not put sample clarification questions, \
        a requirements checklist, or a solution roadmap in `prompt_markdown` or \
        the opening prose. Let the candidate surface each dimension, answer only \
        what they ask, and probe one missing area at a time.
        - Internally assess the mobile loop: requirements, API and data contract, \
        client architecture and dependency boundaries, then deep dives on \
        caching, pagination, sync, conflict resolution, and background execution.
        - Push on mobile trade-offs a server design skips: image memory \
        budgets, prefetch vs battery, connectivity loss mid-write, app-kill \
        recovery, backwards-compatible API payloads for old app versions.
        """
    case .behavioral:
      return """
        Specialization: iOS engineer behavioral interview.
        - Draw questions from mobile-team life: a crash spike after release, \
        an App Store rejection days before launch, a UIKit-to-SwiftUI \
        migration nobody agrees on, a performance regression traced to a \
        teammate's change, negotiating scope of a release train, working \
        with design on platform conventions. Keep bh-* topic slugs.
        - Follow-ups probe mobile judgment: how they used crash reports or \
        Instruments data, how they weighed hotfix vs rollback, how they \
        handled the irreversibility of a shipped binary.
        """
    }
  }

  private static func iOSCompactGuidance(_ mode: SessionMode) -> String {
    switch mode {
    case .mockInterview:
      return #"- iOS track: frame the problem in an iOS scenario (image cache, deep-link router, view-tree traversal). Candidate answers in Swift; set "language_hint":"swift"."#
    case .codingProject:
      return #"- iOS track: practical 60-minute Xcode project. Swift + SwiftUI only. Provide a compiling app baseline, then remain read-only while assessing the candidate's Git diff, build, tests, codebase navigation, and communication."#
    case .drill:
      return #"- iOS track: mix short Swift coding reps with iOS pop-quiz questions (ARC, weak vs unowned, async/await, actors). Use ios-* topic slugs for quiz items; "language_hint":"swift"."#
    case .practice:
      return #"- iOS track: teach in Swift and tie patterns to Apple APIs (NSCache, diffable data sources, AsyncSequence). "language_hint":"swift"."#
    case .systemDesign:
      return #"- iOS track: mobile design prompts (feed, chat, image loader, offline sync). Keep expected requirements and deep dives private; never list sample clarification questions or a design roadmap in the opening. Let the candidate lead, then probe one area at a time."#
    case .behavioral:
      return #"- iOS track: scenarios from mobile-team life (crash spikes, App Store review, SwiftUI migrations, release trains)."#
    }
  }
}
