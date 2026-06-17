import SwiftUI

/// A simple wrapping layout (left-to-right, top-to-bottom) for chips and tags.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [CGFloat] = [0]      // width used per row
        var rowHeights: [CGFloat] = [0]
        var x: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                rows.append(0); rowHeights.append(0); x = 0
            }
            x += size.width + spacing
            rows[rows.count - 1] = x
            rowHeights[rowHeights.count - 1] = max(rowHeights[rowHeights.count - 1], size.height)
        }

        let totalHeight = rowHeights.reduce(0, +) + spacing * CGFloat(max(rowHeights.count - 1, 0))
        let width = proposal.width ?? rows.max() ?? 0
        return CGSize(width: width, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), anchor: .topLeading,
                       proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
