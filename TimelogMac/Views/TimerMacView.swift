import SwiftUI
import TimelogCore

struct TimerMacView: View {
    @Environment(TimerViewModel.self) private var vm
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var vm = vm
        VStack(spacing: 40) {
            Spacer()

            if vm.pomodoroEnabled {
                VStack(spacing: 8) {
                    Text(vm.phase.label)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        ForEach(0..<vm.pomodorosBeforeLong, id: \.self) { i in
                            Circle()
                                .fill(i < vm.completedPomodoros % vm.pomodorosBeforeLong
                                      ? Color.accentColor : Color.secondary.opacity(0.25))
                                .frame(width: 10, height: 10)
                        }
                    }
                }
            }

            ZStack {
                if vm.pomodoroEnabled {
                    TimerRingMacView(progress: vm.progress, phase: vm.phase)
                        .frame(width: 240, height: 240)
                }
                Text(vm.displayTime)
                    .font(.system(size: 72, weight: .thin, design: .monospaced))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            HStack(spacing: 48) {
                Button { vm.reset() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button { vm.toggle() } label: {
                    Image(systemName: vm.isRunning ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 72))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.space, modifiers: [])

                Toggle(isOn: $vm.pomodoroEnabled) {
                    Image(systemName: "timer").font(.title)
                }
                .toggleStyle(.button)
                .onChange(of: vm.pomodoroEnabled) { vm.reset() }
            }

            Spacer()
        }
        .frame(maxWidth: 480)
        .onAppear { vm.applySettings(settings) }
    }
}

private struct TimerRingMacView: View {
    let progress: Double
    let phase: PomodoroPhase

    private var ringColor: Color {
        switch phase {
        case .work: .accentColor
        case .shortBreak: .green
        case .longBreak: .mint
        }
    }

    var body: some View {
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 14)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
        }
    }
}
