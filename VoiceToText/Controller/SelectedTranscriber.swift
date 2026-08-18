import Foundation

/// Dispatches to whichever local engine `SettingsState` currently selects.
/// This is the only place in the app that knows switching engines is
/// possible — `DictationController` is handed this as a single opaque
/// `Transcriber` and never finds out.
final class SelectedTranscriber: Transcriber {
    private let parakeet: any LocalTranscriber
    private let whisper: any LocalTranscriber
    private let settings: SettingsState

    init(parakeet: any LocalTranscriber, whisper: any LocalTranscriber, settings: SettingsState) {
        self.parakeet = parakeet
        self.whisper = whisper
        self.settings = settings
    }

    func transcribe(_ clip: AudioClip) async throws -> String {
        try await current.transcribe(clip)
    }

    private var current: any LocalTranscriber {
        switch settings.selectedEngine {
        case .parakeet: parakeet
        case .whisper: whisper
        }
    }
}
