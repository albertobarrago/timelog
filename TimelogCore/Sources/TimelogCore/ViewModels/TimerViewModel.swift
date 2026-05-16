import Foundation
import Observation
#if os(iOS)
import UIKit
#endif
#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit
#endif

public enum PomodoroPhase {
    case work, shortBreak, longBreak

    public var label: String {
        switch self {
        case .work: "Focus"
        case .shortBreak: "Short Break"
        case .longBreak: "Long Break"
        }
    }
}

@Observable
@MainActor
public final class TimerViewModel {
    public var isRunning = false
    public var elapsed: TimeInterval = 0
    public var pomodoroEnabled = false
    public var phase: PomodoroPhase = .work
    public var completedPomodoros = 0
    public var workMinutes = 25
    public var shortBreakMinutes = 5
    public var longBreakMinutes = 15
    public var pomodorosBeforeLong = 4

    public init() {}

    public func applySettings(_ store: SettingsStore) {
        workMinutes = store.pomodoroWork
        shortBreakMinutes = store.pomodoroShortBreak
        longBreakMinutes = store.pomodoroLongBreak
    }

    nonisolated(unsafe) private var timer: Timer?

    public var phaseTotal: TimeInterval {
        switch phase {
        case .work: TimeInterval(workMinutes * 60)
        case .shortBreak: TimeInterval(shortBreakMinutes * 60)
        case .longBreak: TimeInterval(longBreakMinutes * 60)
        }
    }

    public var progress: Double {
        guard pomodoroEnabled, phaseTotal > 0 else { return 0 }
        return min(elapsed / phaseTotal, 1.0)
    }

    public var displayTime: String {
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

    public func toggle() { isRunning ? pause() : start() }

    public func start() {
        isRunning = true
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        if pomodoroEnabled {
            NotificationManager.shared.schedulePomodoroEnd(phase: phase.label, in: phaseTotal - elapsed)
        }
        #if os(iOS) && !targetEnvironment(macCatalyst)
        startLiveActivity()
        #endif
        #if os(iOS)
        haptic(.medium)
        #endif
    }

    public func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        NotificationManager.shared.cancelPomodoroNotification()
        #if os(iOS) && !targetEnvironment(macCatalyst)
        updateLiveActivity()
        #endif
        #if os(iOS)
        haptic(.light)
        #endif
    }

    public func reset() {
        pause()
        elapsed = 0
        phase = .work
        completedPomodoros = 0
        #if os(iOS) && !targetEnvironment(macCatalyst)
        endLiveActivity()
        #endif
        #if os(iOS)
        haptic(.rigid)
        #endif
    }

    private func tick() {
        elapsed += 1
        #if os(iOS) && !targetEnvironment(macCatalyst)
        if Int(elapsed) % 5 == 0 { updateLiveActivity() }
        #endif
        if pomodoroEnabled, elapsed >= phaseTotal { phaseComplete() }
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
        #if os(iOS) && !targetEnvironment(macCatalyst)
        updateLiveActivity()
        #endif
    }

    #if os(iOS)
    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    #endif

    deinit { timer?.invalidate() }
}

#if os(iOS) && !targetEnvironment(macCatalyst)
extension TimerViewModel {
    private var liveActivityState: TimelogActivityAttributes.ContentState {
        TimelogActivityAttributes.ContentState(
            displayTime: displayTime,
            isRunning: isRunning,
            phase: pomodoroEnabled ? phase.label : "Stopwatch"
        )
    }

    private var _liveActivity: Activity<TimelogActivityAttributes>? {
        Activity<TimelogActivityAttributes>.activities.first
    }

    func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endLiveActivity()
        _ = try? Activity.request(
            attributes: TimelogActivityAttributes(),
            content: .init(state: liveActivityState, staleDate: nil)
        )
    }

    func updateLiveActivity() {
        guard let a = _liveActivity else { return }
        Task { await a.update(.init(state: liveActivityState, staleDate: nil)) }
    }

    func endLiveActivity() {
        guard let a = _liveActivity else { return }
        Task { await a.end(.init(state: liveActivityState, staleDate: nil), dismissalPolicy: .immediate) }
    }
}
#endif
