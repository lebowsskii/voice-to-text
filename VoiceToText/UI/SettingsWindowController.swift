import AppKit
import SwiftUI

/// Owns the Settings window directly via AppKit instead of SwiftUI's
/// `Settings` scene. That scene wraps its content in an `NSHostingView` whose
/// internal sizing behavior keeps pinning the window back to a fixed/restored
/// size no matter what `.windowResizability` or a forced `styleMask` says —
/// tried both, neither survived a relayout (e.g. expanding the Gemini card).
/// A window we create ourselves has none of that: same approach
/// `RecordingPanelController` already uses for the recording pill.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let defaultSize = NSSize(width: 450, height: 600)
    private static let frameAutosaveName = "SettingsWindow"

    private var window: NSWindow?

    private let parakeet: any LocalTranscriber
    private let whisper: any LocalTranscriber
    private let geminiCatalog: GeminiModelCatalog
    private let settings: SettingsState

    init(parakeet: any LocalTranscriber, whisper: any LocalTranscriber, geminiCatalog: GeminiModelCatalog, settings: SettingsState) {
        self.parakeet = parakeet
        self.whisper = whisper
        self.geminiCatalog = geminiCatalog
        self.settings = settings
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let hosting = NSHostingController(
            rootView: SettingsWindow(parakeet: parakeet, whisper: whisper, geminiCatalog: geminiCatalog, settings: settings)
        )

        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.title = "Settings"
        window.minSize = Self.defaultSize

        // Restores whatever size the user last dragged the window to
        // (AppKit persists it to `UserDefaults` under this name on every
        // move/resize). Only a fresh install — nothing saved yet — falls
        // back to the default size and gets centered.
        let restoredPreviousFrame = window.setFrameAutosaveName(Self.frameAutosaveName)
        if !restoredPreviousFrame {
            window.setContentSize(Self.defaultSize)
            window.center()
        }
        // The hosting controller otherwise gets released (and its state,
        // including the Gemini key draft field, wiped) the moment the window
        // closes — kept alive so reopening Settings resumes where it left
        // off, same lifetime as `parakeet`/`whisper`/`settings` themselves.
        window.isReleasedWhenClosed = false
        window.delegate = self
        return window
    }

    /// Mirrors what `openSettingsWindow` in `VoiceToTextApp` does going in:
    /// flips the app back to a menu-bar-only accessory once Settings closes,
    /// so it stops showing up in Cmd+Tab and the Dock.
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
