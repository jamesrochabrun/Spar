import Foundation

enum CodingProjectRequirementsParser {
  static func parse(_ markdown: String) -> [CodingProjectRequirementSection] {
    var sections: [CodingProjectRequirementSection] = []
    var currentTitle = "Requirements"
    var currentItems: [String] = []

    func appendCurrentSection() {
      guard !currentItems.isEmpty else { return }
      sections.append(CodingProjectRequirementSection(title: currentTitle, items: currentItems))
      currentItems = []
    }

    for rawLine in markdown.components(separatedBy: .newlines) {
      let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !line.isEmpty, !line.hasPrefix("```") else { continue }

      if let heading = heading(from: line) {
        appendCurrentSection()
        currentTitle = heading
      } else {
        currentItems.append(requirementText(from: line))
      }
    }

    appendCurrentSection()
    return sections
  }

  private static func heading(from line: String) -> String? {
    guard line.hasPrefix("#") else { return nil }
    let title = line.drop(while: { $0 == "#" || $0.isWhitespace })
    return title.isEmpty ? nil : String(title)
  }

  private static func requirementText(from line: String) -> String {
    var text = line
    for prefix in ["- [ ] ", "- [x] ", "- [X] ", "- ", "* ", "+ "]
      where text.hasPrefix(prefix) {
      text.removeFirst(prefix.count)
      return text
    }

    if let separator = text.firstIndex(where: \.isWhitespace) {
      let marker = text[..<separator]
      let digits = marker.dropLast()
      if let last = marker.last,
         (last == "." || last == ")"),
         !digits.isEmpty,
         digits.allSatisfy(\.isNumber) {
        text = String(text[text.index(after: separator)...])
      }
    }
    return text
  }
}
