import UIKit

/// Every screen hides the navigation bar, which also switches off iOS's edge swipe to go back.
/// This turns it back on for any pushed screen, except ones that hide the back button on
/// purpose (e.g. "Posted", where going back to the audience step makes no sense).
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === interactivePopGestureRecognizer else { return true }
        guard viewControllers.count > 1, let top = topViewController else { return false }
        return !top.navigationItem.hidesBackButton
    }

    /// Let the edge swipe win over scroll views and other gestures on the screen.
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizer === interactivePopGestureRecognizer
    }
}
