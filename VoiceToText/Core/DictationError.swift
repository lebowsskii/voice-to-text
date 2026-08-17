import Foundation

enum DictationError: Error, Equatable {
    case microphoneUnavailable
    /// macOS has not asked about the microphone yet. Distinct from
    /// `microphoneUnavailable` because the user has done nothing wrong and there
    /// is nothing to fix in Settings — they just have a dialog to answer.
    case microphonePermissionNeeded
    case accessibilityDenied
    case transcriptionFailed(String)

    var message: String {
        switch self {
        case .microphoneUnavailable:
            "Microphone is unavailable. Check Privacy & Security settings."
        case .microphonePermissionNeeded:
            "Allow microphone access in the dialog, then press ⌘⌥Z again."
        case .accessibilityDenied:
            "Text is on the clipboard — paste it with ⌘V. Grant Accessibility access to paste automatically."
        case .transcriptionFailed(let detail):
            "Transcription failed: \(detail)"
        }
    }
}
