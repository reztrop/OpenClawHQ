import SwiftUI

struct CyberpunkBackdrop: View {
    var body: some View {
        ZStack {
            Theme.backdropGradient
                .ignoresSafeArea()

            LinearGradient(
                colors: [Theme.neonCyan.opacity(0.08), .clear, Theme.neonMagenta.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.screen)
            .ignoresSafeArea()

            ScanlineOverlay()
                .opacity(0.08)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
}

private struct ScanlineOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let lines = Int(geo.size.height / 3)
            VStack(spacing: 2) {
                ForEach(0..<max(lines, 1), id: \.self) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 1)
                }
            }
        }
    }
}
