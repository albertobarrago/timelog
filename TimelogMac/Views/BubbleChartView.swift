import SwiftUI
import TimelogCore

// MARK: - Period

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

// MARK: - Chart

struct BubbleChartView: View {
    let allEntries: [TimeEntry]
    let selectedDate: Date
    let period: BubblePeriod

    private let maxDiameter: CGFloat = 110
    private let minDiameter: CGFloat = 36

    // MARK: Data

    private var periodEntries: [TimeEntry] {
        let cal = Calendar.current
        switch period {
        case .week:
            guard let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)) else { return allEntries }
            let end = cal.date(byAdding: .day, value: 7, to: start) ?? .distantFuture
            return allEntries.filter { $0.date >= start && $0.date < end }
        case .month:
            let comps = cal.dateComponents([.year, .month], from: selectedDate)
            guard let start = cal.date(from: comps),
                  let end = cal.date(byAdding: .month, value: 1, to: start) else { return allEntries }
            return allEntries.filter { $0.date >= start && $0.date < end }
        case .allTime:
            return allEntries
        }
    }

    private var bubbles: [ProjectBubble] {
        var acc: [String: ProjectBubble] = [:]
        for entry in periodEntries {
            let key: String = {
                if let proj = entry.project {
                    return proj.mongoId ?? "local_\(proj.name)"
                }
                return "_none_"
            }()
            if acc[key] == nil {
                acc[key] = ProjectBubble(
                    id: key,
                    name: entry.project?.name ?? String(localized: "No project"),
                    color: entry.client?.color ?? Color.secondary.opacity(0.6),
                    minutes: 0
                )
            }
            if var b = acc[key] {
                b.minutes += entry.durationMinutes
                acc[key] = b
            }
        }
        return acc.values.sorted { $0.minutes > $1.minutes }
    }

    private var maxMinutes: Int { bubbles.map(\.minutes).max() ?? 1 }

    private func diameter(for b: ProjectBubble) -> CGFloat {
        let ratio = sqrt(Double(b.minutes) / Double(maxMinutes))
        return minDiameter + CGFloat(ratio) * (maxDiameter - minDiameter)
    }

    // MARK: Body

    var body: some View {
        if bubbles.isEmpty {
            Text("No entries")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
        } else {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 90, maximum: 140), spacing: 8)],
                spacing: 16
            ) {
                ForEach(bubbles) { b in
                    BubbleCellView(
                        bubble: b,
                        diameter: diameter(for: b),
                        cellSize: maxDiameter
                    )
                }
            }
            .padding(.vertical, 8)
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: period)
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

// MARK: - Cell

private struct BubbleCellView: View {
    let bubble: ProjectBubble
    let diameter: CGFloat
    let cellSize: CGFloat

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
                    let text = hours >= 10
                        ? String(format: "%.0fh", hours)
                        : String(format: "%.1fh", hours)
                    Text(text)
                        .font(.system(
                            size: max(10, min(diameter * 0.24, 19)),
                            weight: .bold,
                            design: .rounded
                        ))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: cellSize, height: cellSize)

            Text(bubble.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: cellSize)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(bubble.name), \(bubble.minutes.formattedDuration)")
    }
}
