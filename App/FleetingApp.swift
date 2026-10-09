import DesignSystem
import SwiftUI
import UIKit

/// The application entry point.
///
/// Its only job is to build the composition root and hand it to the root view. Per ADR-0008
/// there is nothing between launch and the capture screen — no gate, no prompt, no splash.
@main
struct FleetingApp: App {
    @UIApplicationDelegateAdaptor(SharingApplicationDelegate.self) private var appDelegate
    private let environment = AppEnvironment()

    init() {
        let title = UIFont.preferredFont(forTextStyle: .headline)
        let large = UIFont.preferredFont(forTextStyle: .largeTitle)
        let tab = UIFont.preferredFont(forTextStyle: .caption2)
        if let descriptor = tab.fontDescriptor.withDesign(.serif) {
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont(descriptor: descriptor, size: 0)]
            UITabBarItem.appearance().setTitleTextAttributes(attributes, for: .normal)
            UITabBarItem.appearance().setTitleTextAttributes(attributes, for: .selected)
        }
        if let descriptor = title.fontDescriptor.withDesign(.serif) {
            UINavigationBar.appearance().titleTextAttributes = [.font: UIFont(
                descriptor: descriptor,
                size: 0
            )]
        }
        if let descriptor = large.fontDescriptor.withDesign(.serif) {
            UINavigationBar.appearance().largeTitleTextAttributes = [
                .font: UIFont(descriptor: descriptor, size: 0)
            ]
        }
    }

    var body: some Scene {
        WindowGroup {
            // No `preferredColorScheme`: the palette adapts, so the app looks the way the user
            // has asked their phone to look rather than overriding it (ADR-0020).
            RootView(environment: environment)
                // Without this the tab bar — the most persistent chrome in the app — draws its
                // selection in the system blue, because no tint was ever set. Every other accent
                // on screen is the palette's purple, so the one control always visible was the
                // one control off-palette.
                .tint(Palette.accentText)
                .fontDesign(.serif)
        }
    }
}
