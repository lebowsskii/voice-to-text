import Foundation

/// Dispatches to whichever engine `SettingsState` currently selects. This is
/// the only place in the app that knows switching engines is possible —
/// `DictationController` is handed this as a single opaque `Transcriber` and
/// never finds out.
///
/// Gemini is handled separately from Parakeet/Whisper because it isn't a
/// `LocalTranscriber`: there's no on-disk model, no download, and so nothing
/// to `prepare()` — see `LocalTranscriber.swift`.
final class SelectedTranscriber: Transcriber {
    private let parakeet: any LocalTranscriber
    private let whisper: any LocalTranscriber
    private let gemini: any Transcriber
    private let settings: SettingsState

    init(parakeet: any LocalTranscriber, whisper: any LocalTranscriber, gemini: any Transcriber, settings: SettingsState) {
        self.parakeet = parakeet
        self.whisper = whisper
        self.gemini = gemini
        self.settings = settings
    }

    func transcribe(_ clip: AudioClip) async throws -> String {
        guard settings.selectedEngine != .gemini else {
            return try await gemini.transcribe(clip)
        }

        let transcriber: any LocalTranscriber = settings.selectedEngine == .parakeet ? parakeet : whisper
        // Only the engine picked at launch got a `prepare()` call, so the other
        // one has files on disk but nothing loaded into memory. Preparing here
        // fixes that — and is idempotent, so a load already in flight is simply
        // awaited. The guard is the point: a `.notDownloaded` engine must never
        // start a multi-minute download behind the user's back, that stays
        // behind the explicit "Download" button in Settings.
        if transcriber.state != .notDownloaded {
            try await transcriber.prepare()
        }
        return try await transcriber.transcribe(clip)
    }
}
