import Foundation
import Observation

enum PomodoroPhase {
    case work, shortBreak, longBreak

    var label: String {
        switch self {
        case .work: "Focus"
        case .shortBreak: "Short Break"
        case .longBreak: "Long Break"
        }
    }
}

@Observable
final class TimerViewModel {
    var isRunning = false
    var elapsed: TimeInterval = 0
    var pomodoroEnabled = false
    var phase: PomodoroPhase = .work
    var completedPomodoros = 0
    var workMinutes = 25
    var shortBreakMinutes = 5
    var longBreakMinutes = 15
    var pomodorosBeforeLong = 4

    private var timer: Timer?

    var phaseTotal: TimeInterval {
        switch phase {
        case .work: TimeInterval(workMinutes * 60)
        case .shortBreak: TimeInterval(shortBreakMinutes * 60)
        case .longBreak: TimeInterval(longBreakMinutes * 60)
        }
    }

    var progress: Double {
        guard pomodoroEnabled, phaseTotal > 0 else { return 0 }
        return min(elapsed / phaseTotal, 1.0)
    }

    var displayTime: String {
        if pomodoroEnabled {
            let remaining = max(phaseTotal - elapsed, 0)
            let m = Int(remaining) / 60
            let s = Int(remaining) % 60
            return String(format: "%02d:%02d", m, s)
        } else {
            let h = Int(elapsed) / 3600
            let m = (Int(elapsed) % 3600) / 60
            let s = Int(elapsed) % 60
            return h > 0
                ? String(format: "%d:%02d:%02d", h, m, s)
                : String(format: "%02d:%02d", m, s)
        }
    }

    func toggle() { isRunning ? pause() : start() }

    func start() {
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        pause()
        elapsed = 0
        phase = .work
        completedPomodoros = 0
    }

    private func tick() {
        elapsed += 1
        if pomodoroEnabled, elapsed >= phaseTotal {
            phaseComplete()
        }
    }

    private func phaseComplete() {
        pause()
        elapsed = 0
        if phase == .work {
            completedPomodoros += 1
            phase = completedPomodoros % pomodorosBeforeLong == 0 ? .longBreak : .shortBreak
        } else {
            phase = .work
        }
    }

    deinit { timer?.invalidate() }
}
