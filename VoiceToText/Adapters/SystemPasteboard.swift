import AppKit
import ApplicationServices
import Foundation

/// Everything the app saved from the user's clipboard before overwriting it.
struct PasteboardSnapshot {
    /// One entry per `NSPasteboardItem`, each mapping every type that item
    /// carried to its data. A list rather than a single dictionary because the
    /// clipboard can hold several items at once — two images copied together,
    /// say — and the pasteboard-level `types`/`data(forType:)` API only ever
    /// sees the first one, so restoring from it silently drops the rest.
    let items: [[NSPasteboard.PasteboardType: Data]]
}

protocol Pasteboarding {
    func snapshot() -> PasteboardSnapshot
    func write(_ text: String)
    func restore(_ snapshot: PasteboardSnapshot)
}

protocol AccessibilityChecking {
    var isTrusted: Bool { get }
}

protocol KeystrokeSending {
    func sendPaste()
}

protocol RestoreScheduling {
    func schedule(after seconds: TimeInterval, work: @escaping () -> Void)
    func cancelPending()
}

struct SystemPasteboard: Pasteboarding {
    /// Injectable so tests can run against a private pasteboard instead of
    /// trampling the real clipboard of whoever is running them.
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    func snapshot() -> PasteboardSnapshot {
        let items = (pasteboard.pasteboardItems ?? []).map { item in
            item.types.reduce(into: [NSPasteboard.PasteboardType: Data]()) { byType, type in
                byType[type] = item.data(forType: type)
            }
        }
        return PasteboardSnapshot(items: items)
    }

    func write(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    func restore(_ snapshot: PasteboardSnapshot) {
        pasteboard.clearContents()
        guard !snapshot.items.isEmpty else { return }

        pasteboard.writeObjects(snapshot.items.map { byType in
            let item = NSPasteboardItem()
            for (type, data) in byType {
                item.setData(data, forType: type)
            }
            return item
        })
    }
}

struct SystemAccessibility: AccessibilityChecking {
    var isTrusted: Bool { AXIsProcessTrusted() }
}

struct SystemKeystrokes: KeystrokeSending {
    /// Virtual key code for "v" on any keyboard layout.
    private static let vKeyCode: CGKeyCode = 0x09

    func sendPaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        if let down = CGEvent(keyboardEventSource: source, virtualKey: Self.vKeyCode, keyDown: true) {
            down.flags = .maskCommand
            down.post(tap: .cghidEventTap)
        }
        if let up = CGEvent(keyboardEventSource: source, virtualKey: Self.vKeyCode, keyDown: false) {
            up.flags = .maskCommand
            up.post(tap: .cghidEventTap)
        }
    }
}

final class TimerRestoreScheduler: RestoreScheduling {
    private var workItem: DispatchWorkItem?

    func schedule(after seconds: TimeInterval, work: @escaping () -> Void) {
        cancelPending()
        let item = DispatchWorkItem(block: work)
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }

    func cancelPending() {
        workItem?.cancel()
        workItem = nil
    }
}
