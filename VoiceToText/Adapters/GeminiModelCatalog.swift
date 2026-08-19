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

    /// Preferred fallback whenever the current selection isn't on offer —
    /// fastest and most consistent of the models benchmarked (see
    /// `super-voice-assistant/SharedSources/GeminiModels.swift`). Only used
    /// when it's actually in the list; otherwise falls back to the first
    /// model, same as before.
    static let defaultModelName = "gemini-3.1-flash-lite"

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

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models")!

        // The key goes in a header, never the query string: `URLCache` keys on
        // the request URL and persists it to `~/Library/Caches`, which would
        // write the key to disk in plaintext and undo the whole point of
        // keeping it in the Keychain. `.reloadIgnoringLocalCacheData` is belt
        // and braces on top of that.
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await session.data(for: request)
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

    /// Which model should be selected, given the list currently on offer and
    /// whatever is selected now. Nothing ever picks a first model otherwise:
    /// the stored selection starts empty, so a fresh install would render a
    /// blank picker and send `models/:generateContent` at the API.
    ///
    /// Pure and static so the catalog stays free of any `SettingsState`
    /// dependency — the caller owns the selection, this only answers what it
    /// should be. An empty list leaves the selection alone: that's the
    /// manual-entry path (fetch failed), and clobbering a name the user typed
    /// by hand would be worse than leaving it.
    static func defaultedSelection(current: String, from models: [String]) -> String {
        guard !models.contains(current) else { return current }
        if models.contains(defaultModelName) { return defaultModelName }
        return models.first ?? current
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
