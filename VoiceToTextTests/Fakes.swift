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
