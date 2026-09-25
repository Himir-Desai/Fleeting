import DesignSystem
import SwiftUI

/// Task text with a completion stroke that draws across each wrapped line.
struct PlanTaskText: View {
    let text: String
    let isDone: Bool
    @State private var completion: CGFloat = 0

    var body: some View {
        Group {
            if #available(iOS 18, macOS 15, *) {
                Text(text).textRenderer(CompletionStroke(progress: completion))
            } else {
                Text(text).strikethrough(isDone)
            }
        }
        .font(Typography.serifBody)
        .foregroundStyle(isDone ? Palette.inkMuted : Palette.ink)
        .multilineTextAlignment(.leading)
        .onAppear { completion = isDone ? 1 : 0 }
        .onChange(of: isDone) { _, done in completion = done ? 1 : 0 }
        .motion(Motion.decay, value: completion)
    }
}

@available(iOS 18, macOS 15, *)
private struct CompletionStroke: TextRenderer {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        let totalWidth = layout.reduce(CGFloat.zero) { $0 + $1.typographicBounds.rect.width }
        var remaining = totalWidth * progress
        for line in layout {
            context.draw(line)
            let rect = line.typographicBounds.rect
            let width = min(rect.width, max(0, remaining))
            if width > 0 {
                var path = Path()
                path.move(to: CGPoint(x: rect.minX, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.minX + width, y: rect.midY))
                context.stroke(path, with: .foreground, lineWidth: 1)
            }
            remaining -= rect.width
        }
    }
}
