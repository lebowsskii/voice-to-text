import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleDictation = Self(
        "toggleDictation",
        initial: .init(.z, modifiers: [.command, .option])
    )

    static let cancelDictation = Self(
        "cancelDictation",
        initial: .init(.escape)
    )
}
