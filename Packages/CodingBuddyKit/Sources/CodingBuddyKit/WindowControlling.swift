//
//  WindowControlling.swift
//  CodingBuddyKit
//

@MainActor
public protocol WindowControlling: AnyObject {
  func showCapsule()
  func hideCapsule()
  func showCanvas()
  func animateToCanvas()
  func animateToCapsule()
}
