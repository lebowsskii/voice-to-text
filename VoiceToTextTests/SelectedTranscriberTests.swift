import Testing
import Foundation
@testable import VoiceToText

@Suite("SelectedTranscriber")
struct SelectedTranscriberTests {

    private func freshSettings(engine: Engine = .parakeet) -> SettingsState {
        let suiteName = "SelectedTranscriberTests.\(UUID().uuidString)"
        let store = SettingsStore(defaults: UserDefaults(suiteName: suiteName)!)
        let settings = SettingsState(store: store)
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
}
