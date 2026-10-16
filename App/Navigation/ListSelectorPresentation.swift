import SwiftUI
import UIKit

/// Keeps the Lists chooser open for outside/repeated taps while allowing native tab navigation.
struct ListSelectorPresentation: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Observer {
        Observer()
    }

    func updateUIViewController(_ controller: Observer, context: Context) {
        controller.configurePopover()
    }

    final class Observer: UIViewController, UIPopoverPresentationControllerDelegate {
        private weak var previousDelegate: (any UIPopoverPresentationControllerDelegate)?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            configurePopover()
        }

        func configurePopover() {
            var ancestor = parent
            while let controller = ancestor {
                if let popover = controller.popoverPresentationController {
                    if popover.delegate !== self {
                        previousDelegate = popover.delegate
                        popover.delegate = self
                    }
                    if let root = controller.presentingViewController?.view.window?.rootViewController,
                       let bar = tabBar(in: root)
                    {
                        popover.passthroughViews = [bar]
                    }
                    return
                }
                ancestor = controller.parent
            }
        }

        func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
            false
        }

        func popoverPresentationControllerShouldDismissPopover(
            _ popoverPresentationController: UIPopoverPresentationController
        ) -> Bool {
            false
        }

        func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
            .none
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            previousDelegate?.presentationControllerDidDismiss?(presentationController)
        }

        @available(iOS, introduced: 8.0, deprecated: 13.0)
        func popoverPresentationControllerDidDismissPopover(
            _ popoverPresentationController: UIPopoverPresentationController
        ) {
            previousDelegate?.popoverPresentationControllerDidDismissPopover?(popoverPresentationController)
        }

        private func tabBar(in controller: UIViewController) -> UITabBar? {
            if let tabs = controller as? UITabBarController {
                return tabs.tabBar
            }
            for child in controller.children {
                if let bar = tabBar(in: child) {
                    return bar
                }
            }
            return nil
        }
    }
}
