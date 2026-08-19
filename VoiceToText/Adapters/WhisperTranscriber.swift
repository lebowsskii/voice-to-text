import Foundation
import WhisperKit
import os

/// Local speech recognition with Whisper Large v3 Turbo running on the Apple
/// Neural Engine, via WhisperKit.
final class WhisperTranscriber: LocalTranscriber {

    let modelName = "Whisper Large v3 Turbo"

    let metadata = ModelMetadata(
        family: "WhisperKit",
        vendor: "Argmax",
        diskSize: "809 MB",
        languages: "99 languages",
        infoURL: URL(string: "https://huggingface.co/openai/whisper-large-v3-turbo")!
    )

    /// Setting this replays `currentState` immediately (see the
    /// `LocalTranscriber` doc comment for why).
    ///
    /// Lock-guarded because the write comes from the main thread (the Settings
    /// view appearing) while `replayCurrentState` reads it from whatever queue
    /// WhisperKit runs its progress callback on.
    var onStateChange: ((ModelState) -> Void)? {
        get { prepareLock.withLock { _onStateChange } }
        set {
            prepareLock.withLock { _onStateChange = newValue }
            replayCurrentState()
        }
    }

    var state: ModelState {
        prepareLock.withLock { currentState }
    }

    /// All five are guarded by `prepareLock`: they are written from the load
    /// task (or `report`, called from the download's progress callback) and
    /// read from whatever context calls `transcribe` or sets `onStateChange`.
    private var _onStateChange: ((ModelState) -> Void)?
    private var whisperKit: WhisperKit?
    private var prepareTask: Task<Void, Error>?
    private var loadFailure: String?
    private var currentState: ModelState = .notDownloaded
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
                    let modelFolder = try await WhisperKit.download(variant: Self.modelVariant) { [weak self] progress in
                        self?.report(.downloading(progress: progress.fractionCompleted))

                        let percent = Int(progress.fractionCompleted * 100)
                        // fractionCompleted fires many times per second; only log
                        // on each new 10% step so this doesn't flood the log.
                        if percent / 10 != loggedPercent / 10 {
                            loggedPercent = percent
                            self?.log.info("Downloading Whisper Large v3 Turbo: \(percent)%")
                        }
                    }

                    self.log.info("Loading Whisper Large v3 Turbo")
                    self.report(.loading)
                    let config = WhisperKitConfig(model: Self.modelVariant, modelFolder: modelFolder.path, load: true)
                    let kit = try await WhisperKit(config)
                    self.prepareLock.withLock {
                        self.whisperKit = kit
                    }
                    self.log.info("Whisper Large v3 Turbo ready")
                    self.report(.ready)
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
            report(.failed(error.localizedDescription))
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

    private func report(_ state: ModelState) {
        prepareLock.withLock { currentState = state }
        replayCurrentState()
    }

    /// Reads the state *inside* the dispatched block, not before it: two
    /// `report` calls racing from different threads would otherwise capture
    /// their states first and could land on the main queue out of order,
    /// latching the UI on a stale one (a trailing `.downloading` callback
    /// arriving after `.ready` would leave a progress bar on screen forever).
    /// Whichever block runs last now reads whatever is true at that moment.
    private func replayCurrentState() {
        let handler = onStateChange
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            handler?(self.prepareLock.withLock { self.currentState })
        }
    }
}
