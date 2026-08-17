import KeyboardShortcuts
import SwiftUI

@main
struct VoiceToTextApp: App {

    @State private var controller: DictationController
    private let parakeet: ParakeetTranscriber

    init() {
        // The composition root: the one place that picks concrete adapters.
        // Everything below this line only ever sees the Core protocols.
        let parakeet = ParakeetTranscriber()
        self.parakeet = parakeet
        _controller = State(initialValue: DictationController(
            audio: MicRecorder(),
            transcriber: parakeet,
            inserter: PasteInserter(
                pasteboard: SystemPasteboard(),
                accessibility: SystemAccessibility(),
                keystrokes: SystemKeystrokes(),
                scheduler: TimerRestoreScheduler()
            )
        ))
    }

    var body: some Scene {
        MenuBarExtra {
            Text("Press ⌘⌥Z to dictate")
            Divider()
            Button("Quit VoiceToText") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            MenuBarLabel(state: controller.state)
                .task {
                    // Downloads the model on first run; later launches just load it.
                    try? await parakeet.prepare()
                }
                .task {
                    // KeyboardShortcuts 3.x: `events(for:)` replaces the legacy
                    // onKeyUp/onKeyDown callbacks used before version 2.
                    for await _ in KeyboardShortcuts.events(.keyUp, for: .toggleDictation) {
                        controller.toggle()
                    }
                }
        }
    }
}
