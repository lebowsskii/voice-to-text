import Foundation
import Observation
import os

/// The dictation state machine: idle → recording → transcribing → idle.
///
/// The only place in the app that knows what is currently happening. It talks
/// to the outside world exclusively through the `Core` protocols, which is why
/// every path below can be tested without a microphone or a network.
@MainActor
@Observable
final class DictationController {

    enum State: Equatable {
        case idle
        case recording
        case transcribing
    }

    private(set) var state: State = .idle
    private(set) var level: Float = 0
    private(set) var startedAt: Date?
    private(set) var lastError: String?

    private let audio: AudioSource
    private let transcriber: Transcriber
    private let inserter: TextInserter
    private let log = Logger(subsystem: "com.lebowsskii.voicetotext", category: "dictation")

    private var finishTask: Task<Void, Never>?

    init(audio: AudioSource, transcriber: Transcriber, inserter: TextInserter) {
        self.audio = audio
        self.transcriber = transcriber
        self.inserter = inserter

        self.audio.onLevel = { [weak self] value in
            MainActor.assumeIsolated { self?.level = value }
        }
    }

    /// Hotkey and the panel's ✓ button both land here.
    func toggle() {
        switch state {
        case .idle:
            start()
        case .recording:
            // Flip synchronously, before the background task even exists, so a
            // `cancel()` that lands in the same run loop turn sees `.transcribing`
            // and takes the right branch instead of falling through to `.recording`.
            state = .transcribing
            finishTask = Task { await finish() }
        case .transcribing:
            break  // already working; ignore
        }
    }

    /// The panel's ✕ button and Esc land here.
    func cancel() {
        switch state {
        case .recording:
            audio.cancel()
        case .transcribing:
            finishTask?.cancel()
        case .idle:
            return
        }
        reset()
    }

    private func start() {
        // The previous dictation may still be holding the user's clipboard.
        inserter.flushPendingRestore()
        lastError = nil

        do {
            try audio.start()
            state = .recording
            startedAt = Date()
        } catch {
            log.error("Could not start recording: \(error.localizedDescription)")
            // Keep the source's own diagnosis when it has one — it can tell
            // "answer the permission dialog" apart from "check your settings",
            // which a blanket `microphoneUnavailable` here would flatten away.
            lastError = (error as? DictationError ?? .microphoneUnavailable).message
            reset()
        }
    }

    private func finish() async {
        // `state` is already `.transcribing` — `toggle()` set it before this task
        // was even created, so a `cancel()` racing with the transcription always
        // observes it and resets us to `.idle` on its own, synchronously.
        let clip = audio.stop()

        do {
            let text = try await transcriber.transcribe(clip)
            guard !Task.isCancelled else { return }

            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            // Silence produces an empty string. Nothing to paste, nothing to report.
            if !trimmed.isEmpty {
                try inserter.insert(trimmed)
            }
        } catch let error as DictationError {
            // A cancellation that raced us here already put the controller back
            // to `.idle` via `cancel()`. Don't resurrect it with an error the
            // user never caused, and don't clobber whatever dictation may have
            // started in the meantime.
            guard !Task.isCancelled else { return }
            log.error("Dictation failed: \(error.message)")
            lastError = error.message
        } catch {
            guard !Task.isCancelled else { return }
            log.error("Dictation failed: \(error.localizedDescription)")
            lastError = DictationError.transcriptionFailed(error.localizedDescription).message
        }

        reset()
    }

    private func reset() {
        state = .idle
        startedAt = nil
        level = 0
        finishTask = nil
    }

    /// Called by the panel once the user has had time to read the error.
    func dismissError() {
        lastError = nil
    }

    #if DEBUG
    /// Lets tests await the transcription that `toggle()` kicks off in the background.
    func finishForTesting() async {
        toggle()
        await finishTask?.value
    }

    /// Exposes the in-flight finish task so tests can capture a reference to it
    /// before calling `cancel()` (which clears it via `reset()`), and later await
    /// its completion deterministically instead of guessing at scheduling order.
    var finishTaskForTesting: Task<Void, Never>? { finishTask }
    #endif
}
