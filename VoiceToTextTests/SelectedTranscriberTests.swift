import Testing
import Foundation
@testable import VoiceToText

@Suite("SelectedTranscriber")
struct SelectedTranscriberTests {

    private func freshSettings(engine: Engine = .parakeet) -> SettingsState {
        let suiteName = "SelectedTranscriberTests.\(UUID().uuidString)"
        let store = SettingsStore(defaults: UserDefaults(suiteName: suiteName)!)
        let apiKeyStore = GeminiAPIKeyStore(service: suiteName)
        let settings = SettingsState(store: store, apiKeyStore: apiKeyStore)
        settings.selectedEngine = engine
        return settings
    }

    @Test("routes to Parakeet when Parakeet is selected")
    func routesToParakeet() async throws {
        let parakeet = FakeLocalTranscriber(modelName: "Parakeet v3")
        parakeet.result = .success("from parakeet")
        let whisper = FakeLocalTranscriber(modelName: "Whisper Large v3 Turbo")
        let settings = freshSettings(engine: .parakeet)
        let selected = SelectedTranscriber(parakeet: parakeet, whisper: whisper, settings: settings)

        let clip = AudioClip(samples: [0.1], sampleRate: 16_000)
        let text = try await selected.transcribe(clip)

        #expect(text == "from parakeet")
        #expect(parakeet.receivedClips == [clip])
        #expect(whisper.receivedClips.isEmpty)
    }

    @Test("routes to Whisper when Whisper is selected")
    func routesToWhisper() async throws {
        let parakeet = FakeLocalTranscriber(modelName: "Parakeet v3")
        let whisper = FakeLocalTranscriber(modelName: "Whisper Large v3 Turbo")
        whisper.result = .success("from whisper")
        let settings = freshSettings(engine: .whisper)
        let selected = SelectedTranscriber(parakeet: parakeet, whisper: whisper, settings: settings)

        let clip = AudioClip(samples: [0.1], sampleRate: 16_000)
        let text = try await selected.transcribe(clip)

        #expect(text == "from whisper")
        #expect(whisper.receivedClips == [clip])
        #expect(parakeet.receivedClips.isEmpty)
    }

    @Test("re-reads selection on every call — switching mid-session takes effect immediately")
    func reReadsSelectionEachCall() async throws {
        let parakeet = FakeLocalTranscriber(modelName: "Parakeet v3")
        let whisper = FakeLocalTranscriber(modelName: "Whisper Large v3 Turbo")
        let settings = freshSettings(engine: .parakeet)
        let selected = SelectedTranscriber(parakeet: parakeet, whisper: whisper, settings: settings)

        let clip = AudioClip(samples: [0.1], sampleRate: 16_000)
        _ = try await selected.transcribe(clip)
        settings.selectedEngine = .whisper
        _ = try await selected.transcribe(clip)

        #expect(parakeet.receivedClips.count == 1)
        #expect(whisper.receivedClips.count == 1)
    }

    @Test("prepares the selected engine before transcribing when its files are already on disk")
    func preparesDownloadedEngineBeforeTranscribing() async throws {
        let parakeet = FakeLocalTranscriber(modelName: "Parakeet v3")
        // Files on disk, not yet loaded into memory — the state an engine is in
        // after the user switches to it mid-session.
        parakeet.state = .ready
        let whisper = FakeLocalTranscriber(modelName: "Whisper Large v3 Turbo")
        let settings = freshSettings(engine: .parakeet)
        let selected = SelectedTranscriber(parakeet: parakeet, whisper: whisper, settings: settings)

        _ = try await selected.transcribe(AudioClip(samples: [0.1], sampleRate: 16_000))

        #expect(parakeet.prepareCallCount == 1)
    }

    @Test("never prepares an engine that isn't downloaded — no accidental multi-minute download")
    func doesNotPrepareUndownloadedEngine() async throws {
        let parakeet = FakeLocalTranscriber(modelName: "Parakeet v3")
        parakeet.state = .notDownloaded
        let whisper = FakeLocalTranscriber(modelName: "Whisper Large v3 Turbo")
        let settings = freshSettings(engine: .parakeet)
        let selected = SelectedTranscriber(parakeet: parakeet, whisper: whisper, settings: settings)

        _ = try await selected.transcribe(AudioClip(samples: [0.1], sampleRate: 16_000))

        #expect(parakeet.prepareCallCount == 0)
    }

    @Test("never prepares the engine that isn't selected")
    func doesNotPrepareUnselectedEngine() async throws {
        let parakeet = FakeLocalTranscriber(modelName: "Parakeet v3")
        let whisper = FakeLocalTranscriber(modelName: "Whisper Large v3 Turbo")
        whisper.state = .ready
        let settings = freshSettings(engine: .parakeet)
        let selected = SelectedTranscriber(parakeet: parakeet, whisper: whisper, settings: settings)

        _ = try await selected.transcribe(AudioClip(samples: [0.1], sampleRate: 16_000))

        #expect(whisper.prepareCallCount == 0)
    }
}
