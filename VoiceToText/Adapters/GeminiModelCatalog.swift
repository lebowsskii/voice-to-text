import Foundation
import Observation
import os

/// Available Gemini models for `generateContent`, fetched from the API and
/// cached to disk so Settings never opens with an empty picker. The model
/// list is never hardcoded: Google has closed models to new API keys
/// without warning before (`gemini-2.5-flash` started 404ing for fresh
/// keys), and a hardcoded name would silently break transcription the same
/// way. See docs/superpowers/specs/2026-08-20-gemini-transcriber-design.md.
@Observable
final class GeminiModelCatalog {
    private(set) var models: [String]
    private(set) var lastFetchFailed = false

    private let cacheURL: URL
    private let session: URLSession
    private let log = Logger(subsystem: "com.lebowsskii.voicetotext", category: "gemini-catalog")

    static var defaultCacheDirectory: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VoiceToText")
    }

    init(session: URLSession = .shared, cacheDirectory: URL = GeminiModelCatalog.defaultCacheDirectory) {
        self.session = session
        self.cacheURL = cacheDirectory.appendingPathComponent("gemini-models.json")
        self.models = Self.readCache(at: cacheURL)
    }

    /// Refreshes `models` from the API. Call once at cold start and whenever
    /// the API key is saved — never when Settings merely opens, that would
    /// only add latency to opening a window for no benefit (see spec).
    func refresh(apiKey: String) async {
        guard !apiKey.isEmpty else { return }

        var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models")!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components.url else { return }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                log.error("Gemini model list request failed with status \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                lastFetchFailed = true
                return
            }

            let decoded = try JSONDecoder().decode(ListModelsResponse.self, from: data)
            let names = Self.modelNames(from: decoded.models)
            guard !names.isEmpty else {
                lastFetchFailed = true
                return
            }

            models = names
            lastFetchFailed = false
            Self.writeCache(names, to: cacheURL)
            log.info("Gemini model list refreshed: \(names.count) models")
        } catch {
            log.error("Gemini model list refresh failed: \(error.localizedDescription)")
            lastFetchFailed = true
        }
    }

    struct ListModelsResponse: Decodable {
        let models: [Model]

        struct Model: Decodable {
            let name: String
            let supportedGenerationMethods: [String]?
        }
    }

    static func modelNames(from models: [ListModelsResponse.Model]) -> [String] {
        models
            .filter { $0.supportedGenerationMethods?.contains("generateContent") == true }
            .map { model in
                model.name.hasPrefix("models/") ? String(model.name.dropFirst("models/".count)) : model.name
            }
    }

    private static func readCache(at url: URL) -> [String] {
        guard let data = try? Data(contentsOf: url),
              let names = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return names
    }

    private static func writeCache(_ names: [String], to url: URL) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(names) else { return }
        try? data.write(to: url)
    }
}
