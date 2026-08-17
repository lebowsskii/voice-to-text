import Foundation

/// Turns recorded audio into text.
///
/// This is the seam of the whole app: a local CoreML model and an HTTP call to
/// a cloud API are both just a `Transcriber`, so nothing above this protocol
/// has to know which one is in use.
protocol Transcriber {
    func transcribe(_ clip: AudioClip) async throws -> String
}
