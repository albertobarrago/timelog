import SwiftUI

struct TimerRingView: View {
    var progress: Double
    var phase: PomodoroPhase

    private var ringColor: Color {
        switch phase {
        case .work: .accentColor
        case .shortBreak: .green
        case .longBreak: .mint
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: 14)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
        }
    }
}
