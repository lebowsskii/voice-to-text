import Foundation
import WhisperKit
import os

/// Local speech recognition with Whisper Large v3 Turbo running on the Apple
/// Neural Engine, via WhisperKit.
final class WhisperTranscriber: Transcriber {

    /// All three are guarded by `prepareLock`: they are written from the load
    /// task and read from whatever context calls `transcribe`.
    private var whisperKit: WhisperKit?
    private var prepareTask: Task<Void, Error>?
    private var loadFailure: String?
    private let prepareLock = NSLock()
    private let log = Logger(subsystem: "com.lebowsskii.voicetotext", category: "whisper")

    /// Matched against file paths in the `argmaxinc/whisperkit-coreml` HuggingFace
    /// repo (`WhisperKit.download`'s `*<variant>/*` glob) to pick the Large v3
    /// Turbo variant without pinning to one dated snapshot name.
    private static let modelVariant = "large-v3-v20240930_turbo"

    /// Downloads the model on first run and loads it into memory. Call once at
    /// launch — the first call can take minutes on a slow connection.
    func prepare() async throws {
        let (task, isNewTask) = prepareLock.withLock { () -> (Task<Void, Error>, Bool) in
            if let existing = prepareTask {
                return (existing, false)
            } else {
                let newTask = Task {
                    self.log.info("Downloading Whisper Large v3 Turbo")
                    var loggedPercent = -1
                    let modelFolder = try await WhisperKit.download(variant: Self.modelVariant) { progress in
                        let percent = Int(progress.fractionCompleted * 100)
                        // fractionCompleted fires many times per second; only log
                        // on each new 10% step so this doesn't flood the log.
                        if percent / 10 != loggedPercent / 10 {
                            loggedPercent = percent
                            self.log.info("Downloading Whisper Large v3 Turbo: \(percent)%")
                        }
                    }

                    self.log.info("Loading Whisper Large v3 Turbo")
                    let config = WhisperKitConfig(model: Self.modelVariant, modelFolder: modelFolder.path, load: true)
                    let kit = try await WhisperKit(config)
                    self.prepareLock.withLock {
                        self.whisperKit = kit
                    }
                    self.log.info("Whisper Large v3 Turbo ready")
                }
                prepareTask = newTask
                loadFailure = nil
                return (newTask, true)
            }
        }

        do {
            try await task.value
        } catch {
            // The only place the real cause is visible: the caller at launch has
            // nowhere to show it, and every later dictation sees just the
            // summary in `loadFailure`.
            log.error("Whisper Large v3 Turbo failed to load: \(error.localizedDescription)")
            prepareLock.withLock {
                loadFailure = error.localizedDescription
                // Clearing the task lets a later call retry the download.
                if isNewTask {
                    prepareTask = nil
                }
            }
            throw error
        }
    }

    func transcribe(_ clip: AudioClip) async throws -> String {
        let (whisperKit, loadFailure) = prepareLock.withLock { (self.whisperKit, self.loadFailure) }

        guard let whisperKit else {
            // "Still loading" is a lie once the load has failed — it tells the
            // user to wait for something that is never coming.
            throw DictationError.transcriptionFailed(
                loadFailure.map { "Whisper model failed to load: \($0)" }
                    ?? "Whisper model is still loading"
            )
        }
        guard !clip.isEmpty else { return "" }

        do {
            let results = try await whisperKit.transcribe(audioArray: clip.samples)
            return results.map(\.text).joined(separator: " ")
        } catch {
            throw DictationError.transcriptionFailed(error.localizedDescription)
        }
    }
}
