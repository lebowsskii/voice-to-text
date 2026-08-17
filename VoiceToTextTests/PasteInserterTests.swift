import Testing
import Foundation
@testable import VoiceToText

final class FakePasteboard: Pasteboarding {
    var contents = "user's original clipboard"
    private(set) var snapshots = 0

    func snapshot() -> PasteboardSnapshot {
        snapshots += 1
        return PasteboardSnapshot(items: [:], plainText: contents)
    }

    func write(_ text: String) { contents = text }

    func restore(_ snapshot: PasteboardSnapshot) { contents = snapshot.plainText ?? "" }
}

final class FakeAccessibility: AccessibilityChecking {
    var isTrusted = true
}

final class FakeKeystrokes: KeystrokeSending {
    private(set) var pasteCount = 0
    func sendPaste() { pasteCount += 1 }
}

/// Runs nothing until the test asks it to, so ordering is explicit.
final class ManualScheduler: RestoreScheduling {
    private var pending: (() -> Void)?

    func schedule(after seconds: TimeInterval, work: @escaping () -> Void) {
        pending = work
    }

    func cancelPending() { pending = nil }

    func fire() {
        pending?()
        pending = nil
    }

    var hasPending: Bool { pending != nil }
}

@Suite("PasteInserter")
struct PasteInserterTests {

    private func make() -> (PasteInserter, FakePasteboard, FakeAccessibility, FakeKeystrokes, ManualScheduler) {
        let pasteboard = FakePasteboard()
        let accessibility = FakeAccessibility()
        let keystrokes = FakeKeystrokes()
        let scheduler = ManualScheduler()
        let inserter = PasteInserter(
            pasteboard: pasteboard,
            accessibility: accessibility,
            keystrokes: keystrokes,
            scheduler: scheduler
        )
        return (inserter, pasteboard, accessibility, keystrokes, scheduler)
    }

    @Test("puts the text on the clipboard and sends ⌘V")
    func pastesText() throws {
        let (inserter, pasteboard, _, keystrokes, _) = make()

        try inserter.insert("transcribed text")

        #expect(pasteboard.contents == "transcribed text")
        #expect(keystrokes.pasteCount == 1)
    }

    @Test("restores the original clipboard once the delay elapses")
    func restoresClipboard() throws {
        let (inserter, pasteboard, _, _, scheduler) = make()

        try inserter.insert("transcribed text")
        #expect(pasteboard.contents == "transcribed text")

        scheduler.fire()
        #expect(pasteboard.contents == "user's original clipboard")
    }

    @Test("without Accessibility permission it throws and leaves the text on the clipboard")
    func accessibilityDenied() {
        let (inserter, pasteboard, accessibility, keystrokes, _) = make()
        accessibility.isTrusted = false

        #expect(throws: DictationError.accessibilityDenied) {
            try inserter.insert("transcribed text")
        }

        // The user has to paste manually, so the transcription must survive.
        #expect(pasteboard.contents == "transcribed text")
        #expect(keystrokes.pasteCount == 0)
    }

    @Test("flushPendingRestore restores immediately instead of waiting")
    func flushRestoresEarly() throws {
        let (inserter, pasteboard, _, _, scheduler) = make()

        try inserter.insert("transcribed text")
        inserter.flushPendingRestore()

        #expect(pasteboard.contents == "user's original clipboard")
        #expect(!scheduler.hasPending)
    }

    @Test("flushPendingRestore with nothing pending does nothing")
    func flushWithoutPendingIsSafe() {
        let (inserter, pasteboard, _, _, _) = make()

        inserter.flushPendingRestore()

        #expect(pasteboard.contents == "user's original clipboard")
    }
}
