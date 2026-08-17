import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleDictation = Self(
        "toggleDictation",
        initial: .init(.z, modifiers: [.command, .option])
    )
}
