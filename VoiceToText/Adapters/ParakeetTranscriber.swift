import FluidAudio
import Foundation
import os

/// Local speech recognition with Parakeet TDT v3 (25 languages) running on the
/// Apple Neural Engine.
final class ParakeetTranscriber: Transcriber {

    private var manager: AsrManager?
    private var prepareTask: Task<Void, Error>?
    private let prepareLock = NSLock()
    private let log = Logger(subsystem: "com.lebowsskii.voicetotext", category: "parakeet")

    /// Where FluidAudio keeps its CoreML models.
    private var modelsDirectory: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VoiceToText")
            .appendingPathComponent("Models")
    }

    /// Downloads the model on first run and loads it into memory. Call once at
    /// launch — the first call can take minutes on a slow connection.
    func prepare() async throws {
        let (task, isNewTask) = prepareLock.withLock { () -> (Task<Void, Error>, Bool) in
            if let existing = prepareTask {
                return (existing, false)
            } else {
                let newTask = Task {
                    try FileManager.default.createDirectory(at: self.modelsDirectory, withIntermediateDirectories: true)

                    self.log.info("Loading Parakeet v3 from \(self.modelsDirectory.path)")
                    let models = try await AsrModels.load(from: self.modelsDirectory, version: .v3)
                    self.manager = AsrManager(models: models)
                    self.log.info("Parakeet v3 ready")
                }
                prepareTask = newTask
                return (newTask, true)
            }
        }

        do {
            try await task.value
        } catch {
            if isNewTask {
                prepareLock.withLock {
                    prepareTask = nil
                }
            }
            throw error
        }
    }

    func transcribe(_ clip: AudioClip) async throws -> String {
        guard let manager else {
            throw DictationError.transcriptionFailed("Parakeet model is still loading")
        }
        guard !clip.isEmpty else { return "" }

        do {
            var decoderState = try TdtDecoderState()
            let result = try await manager.transcribe(clip.samples, decoderState: &decoderState)
            return result.text
        } catch {
            throw DictationError.transcriptionFailed(error.localizedDescription)
        }
    }
}
