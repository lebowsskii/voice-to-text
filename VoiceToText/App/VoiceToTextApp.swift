import KeyboardShortcuts
import SwiftUI

@main
struct VoiceToTextApp: App {

    @State private var controller: DictationController
    @State private var panel: RecordingPanelController?
    /// Auto-dismiss timer for the currently shown error. Re-created (and the
    /// old one cancelled) every time `lastError` changes, so a stale timer
    /// from a previous error can never dismiss the one currently on screen.
    @State private var errorDismissTask: Task<Void, Never>?
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
                .task {
                    for await _ in KeyboardShortcuts.events(.keyUp, for: .cancelDictation) {
                        controller.cancel()
                    }
                }
                .onChange(of: controller.state) { _, _ in updatePanel() }
                .onChange(of: controller.lastError) { _, error in
                    updatePanel()

                    // Whatever was showing before — gone now, whether it was
                    // dismissed, replaced, or cleared by a fresh dictation.
                    // Its timer must not reach into the future and dismiss
                    // whatever (if anything) replaces it, even if the new
                    // error has the exact same text as the old one.
                    errorDismissTask?.cancel()

                    guard error != nil else {
                        errorDismissTask = nil
                        return
                    }
                    // Give the user time to read it, then get out of the way.
                    errorDismissTask = Task {
                        try? await Task.sleep(for: .seconds(6))
                        guard !Task.isCancelled else { return }
                        controller.dismissError()
                    }
                }
        }
    }

    /// The panel is visible whenever something is happening — a dictation in
    /// progress, or an error the user has not seen yet.
    @MainActor
    private func updatePanel() {
        let resolvedPanel: RecordingPanelController
        if let panel {
            resolvedPanel = panel
        } else {
            resolvedPanel = RecordingPanelController(controller: controller)
            panel = resolvedPanel
        }

        if controller.state == .idle && controller.lastError == nil {
            resolvedPanel.hide()
        } else {
            resolvedPanel.show()
        }
    }
}
