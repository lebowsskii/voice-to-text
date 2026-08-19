import Foundation
import os

/// Cloud speech recognition via the Gemini API. Unlike `ParakeetTranscriber`
/// and `WhisperTranscriber`, this does not conform to `LocalTranscriber` —
/// there is no model to download or load, only an API key and a network
/// call. See `LocalTranscriber.swift` for why that distinction matters.
final class GeminiTranscriber {

    private static let log = Logger(subsystem: "com.lebowsskii.voicetotext", category: "gemini")

    /// Models that reject `generationConfig.thinkingConfig` with a 400
    /// "Invalid argument" — checked before the field is ever sent.
    static let modelsWithoutThinkingConfig: Set<String> = ["gemini-flash-lite-latest"]

    /// Clips shorter than this get padded — very short recordings transcribe
    /// unreliably otherwise.
    private static let minDurationSeconds: Double = 1.5
    private static let paddingDurationSeconds: Double = 1.0

    static func padded(_ samples: [Float], sampleRate: Double) -> [Float] {
        guard sampleRate > 0, Double(samples.count) / sampleRate < minDurationSeconds else { return samples }
        let paddingSamples = Int(paddingDurationSeconds * sampleRate)
        return samples + [Float](repeating: 0, count: paddingSamples)
    }

    static func wavData(from samples: [Float], sampleRate: Int) -> Data {
        let int16Samples: [Int16] = samples.map { sample in
            let clamped = max(-1.0, min(1.0, sample))
            return Int16(clamped * Float(Int16.max))
        }

        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate) * UInt32(numChannels) * UInt32(bitsPerSample) / 8
        let blockAlign = numChannels * bitsPerSample / 8
        let dataSize = UInt32(int16Samples.count * 2)
        let chunkSize = 36 + dataSize

        var data = Data()
        data.append("RIFF".data(using: .ascii)!)
        data.append(chunkSize.littleEndianData)
        data.append("WAVE".data(using: .ascii)!)

        data.append("fmt ".data(using: .ascii)!)
        data.append(UInt32(16).littleEndianData)
        data.append(UInt16(1).littleEndianData) // PCM
        data.append(numChannels.littleEndianData)
        data.append(UInt32(sampleRate).littleEndianData)
        data.append(byteRate.littleEndianData)
        data.append(blockAlign.littleEndianData)
        data.append(bitsPerSample.littleEndianData)

        data.append("data".data(using: .ascii)!)
        data.append(dataSize.littleEndianData)
        for sample in int16Samples {
            data.append(sample.littleEndianData)
        }

        return data
    }
}

private extension FixedWidthInteger {
    var littleEndianData: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<Self>.size)
    }
}
