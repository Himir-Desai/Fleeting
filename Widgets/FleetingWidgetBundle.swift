import SwiftUI
import WidgetKit

/// Everything Fleeting puts outside the app.
@main
struct FleetingWidgetBundle: WidgetBundle {
    var body: some Widget {
        FreshnessWidget()
        DailyPlanWidget()
        TomorrowPlanWidget()
        CaptureWidget()
        CaptureControl()
    }
}
