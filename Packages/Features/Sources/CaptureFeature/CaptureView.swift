import DesignSystem
import SwiftUI

/// The capture screen.
///
/// A placeholder until Phase 1. It exists now so the app shell has something to launch
/// into and so the dependency graph can be verified end to end.
public struct CaptureView: View {
    /// Creates the capture screen.
    public init() {}

    public var body: some View {
        ZStack {
            Palette.surface.ignoresSafeArea()
            VStack(spacing: Spacing.snug) {
                Text("Fleeting")
                    .font(Typography.title)
                    .foregroundStyle(Palette.ink)
                Text("Phase 0 — foundations")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkMuted)
            }
        }
    }
}

#Preview {
    CaptureView()
}
