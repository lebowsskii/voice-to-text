import Foundation

/// Download/load state of a local transcription model, shown in Settings.
enum ModelState: Equatable {
    case notDownloaded
    /// `progress` is 0...1, or `nil` when the underlying download API
    /// doesn't report a fraction (shown as an indeterminate spinner).
    case downloading(progress: Double?)
    /// Files are on disk; the model is being loaded/compiled into memory.
    case loading
    /// The model's files are present locally — which is *not* the same as
    /// being loaded into memory and ready to transcribe: an engine the user
    /// switched to mid-session reports `.ready` while its in-memory manager is
    /// still `nil`. Anything about to actually use the model should go through
    /// `prepare()` first; once the files exist that call is cheap and
    /// idempotent.
    case ready
    case failed(String)
}
