import Foundation
import os

/// Cloud speech recognition via the Gemini API. Unlike `ParakeetTranscriber`
/// and `WhisperTranscriber`, this does not conform to `LocalTranscriber` —
/// there is no model to download or load, only an API key and a network
/// call. See `LocalTranscriber.swift` for why that distinction matters.
final class GeminiTranscriber: Transcriber {

    private let apiKeyStore: GeminiAPIKeyStore
    private let settings: SettingsState
    private let session: URLSession
    private let log = Logger(subsystem: "com.lebowsskii.voicetotext", category: "gemini")

    /// Models that reject `generationConfig.thinkingConfig` with a 400
    /// "Invalid argument" — checked before the field is ever sent.
    static let modelsWithoutThinkingConfig: Set<String> = ["gemini-flash-lite-latest"]

    /// Clips shorter than this get padded — very short recordings transcribe
    /// unreliably otherwise.
    private static let minDurationSeconds: Double = 1.5
    private static let paddingDurationSeconds: Double = 1.0

    init(apiKeyStore: GeminiAPIKeyStore, settings: SettingsState, session: URLSession = .shared) {
        self.apiKeyStore = apiKeyStore
        self.settings = settings
        self.session = session
    }

    func transcribe(_ clip: AudioClip) async throws -> String {
        guard !clip.isEmpty else { return "" }
        guard let apiKey = apiKeyStore.get(), !apiKey.isEmpty else {
            throw DictationError.transcriptionFailed("Gemini API key is not set. Add it in Settings → Models.")
        }

        let model = settings.geminiSelectedModel
        // An empty name still forms a valid URL (`models/:generateContent`),
        // so the `guard let url` below would wave it through and the user
        // would see a raw Google 404 body instead of something actionable.
        guard !model.isEmpty else {
            throw DictationError.transcriptionFailed("No Gemini model selected. Pick one in Settings → Models.")
        }
        let components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")
        guard let url = components?.url else {
            throw DictationError.transcriptionFailed("Gemini model name is invalid: \(model)")
        }

        let paddedSamples = Self.padded(clip.samples, sampleRate: clip.sampleRate)
        let base64Audio = Self.wavData(from: paddedSamples, sampleRate: Int(clip.sampleRate)).base64EncodedString()

        var requestBody: [String: Any] = [
            "contents": [[
                "parts": [
                    ["text": "Transcribe the speech from this audio. Provide only the transcription text, without any additional commentary."],
                    ["inline_data": ["mime_type": "audio/wav", "data": base64Audio]]
                ]
            ]]
        ]
        if settings.geminiDisableThinking, !Self.modelsWithoutThinkingConfig.contains(model) {
            requestBody["generationConfig"] = ["thinkingConfig": ["thinkingBudget": 0]]
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Header, not a `?key=` query item: request URLs end up in caches and
        // logs, and this one carries a secret. See `GeminiModelCatalog`.
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await Self.send(request, session: session)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            log.error("Gemini request failed (status \(statusCode)): \(message)")
            throw DictationError.transcriptionFailed("Gemini request failed (status \(statusCode)): \(message)")
        }

        let decoded: GenerateContentResponse
        do {
            decoded = try JSONDecoder().decode(GenerateContentResponse.self, from: data)
        } catch {
            throw DictationError.transcriptionFailed("Gemini response could not be parsed: \(error.localizedDescription)")
        }

        if let blockReason = decoded.promptFeedback?.blockReason {
            throw DictationError.transcriptionFailed("Gemini blocked the request: \(blockReason)")
        }
        guard let text = decoded.candidates?.first?.content?.parts?.first?.text else {
            throw DictationError.transcriptionFailed("Gemini returned no transcription text")
        }
        return text
    }

    /// Retries once or twice, 1s apart, on HTTP 503 ("high demand") — a
    /// status the Gemini API returns regularly regardless of which model is
    /// called. Every other status and every network error passes through
    /// unchanged after the first try.
    private static func send(
        _ request: URLRequest,
        session: URLSession,
        retriesRemaining: Int = 2
    ) async throws -> (Data, URLResponse) {
        let (data, response) = try await session.data(for: request)
        if retriesRemaining > 0,
           let http = response as? HTTPURLResponse,
           http.statusCode == 503 {
            try await Task.sleep(for: .seconds(1))
            return try await send(request, session: session, retriesRemaining: retriesRemaining - 1)
        }
        return (data, response)
    }

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

    private struct GenerateContentResponse: Decodable {
        let candidates: [Candidate]?
        let promptFeedback: PromptFeedback?

        struct Candidate: Decodable {
            let content: Content?
        }
        struct Content: Decodable {
            let parts: [Part]?
        }
        struct Part: Decodable {
            let text: String?
        }
        struct PromptFeedback: Decodable {
            let blockReason: String?
        }
    }
}

private extension FixedWidthInteger {
    var littleEndianData: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<Self>.size)
    }
}
