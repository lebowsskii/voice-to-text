import Foundation

/// A `Transcriber` backed by a local model that must be downloaded and
/// loaded before use — as opposed to a cloud engine like Gemini, which has
/// no such lifecycle. `ParakeetTranscriber` and `WhisperTranscriber` both
/// conform; `ModelsSettingsView` iterates them through this protocol so it
/// doesn't need to know which concrete adapters exist.
protocol LocalTranscriber: AnyObject, Transcriber {
    /// Display name for Settings, e.g. "Parakeet v3".
    var modelName: String { get }

    /// Called with the current state, on the main thread, whenever it
    /// changes. Settable so `ModelsSettingsView` can observe it; follows the
    /// same pattern as `AudioSource.onLevel` — with one addition: setting
    /// this immediately replays the last known state, so a view that starts
    /// observing after the model was already downloaded/loaded doesn't miss
    /// it and get stuck showing a stale "not downloaded".
    var onStateChange: ((ModelState) -> Void)? { get set }

    /// Downloads the model if needed and loads it into memory. Idempotent —
    /// safe to call while already in progress or already ready.
    func prepare() async throws
}
