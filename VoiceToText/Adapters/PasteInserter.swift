import Foundation
import os

/// Pastes text at the cursor by borrowing the clipboard, sending ⌘V, and giving
/// the clipboard back.
///
/// macOS offers no signal for "the paste completed", so the clipboard is
/// returned one second later — or as soon as the next dictation starts,
/// whichever comes first. The app this replaces waited a flat 0.2 s, which
/// overwrote the user's clipboard before slower apps had read the paste.
final class PasteInserter: TextInserter {

    private let pasteboard: Pasteboarding
    private let accessibility: AccessibilityChecking
    private let keystrokes: KeystrokeSending
    private let scheduler: RestoreScheduling
    private let restoreDelay: TimeInterval
    private let log = Logger(subsystem: "com.lebowsskii.voicetotext", category: "paste")

    private var pendingSnapshot: PasteboardSnapshot?

    init(
        pasteboard: Pasteboarding,
        accessibility: AccessibilityChecking,
        keystrokes: KeystrokeSending,
        scheduler: RestoreScheduling,
        restoreDelay: TimeInterval = 1.0
    ) {
        self.pasteboard = pasteboard
        self.accessibility = accessibility
        self.keystrokes = keystrokes
        self.scheduler = scheduler
        self.restoreDelay = restoreDelay
    }

    func insert(_ text: String) throws {
        let saved = pasteboard.snapshot()
        pasteboard.write(text)

        // Checked after writing on purpose: if the permission is missing, the
        // transcription stays on the clipboard so the user can paste it by hand.
        guard accessibility.isTrusted else {
            log.error("Accessibility permission missing — leaving text on the clipboard")
            throw DictationError.accessibilityDenied
        }

        pendingSnapshot = saved
        keystrokes.sendPaste()

        scheduler.schedule(after: restoreDelay) { [weak self] in
            self?.restoreNow()
        }
    }

    func flushPendingRestore() {
        scheduler.cancelPending()
        restoreNow()
    }

    private func restoreNow() {
        guard let snapshot = pendingSnapshot else { return }
        pendingSnapshot = nil
        pasteboard.restore(snapshot)
    }
}
