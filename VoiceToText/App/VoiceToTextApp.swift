import KeyboardShortcuts
import SwiftUI

@main
struct VoiceToTextApp: App {

    @State private var controller: DictationController
    @State private var panel: RecordingPanelController?
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
                .onChange(of: controller.state) { _, _ in updatePanel() }
                .onChange(of: controller.lastError) { _, error in
                    updatePanel()
                    guard error != nil else { return }
                    // Give the user time to read it, then get out of the way.
                    Task {
                        try? await Task.sleep(for: .seconds(6))
                        controller.dismissError()
                    }
                }
        }
    }

    /// The panel is visible whenever something is happening — a dictation in
    /// progress, or an error the user has not seen yet.
    @MainActor
    private func updatePanel() {
        let panel = panel ?? RecordingPanelController(controller: controller)
        self.panel = panel

        if controller.state == .idle && controller.lastError == nil {
            panel.hide()
        } else {
            panel.show()
        }
    }
}
