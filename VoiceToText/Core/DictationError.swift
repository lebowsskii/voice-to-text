import Foundation

enum DictationError: Error, Equatable {
    case microphoneUnavailable
    case accessibilityDenied
    case transcriptionFailed(String)

    var message: String {
        switch self {
        case .microphoneUnavailable:
            "Microphone is unavailable. Check Privacy & Security settings."
        case .accessibilityDenied:
            "Text is on the clipboard — paste it with ⌘V. Grant Accessibility access to paste automatically."
        case .transcriptionFailed(let detail):
            "Transcription failed: \(detail)"
        }
    }
}
