import DesignSystem
import SwiftUI
import WidgetKit

/// A single entry: the capture widget has no state to show.
struct CaptureEntry: TimelineEntry {
    let date: Date
}

/// Supplies the capture widget's one entry.
struct CaptureProvider: TimelineProvider {
    func placeholder(in _: Context) -> CaptureEntry {
        CaptureEntry(date: .distantPast)
    }

    func getSnapshot(in _: Context, completion: @escaping (CaptureEntry) -> Void) {
        completion(CaptureEntry(date: .distantPast))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<CaptureEntry>) -> Void) {
        // Nothing here changes, so this never needs reloading.
        completion(Timeline(entries: [CaptureEntry(date: .distantPast)], policy: .never))
    }
}

/// A lock screen control that opens straight into the capture field.
///
/// The whole widget is the target, so catching a thought from the lock screen costs one tap and
/// lands on a focused keyboard exactly as a cold launch does.
struct CaptureWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FleetingCapture", provider: CaptureProvider()) { _ in
            CaptureWidgetView()
                .containerBackground(.clear, for: .widget)
                .widgetURL(URL(string: "fleeting://capture"))
        }
        .configurationDisplayName("Capture")
        .description("Jump straight to a blank note.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

/// The capture widget's content.
struct CaptureWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .accessoryCircular {
            Image(systemName: "square.and.pencil")
                .font(Typography.capture)
        } else {
            Label("Capture a thought", systemImage: "square.and.pencil")
                .font(Typography.title)
        }
    }
}
