import Charts
import SwiftUI
import TimelogCore

// MARK: - Shared types

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

struct ProjectBubble: Identifiable {
    let id: String
    let name: String
    let color: Color
    var minutes: Int
}

// MARK: - Donut Chart

struct DonutChartView: View {
    let bubbles: [ProjectBubble]

    private var totalMinutes: Int { bubbles.reduce(0) { $0 + $1.minutes } }

    var body: some View {
        if bubbles.isEmpty {
            Text("No entries")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
        } else {
            HStack(alignment: .center, spacing: 20) {
                ZStack {
                    Chart(bubbles) { b in
                        SectorMark(
                            angle: .value("Minutes", b.minutes),
                            innerRadius: .ratio(0.56),
                            angularInset: 1.5
                        )
                        .foregroundStyle(b.color)
                        .cornerRadius(3)
                    }
                    .frame(width: 130, height: 130)

                    VStack(spacing: 1) {
                        Text(totalMinutes.formattedDuration)
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .monospacedDigit()
                        Text(String(localized: "total"))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(bubbles) { b in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(b.color)
                                .frame(width: 8, height: 8)
                            Text(b.name)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            let hours = Double(b.minutes) / 60.0
                            Text(hours >= 10
                                 ? String(format: "%.0fh", hours)
                                 : String(format: "%.1fh", hours))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 8)
        }
    }
}
