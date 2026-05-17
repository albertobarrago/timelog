import SwiftUI
import AppKit

// MARK: - View

struct AboutMacView: View {
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    private let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"

    var body: some View {
        VStack(spacing: 0) {
            if let icon = NSImage(named: "AppIcon") {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 80, height: 80)
                    .padding(.top, 24)
            }

            Text("Timelog")
                .font(.system(size: 18, weight: .semibold))
                .padding(.top, 12)

            Text("Version \(version) (\(build))")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.top, 3)

            HStack(spacing: 0) {
                Link("Website", destination: URL(string: "https://albertobarrago.github.io/Timelog")!)
                separator
                Link("GitHub", destination: URL(string: "https://github.com/AlbertoBarrago/Timelog")!)
                separator
                Link("Changelog", destination: URL(string: "https://github.com/AlbertoBarrago/Timelog/blob/main/CHANGELOG.md")!)
            }
            .font(.system(size: 12))
            .padding(.top, 14)
            .padding(.bottom, 26)
        }
        .frame(width: 280)
        .background(.windowBackground)
    }

    private var separator: some View {
        Text("  |  ").foregroundStyle(.tertiary).font(.system(size: 12))
    }
}

// MARK: - Singleton window controller

final class AboutWindowController: NSWindowController {
    static let shared = AboutWindowController()

    private init() {
        let hosting = NSHostingController(rootView: AboutMacView())
        let window = NSPanel(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About Timelog"
        window.contentViewController = hosting
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) { nil }
}
