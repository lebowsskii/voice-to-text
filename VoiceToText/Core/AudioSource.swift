import Foundation

/// Captures audio from somewhere — a microphone in production, a canned clip in tests.
protocol AudioSource: AnyObject {
    /// Called with the current input level (0…1) while recording, for the waveform.
    /// Implementations must call this on the main thread.
    var onLevel: ((Float) -> Void)? { get set }

    func start() throws
    /// Stops recording and returns everything captured since `start()`.
    func stop() -> AudioClip
    /// Stops recording and throws the audio away.
    func cancel()
}
