import Foundation

struct CodingProjectRequirementSection: Equatable, Identifiable {
  let title: String
  let items: [String]

  var id: String { title }
}
