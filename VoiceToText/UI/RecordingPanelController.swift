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

        // The hosting controller resizes the window to fit the SwiftUI content,
        // so this has to run after that has settled.
        DispatchQueue.main.async { [weak self] in
            self?.position(panel)
        }

        position(panel)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    private func makePanel() -> NSPanel {
        let hosting = NSHostingController(rootView: RecordingPanelView(controller: controller))
        hosting.sizingOptions = [.preferredContentSize]

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

    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(.init(
            x: visible.midX - size.width / 2,
            y: visible.minY + bottomInset
        ))
    }
}

/// A borderless panel still refuses to show up unless it can become key —
/// this subclass allows that without activating the app.
private final class NonActivatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
