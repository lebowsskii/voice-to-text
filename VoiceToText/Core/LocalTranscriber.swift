import Foundation

/// Static facts about a local model shown on its card in Settings — not
/// download/load state, which lives in `ModelState` instead.
struct ModelMetadata {
    /// Model family, e.g. "Parakeet" or "WhisperKit" — used as the section
    /// header together with `vendor`, e.g. "Parakeet by FluidAudio".
    let family: String
    let vendor: String
    /// On-disk footprint of the downloaded model files. Deliberately not a
    /// claim about RAM usage while loaded, which can differ — the card
    /// labels this explicitly so the two aren't conflated.
    let diskSize: String
    let languages: String
    let infoURL: URL
}

/// A `Transcriber` backed by a local model that must be downloaded and
/// loaded before use — as opposed to a cloud engine like Gemini, which has
/// no such lifecycle. `ParakeetTranscriber` and `WhisperTranscriber` both
/// conform; `ModelsSettingsView` iterates them through this protocol so it
/// doesn't need to know which concrete adapters exist.
protocol LocalTranscriber: AnyObject, Transcriber {
    /// Display name for Settings, e.g. "Parakeet v3".
    var modelName: String { get }

    /// Static description shown on the model's card in Settings.
    var metadata: ModelMetadata { get }

    /// Called with the current state, on the main thread, whenever it
    /// changes. Settable so `ModelsSettingsView` can observe it; follows the
    /// same pattern as `AudioSource.onLevel` — with one addition: setting
    /// this immediately replays the last known state, so a view that starts
    /// observing after the model was already downloaded/loaded doesn't miss
    /// it and get stuck showing a stale "not downloaded".
    var onStateChange: ((ModelState) -> Void)? { get set }

    /// Current state, readable synchronously without going through
    /// `onStateChange` — thread-safe, callable from any context.
    var state: ModelState { get }

    /// Downloads the model if needed and loads it into memory. Idempotent —
    /// safe to call while already in progress or already ready.
    func prepare() async throws
}
