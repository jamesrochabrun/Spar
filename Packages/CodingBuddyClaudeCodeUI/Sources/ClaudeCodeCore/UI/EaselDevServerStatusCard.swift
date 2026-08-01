import SwiftUI

struct EaselDevServerStatusCard: View {
  let url: URL

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 8) {
        Circle()
          .fill(CodingBuddyChatRuntimeStyle.completedForeground(for: colorScheme))
          .frame(width: 6, height: 6)

        Text("Dev server running")
          .font(.callout.bold())
          .foregroundStyle(CodingBuddyChatRuntimeStyle.successForeground(for: colorScheme))
      }

      Text(url.absoluteString.replacingOccurrences(of: "http://", with: ""))
        .font(.callout)
        .foregroundStyle(CodingBuddyChatRuntimeStyle.successForeground(for: colorScheme).opacity(0.82))
        .lineLimit(1)
        .truncationMode(.middle)
        .textSelection(.enabled)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 11)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(CodingBuddyChatRuntimeStyle.successBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: CodingBuddyChatRuntimeStyle.cardRadius))
  }
}
