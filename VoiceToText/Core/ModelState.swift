import Foundation

/// Download/load state of a local transcription model, shown in Settings.
enum ModelState: Equatable {
    case notDownloaded
    /// `progress` is 0...1, or `nil` when the underlying download API
    /// doesn't report a fraction (shown as an indeterminate spinner).
    case downloading(progress: Double?)
    /// Files are on disk; the model is being loaded/compiled into memory.
    case loading
    case ready
    case failed(String)
}
