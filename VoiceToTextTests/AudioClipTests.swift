import Testing
@testable import VoiceToText

@Suite("AudioClip")
struct AudioClipTests {

    @Test("duration is derived from sample count and rate")
    func durationFromSamples() {
        let clip = AudioClip(samples: Array(repeating: 0, count: 32_000), sampleRate: 16_000)
        #expect(clip.duration == 2.0)
    }

    @Test("a clip without samples is empty and has zero duration")
    func emptyClip() {
        let clip = AudioClip(samples: [], sampleRate: 16_000)
        #expect(clip.isEmpty)
        #expect(clip.duration == 0)
    }
}
