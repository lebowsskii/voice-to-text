import FluidAudio
import Foundation
import os

/// Local speech recognition with Parakeet TDT v3 (25 languages) running on the
/// Apple Neural Engine.
final class ParakeetTranscriber: LocalTranscriber {

    let modelName = "Parakeet v3"

    /// Setting this replays `currentState` immediately (see the
    /// `LocalTranscriber` doc comment for why) — a view that starts
    /// observing after the model was already downloaded must not see a
    /// stale `.notDownloaded`.
    ///
    /// Lock-guarded because the write comes from the main thread (the Settings
    /// view appearing) while `replayCurrentState` reads it from whatever queue
    /// FluidAudio runs its progress callback on.
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
    private var manager: AsrManager?
    private var prepareTask: Task<Void, Error>?
    private var loadFailure: String?
    private var currentState: ModelState
    private let prepareLock = NSLock()
    private let log = Logger(subsystem: "com.lebowsskii.voicetotext", category: "parakeet")

    /// Where FluidAudio keeps its CoreML models. Static because Swift forbids
    /// referencing any instance computed property through `self` — even one
    /// that, like this one, doesn't read stored state — until every stored
    /// property has an initial value, and `init` needs this before
    /// `currentState` is set.
    private static var modelsDirectory: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VoiceToText")
            .appendingPathComponent("Models")
    }

    init() {
        let ready = AsrModels.modelsExist(at: Self.modelsDirectory, version: .v3)
        currentState = ready ? .ready : .notDownloaded
    }

    /// Downloads the model on first run and loads it into memory. Call once at
    /// launch — the first call can take minutes on a slow connection.
    func prepare() async throws {
        let (task, isNewTask) = prepareLock.withLock { () -> (Task<Void, Error>, Bool) in
            if let existing = prepareTask {
                return (existing, false)
            } else {
                let newTask = Task {
                    try FileManager.default.createDirectory(at: Self.modelsDirectory, withIntermediateDirectories: true)

                    self.log.info("Loading Parakeet v3 from \(Self.modelsDirectory.path)")
                    let models = try await AsrModels.load(
                        from: Self.modelsDirectory,
                        version: .v3,
                        progressHandler: { [weak self] progress in
                            self?.reportDownloadProgress(progress)
                        }
                    )
                    self.prepareLock.withLock {
                        self.manager = AsrManager(models: models)
                    }
                    self.log.info("Parakeet v3 ready")
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
            log.error("Parakeet v3 failed to load: \(error.localizedDescription)")
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
        let (manager, loadFailure) = prepareLock.withLock { (self.manager, self.loadFailure) }

        guard let manager else {
            // "Still loading" is a lie once the load has failed — it tells the
            // user to wait for something that is never coming.
            throw DictationError.transcriptionFailed(
                loadFailure.map { "Parakeet model failed to load: \($0)" }
                    ?? "Parakeet model is still loading"
            )
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

    private func reportDownloadProgress(_ progress: DownloadProgress) {
        // FluidAudio's `fractionCompleted` already spans the whole
        // download-then-compile pipeline as one continuous 0...1 value —
        // downloading occupies [0, 0.5], compiling advances the rest of the
        // way to 1.0 (see FluidAudio's `ProgressReporter`). Switching to a
        // bare `.loading` spinner for `.compiling` discarded that second
        // half entirely, which is why the bar looked stuck at 50%: that IS
        // where the download genuinely finishes.
        switch progress.phase {
        case .listing, .downloading, .compiling:
            report(.downloading(progress: progress.fractionCompleted))
        }
    }

    private func report(_ state: ModelState) {
        prepareLock.withLock { currentState = state }
        replayCurrentState()
    }

    /// Reads the state *inside* the dispatched block, not before it: two
    /// `report` calls racing from different threads would otherwise capture
    /// their states first and could land on the main queue out of order,
    /// latching the UI on a stale one (a trailing `.compiling` callback
    /// arriving after `.ready` would leave "Loading…" on screen forever).
    /// Whichever block runs last now reads whatever is true at that moment.
    private func replayCurrentState() {
        let handler = onStateChange
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            handler?(self.prepareLock.withLock { self.currentState })
        }
    }
}
