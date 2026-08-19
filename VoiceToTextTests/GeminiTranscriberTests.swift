import Testing
import Foundation
@testable import VoiceToText

@Suite("GeminiTranscriber")
struct GeminiTranscriberTests {

    @Test("a clip at or above 1.5s is left unchanged")
    func longClipUnpadded() {
        let samples = [Float](repeating: 0.5, count: 24_000) // 1.5s at 16kHz
        #expect(GeminiTranscriber.padded(samples, sampleRate: 16_000).count == samples.count)
    }

    @Test("a clip under 1.5s gets 1s of silence appended")
    func shortClipPadded() {
        let samples = [Float](repeating: 0.5, count: 8_000) // 0.5s at 16kHz
        let result = GeminiTranscriber.padded(samples, sampleRate: 16_000)

        #expect(result.count == 8_000 + 16_000)
        #expect(result.prefix(8_000).allSatisfy { $0 == 0.5 })
        #expect(result.suffix(16_000).allSatisfy { $0 == 0 })
    }

    @Test("WAV data starts with a valid RIFF/WAVE header sized for the sample count")
    func wavHeaderIsWellFormed() {
        let samples: [Float] = [0, 0.5, -0.5, 1.0, -1.0]
        let data = GeminiTranscriber.wavData(from: samples, sampleRate: 16_000)

        #expect(data.count == 44 + samples.count * 2) // 44-byte header + 16-bit samples
        #expect(data.prefix(4) == Data("RIFF".utf8))
        #expect(data[8..<12] == Data("WAVE".utf8))
        #expect(data[36..<40] == Data("data".utf8))
    }

    @Test("out-of-range samples clamp instead of wrapping")
    func samplesClampToInt16Range() {
        let data = GeminiTranscriber.wavData(from: [2.0, -2.0], sampleRate: 16_000)
        let firstSample = Int16(littleEndian: data[44..<46].withUnsafeBytes { $0.load(as: Int16.self) })
        let secondSample = Int16(littleEndian: data[46..<48].withUnsafeBytes { $0.load(as: Int16.self) })

        #expect(firstSample == Int16.max)
        #expect(secondSample == -Int16.max)
    }

    @Test("gemini-flash-lite-latest is the only model that rejects thinkingConfig")
    func thinkingConfigExclusionList() {
        #expect(GeminiTranscriber.modelsWithoutThinkingConfig.contains("gemini-flash-lite-latest"))
        #expect(!GeminiTranscriber.modelsWithoutThinkingConfig.contains("gemini-3.1-flash-lite"))
    }
}
