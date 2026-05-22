import SwiftUI
import TimelogCore

// MARK: - Enums

enum BubblePeriod: String, CaseIterable, Identifiable {
    case week    = "Week"
    case month   = "Month"
    case allTime = "All Time"
    var id: String { rawValue }

    var localizedLabel: String {
        switch self {
        case .week:    return String(localized: "Week")
        case .month:   return String(localized: "Month")
        case .allTime: return String(localized: "All Time")
        }
    }
}

enum ChartType: String, CaseIterable, Identifiable {
    case bubble = "Bubble"
    case donut  = "Donut"
    var id: String { rawValue }

    var localizedLabel: String {
        switch self {
        case .bubble: return String(localized: "Bubble")
        case .donut:  return String(localized: "Donut")
        }
    }
}

// MARK: - Model

struct ProjectBubble: Identifiable {
    let id: String
    let name: String
    let color: Color
    var minutes: Int
}

// MARK: - Bubble Chart

struct BubbleChartView: View {
    let bubbles: [ProjectBubble]

    private let maxDiameter: CGFloat = 110
    private let minDiameter: CGFloat = 36

    private var maxMinutes: Int { bubbles.map(\.minutes).max() ?? 1 }

    private func diameter(for b: ProjectBubble) -> CGFloat {
        let ratio = sqrt(Double(b.minutes) / Double(maxMinutes))
        return minDiameter + CGFloat(ratio) * (maxDiameter - minDiameter)
    }

    var body: some View {
        if bubbles.isEmpty {
            Text("No entries")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
        } else {
            BubbleFlowLayout(spacing: 12) {
                ForEach(bubbles) { b in
                    BubbleCellView(bubble: b, diameter: diameter(for: b))
                }
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Flow Layout

private struct BubbleFlowLayout: Layout {
    var spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let width = proposal.width ?? 300
        let rows = computeRows(containerWidth: width, subviews: subviews)
        guard !rows.isEmpty else { return .zero }
        let totalHeight = rows.reduce(CGFloat(0)) { h, row in
            h + (row.map { subviews[$0].sizeThatFits(.unspecified).height }.max() ?? 0)
        } + CGFloat(max(0, rows.count - 1)) * spacing
        return CGSize(width: width, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let rows = computeRows(containerWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            let rowHeight = row.map { subviews[$0].sizeThatFits(.unspecified).height }.max() ?? 0
            var rowWidth: CGFloat = 0
            for (offset, i) in row.enumerated() {
                rowWidth += subviews[i].sizeThatFits(.unspecified).width + (offset > 0 ? spacing : 0)
            }
            var x = bounds.midX - rowWidth / 2
            for i in row {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(
                    at: CGPoint(x: x, y: y + (rowHeight - size.height) / 2),
                    proposal: .unspecified
                )
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(containerWidth: CGFloat, subviews: Subviews) -> [[Int]] {
        var rows: [[Int]] = [[]]
        var currentWidth: CGFloat = 0
        for (i, subview) in subviews.enumerated() {
            let w = subview.sizeThatFits(.unspecified).width
            let needed = rows.last!.isEmpty ? w : w + spacing
            if !rows.last!.isEmpty && currentWidth + needed > containerWidth {
                rows.append([i])
                currentWidth = w
            } else {
                rows[rows.count - 1].append(i)
                currentWidth += needed
            }
        }
        return rows.filter { !$0.isEmpty }
    }
}

// MARK: - Bubble Cell

private struct BubbleCellView: View {
    let bubble: ProjectBubble
    let diameter: CGFloat

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(bubble.color.opacity(0.82))
                    .frame(width: diameter, height: diameter)
                    .shadow(color: bubble.color.opacity(0.35), radius: 5, y: 2)
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: diameter)

                if diameter >= 54 {
                    let hours = Double(bubble.minutes) / 60.0
                    Text(hours >= 10 ? String(format: "%.0fh", hours) : String(format: "%.1fh", hours))
                        .font(.system(
                            size: max(10, min(diameter * 0.24, 19)),
                            weight: .bold,
                            design: .rounded
                        ))
                        .foregroundStyle(.white)
                }
            }

            Text(bubble.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: diameter)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(bubble.name), \(bubble.minutes.formattedDuration)")
    }
}
