import AppKit
import ApplicationServices
import Foundation

/// Everything the app saved from the user's clipboard before overwriting it.
struct PasteboardSnapshot {
    let items: [NSPasteboard.PasteboardType: Data]
    let plainText: String?
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
    func snapshot() -> PasteboardSnapshot {
        let pasteboard = NSPasteboard.general
        var items: [NSPasteboard.PasteboardType: Data] = [:]
        for type in pasteboard.types ?? [] {
            if let data = pasteboard.data(forType: type) {
                items[type] = data
            }
        }
        return PasteboardSnapshot(items: items, plainText: pasteboard.string(forType: .string))
    }

    func write(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    func restore(_ snapshot: PasteboardSnapshot) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        for (type, data) in snapshot.items {
            pasteboard.setData(data, forType: type)
        }
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
