import SwiftUI

struct SplashView: View {
    @Binding var isShowing: Bool

    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.85

    var body: some View {
        ZStack {
            Color(white: 0.05)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "clock.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .foregroundStyle(.accent)

                VStack(spacing: 4) {
                    Text("Timelog")
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

                    Text(String(localized: "Track your time."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                opacity = 1
                scale = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeIn(duration: 0.3)) {
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isShowing = false
                }
            }
        }
    }
}

#Preview {
    SplashView(isShowing: .constant(true))
}
