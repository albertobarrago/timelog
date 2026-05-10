import SwiftUI
import TimelogCore

struct TimerMacView: View {
    @Environment(TimerViewModel.self) private var vm
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var vm = vm
        VStack(spacing: 0) {
            Spacer()

            // Phase + dots
            if vm.pomodoroEnabled {
                VStack(spacing: 6) {
                    Text(vm.phase.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        ForEach(0..<vm.pomodorosBeforeLong, id: \.self) { i in
                            Circle()
                                .fill(i < vm.completedPomodoros % vm.pomodorosBeforeLong
                                      ? Color.accentColor : Color.secondary.opacity(0.3))
                                .frame(width: 7, height: 7)
                        }
                    }
                }
                .padding(.bottom, 20)
            }

            // Ring + time
            ZStack {
                if vm.pomodoroEnabled {
                    Circle()
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: vm.progress)
                        .stroke(ringColor(for: vm.phase),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: vm.progress)
                }
                Text(vm.displayTime)
                    .font(.system(size: 52, weight: .thin, design: .monospaced))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .frame(width: 180, height: 180)

            Spacer().frame(height: 32)

            // Controls — single row, visually balanced
            HStack(spacing: 0) {
                Spacer()

                // Reset
                Button { vm.reset() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .disabled(!vm.isRunning && vm.elapsed == 0)

                Spacer().frame(width: 28)

                // Play / Pause
                Button { vm.toggle() } label: {
                    Image(systemName: vm.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 20, weight: .medium))
                        .frame(width: 52, height: 52)
                        .background(Color.accentColor, in: Circle())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.space, modifiers: [])

                Spacer().frame(width: 28)

                // Pomodoro toggle
                Toggle(isOn: $vm.pomodoroEnabled) {
                    Image(systemName: "timer")
                        .font(.system(size: 16, weight: .regular))
                        .frame(width: 36, height: 36)
                }
                .toggleStyle(.button)
                .buttonStyle(.plain)
                .onChange(of: vm.pomodoroEnabled) { vm.reset() }

                Spacer()
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Timer")
        .onAppear { vm.applySettings(settings) }
    }

    private func ringColor(for phase: PomodoroPhase) -> Color {
        switch phase {
        case .work:       .accentColor
        case .shortBreak: .green
        case .longBreak:  .mint
        }
    }
}
