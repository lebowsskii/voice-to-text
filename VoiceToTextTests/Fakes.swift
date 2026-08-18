import Foundation
@testable import VoiceToText

final class FakeAudioSource: AudioSource {
    var onLevel: ((Float) -> Void)?

    var clipToReturn = AudioClip(samples: Array(repeating: 0.5, count: 16_000), sampleRate: 16_000)
    var startError: Error?

    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var cancelCount = 0

    func start() throws {
        if let startError { throw startError }
        startCount += 1
    }

    func stop() -> AudioClip {
        stopCount += 1
        return clipToReturn
    }

    func cancel() { cancelCount += 1 }
}

final class FakeTranscriber: Transcriber {
    var result: Result<String, Error> = .success("hello world")
    private(set) var receivedClips: [AudioClip] = []

    func transcribe(_ clip: AudioClip) async throws -> String {
        receivedClips.append(clip)
        return try result.get()
    }
}

/// A transcriber whose `transcribe(_:)` call suspends until the test calls
/// `resume(with:)`, so a test can call `cancel()` on the controller while a
/// transcription is genuinely in flight instead of guessing at timing.
///
/// This is a deliberate departure from the original Task 3 brief, authorized
/// by review ruling: covering "cancel on every step" per the design spec
/// requires a transcriber that can be paused mid-call.
final class SuspendableFakeTranscriber: Transcriber {
    private(set) var receivedClips: [AudioClip] = []

    private var startContinuation: CheckedContinuation<Void, Never>?
    private var resumeContinuation: CheckedContinuation<Void, Never>?
    private var result: Result<String, Error> = .success("hello world")

    func transcribe(_ clip: AudioClip) async throws -> String {
        receivedClips.append(clip)
        startContinuation?.resume()
        startContinuation = nil

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            resumeContinuation = continuation
        }

        return try result.get()
    }

    /// Suspends until `transcribe(_:)` has been called and is waiting on `resume(with:)`.
    func waitUntilStarted() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            startContinuation = continuation
        }
    }

    /// Lets the suspended `transcribe(_:)` call return (or throw) the given result.
    func resume(with result: Result<String, Error>) {
        self.result = result
        resumeContinuation?.resume()
        resumeContinuation = nil
    }
}

final class FakeLocalTranscriber: LocalTranscriber {
    let modelName: String
    var onStateChange: ((ModelState) -> Void)?
    var result: Result<String, Error> = .success("hello world")
    private(set) var receivedClips: [AudioClip] = []
    private(set) var prepareCallCount = 0

    init(modelName: String) {
        self.modelName = modelName
    }

    func transcribe(_ clip: AudioClip) async throws -> String {
        receivedClips.append(clip)
        return try result.get()
    }

    func prepare() async throws {
        prepareCallCount += 1
    }
}

final class FakeTextInserter: TextInserter {
    var insertError: Error?
    private(set) var inserted: [String] = []
    private(set) var flushCount = 0

    func insert(_ text: String) throws {
        if let insertError { throw insertError }
        inserted.append(text)
    }

    func flushPendingRestore() { flushCount += 1 }
}
