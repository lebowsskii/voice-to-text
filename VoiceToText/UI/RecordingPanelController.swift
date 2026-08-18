import AppKit
import SwiftUI

/// Owns the floating NSPanel the recording pill lives in.
///
/// The panel must never take focus: if it did, the user's cursor would leave
/// their text field and there would be nowhere left to paste.
@MainActor
final class RecordingPanelController {

    private var panel: NSPanel?
    private let controller: DictationController

    /// Distance from the bottom of the screen's visible area.
    private let bottomInset: CGFloat = 90

    init(controller: DictationController) {
        self.controller = controller
    }

    /// Safe to call repeatedly — it also re-centres the panel, which matters
    /// because the error pill is wider than the recording pill.
    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel

        position(panel)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    private func makePanel() -> NSPanel {
        let hosting = NSHostingController(rootView: RecordingPanelView(controller: controller))

        let panel = NonActivatingPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        return panel
    }

    /// Sizes and centres the panel from the content ourselves rather than via
    /// `NSHostingController.sizingOptions = [.preferredContentSize]`: that
    /// option drives an animated window resize (`NSHostingView.
    /// updateAnimatedWindowSize`) that, on a shape change as large as spinner
    /// -> error pill, re-enters `windowDidLayout` before the previous pass has
    /// settled and recurses until CoreAutoLayout overflows the stack.
    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.contentViewController?.view.fittingSize ?? panel.frame.size
        let origin = CGPoint(
            x: visible.midX - size.width / 2,
            y: visible.minY + bottomInset
        )
        panel.setFrame(CGRect(origin: origin, size: size), display: true)
    }
}

/// A borderless panel still refuses to show up unless it can become key —
/// this subclass allows that without activating the app.
private final class NonActivatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
