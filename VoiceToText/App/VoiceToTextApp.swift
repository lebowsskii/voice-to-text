import AppKit
import KeyboardShortcuts
import SwiftUI

@main
struct VoiceToTextApp: App {

    @Environment(\.openSettings) private var openSettings

    @State private var controller: DictationController
    @State private var settings: SettingsState
    @State private var panel: RecordingPanelController?
    /// Auto-dismiss timer for the currently shown error. Re-created (and the
    /// old one cancelled) every time `lastError` changes, so a stale timer
    /// from a previous error can never dismiss the one currently on screen.
    @State private var errorDismissTask: Task<Void, Never>?
    private let parakeet: ParakeetTranscriber
    private let whisper: WhisperTranscriber

    init() {
        // The composition root: the one place that picks concrete adapters.
        // Everything below this line only ever sees the Core protocols.
        let apiKeyStore = GeminiAPIKeyStore()
        let settings = SettingsState(store: SettingsStore(), apiKeyStore: apiKeyStore)
        self._settings = State(initialValue: settings)

        let parakeet = ParakeetTranscriber()
        let whisper = WhisperTranscriber()
        self.parakeet = parakeet
        self.whisper = whisper

        let selected = SelectedTranscriber(parakeet: parakeet, whisper: whisper, settings: settings)

        _controller = State(initialValue: DictationController(
            audio: MicRecorder(),
            transcriber: selected,
            inserter: PasteInserter(
                pasteboard: SystemPasteboard(),
                accessibility: SystemAccessibility(),
                keystrokes: SystemKeystrokes(),
                scheduler: TimerRestoreScheduler()
            )
        ))

        // `cancelDictation` is a bare Esc, registered globally via Carbon. Left
        // enabled at all times it would swallow every Esc press system-wide —
        // closing dialogs, exiting vim, dismissing autocomplete — since a
        // registered hotkey goes to us *instead of* the focused app, not
        // alongside it. Start disabled; `updateCancelShortcut` below toggles
        // it on only while a dictation is actually in flight.
        KeyboardShortcuts.disable(.cancelDictation)
    }

    var body: some Scene {
        MenuBarExtra {
            Text("Press ⌘⌥Z to dictate")
            Divider()
            Button("Settings…") {
                openSettingsWindow()
            }
            Divider()
            Button("Quit VoiceToText") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            MenuBarLabel(state: controller.state)
                .task {
                    // Downloads the selected model on first run; later launches
                    // just load it. Discarding the error is safe only because
                    // `prepare()` reports it via `onStateChange`/logs and every
                    // later `transcribe()` reports it too — there is no UI at
                    // launch to show it in.
                    switch settings.selectedEngine {
                    case .parakeet: try? await parakeet.prepare()
                    case .whisper: try? await whisper.prepare()
                    }
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
                // The Esc gate lives in KeyboardShortcuts' global state but is
                // maintained from here, so it outlives this view while the
                // observation that keeps it honest does not. `initial: true`
                // re-syncs the gate every time the label view is created: if a
                // dictation ends while no view exists to see the transition,
                // the replacement view would otherwise inherit `.idle` as its
                // baseline, never fire, and leave Esc registered at rest —
                // silently stealing Esc system-wide for the rest of the session.
                .onChange(of: controller.state, initial: true) { _, newState in
                    updateCancelShortcut(for: newState)
                }
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

        Settings {
            SettingsWindow(parakeet: parakeet, whisper: whisper, settings: settings)
        }
    }

    /// `LSUIElement` makes this a menu-bar-only accessory app: no Dock icon,
    /// no Cmd+Tab entry, and opening a window doesn't raise it above other
    /// apps. Flip to a regular app for as long as Settings is open so the
    /// window can actually come to the front and be found again later; the
    /// window's `.onDisappear` (see `SettingsWindow`) flips it back.
    @MainActor
    private func openSettingsWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
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

    /// Registers the global Esc hotkey only while a dictation is actually in
    /// flight, so it never steals Esc from other apps at rest. `.idle` covers
    /// all three ways a dictation ends — insert, cancel, error — because every
    /// exit path in `DictationController` either runs `reset()`, which sets
    /// `state = .idle`, or is reachable only after `cancel()` already ran it.
    /// (The `Task.isCancelled` early returns in `finish()` are the latter kind.)
    /// A future change that cancels `finishTask` from anywhere but `cancel()`
    /// would break that precondition — and with it this gate.
    @MainActor
    private func updateCancelShortcut(for state: DictationController.State) {
        switch state {
        case .idle:
            KeyboardShortcuts.disable(.cancelDictation)
        case .recording, .transcribing:
            KeyboardShortcuts.enable(.cancelDictation)
        }
    }
}
