import SwiftUI

struct SplashView: View {
    @Binding var isShowing: Bool

    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.8
    @State private var glowRadius: CGFloat = 0
    @State private var showSubtitle = false

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.07, blue: 0.12), Color(white: 0.03)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Icon with glow
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 110, height: 110)
                        .blur(radius: glowRadius)

                    Image(systemName: "clock.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .foregroundColor(.accentColor)
                }
                .padding(.bottom, 28)

                // Title
                Text("Timelog")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.bottom, 8)

                // Subtitle
                if showSubtitle {
                    Text("Track your time.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer()

                // Version at bottom
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.2))
                    .padding(.bottom, 32)
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear { animate() }
    }

    private func animate() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
            opacity = 1
            scale   = 1.0
        }
        withAnimation(.easeOut(duration: 1.2)) {
            glowRadius = 18
        }
        withAnimation(.easeIn(duration: 0.4).delay(0.3)) {
            showSubtitle = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeIn(duration: 0.35)) {
                opacity = 0
                scale   = 1.05
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isShowing = false
            }
        }
    }
}

#Preview {
    SplashView(isShowing: .constant(true))
}
