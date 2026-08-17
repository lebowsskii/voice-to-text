import Testing
import Foundation
@testable import VoiceToText

@MainActor
@Suite("DictationController")
struct DictationControllerTests {

    private func makeController(
        audio: FakeAudioSource = .init(),
        transcriber: FakeTranscriber = .init(),
        inserter: FakeTextInserter = .init()
    ) -> DictationController {
        DictationController(audio: audio, transcriber: transcriber, inserter: inserter)
    }

    @Test("starts out idle")
    func startsIdle() {
        #expect(makeController().state == .idle)
    }

    @Test("first toggle starts recording")
    func firstToggleRecords() {
        let audio = FakeAudioSource()
        let controller = makeController(audio: audio)

        controller.toggle()

        #expect(controller.state == .recording)
        #expect(audio.startCount == 1)
    }

    @Test("second toggle transcribes and inserts, then returns to idle")
    func secondToggleInserts() async {
        let transcriber = FakeTranscriber()
        transcriber.result = .success("привет мир")
        let inserter = FakeTextInserter()
        let controller = makeController(transcriber: transcriber, inserter: inserter)

        controller.toggle()
        await controller.finishForTesting()

        #expect(inserter.inserted == ["привет мир"])
        #expect(controller.state == .idle)
    }

    @Test("cancel throws the recording away without transcribing")
    func cancelDiscards() {
        let audio = FakeAudioSource()
        let transcriber = FakeTranscriber()
        let inserter = FakeTextInserter()
        let controller = makeController(audio: audio, transcriber: transcriber, inserter: inserter)

        controller.toggle()
        controller.cancel()

        #expect(controller.state == .idle)
        #expect(audio.cancelCount == 1)
        #expect(audio.stopCount == 0)
        #expect(transcriber.receivedClips.isEmpty)
        #expect(inserter.inserted.isEmpty)
    }

    @Test("empty transcription inserts nothing")
    func emptyTranscriptionInsertsNothing() async {
        let transcriber = FakeTranscriber()
        transcriber.result = .success("   ")
        let inserter = FakeTextInserter()
        let controller = makeController(transcriber: transcriber, inserter: inserter)

        controller.toggle()
        await controller.finishForTesting()

        #expect(inserter.inserted.isEmpty)
        #expect(controller.state == .idle)
        #expect(controller.lastError == nil)
    }

    @Test("engine failure surfaces an error and returns to idle")
    func engineFailure() async {
        let transcriber = FakeTranscriber()
        transcriber.result = .failure(DictationError.transcriptionFailed("model died"))
        let controller = makeController(transcriber: transcriber)

        controller.toggle()
        await controller.finishForTesting()

        #expect(controller.state == .idle)
        #expect(controller.lastError != nil)
    }

    @Test("missing accessibility permission is reported to the user")
    func accessibilityDenied() async {
        let inserter = FakeTextInserter()
        inserter.insertError = DictationError.accessibilityDenied
        let controller = makeController(inserter: inserter)

        controller.toggle()
        await controller.finishForTesting()

        #expect(controller.state == .idle)
        #expect(controller.lastError == DictationError.accessibilityDenied.message)
    }

    @Test("starting a new dictation flushes the previous clipboard restore")
    func startFlushesRestore() {
        let inserter = FakeTextInserter()
        let controller = makeController(inserter: inserter)

        controller.toggle()

        #expect(inserter.flushCount == 1)
    }

    @Test("input level from the audio source reaches the controller")
    func levelPropagates() {
        let audio = FakeAudioSource()
        let controller = makeController(audio: audio)

        audio.onLevel?(0.75)

        #expect(controller.level == 0.75)
    }

    @Test("dismissing an error clears it")
    func dismissError() async {
        let inserter = FakeTextInserter()
        inserter.insertError = DictationError.accessibilityDenied
        let controller = makeController(inserter: inserter)

        controller.toggle()
        await controller.finishForTesting()
        #expect(controller.lastError != nil)

        controller.dismissError()
        #expect(controller.lastError == nil)
    }
}
