import SwiftUI

/// The "Models" section of Settings: pick the active engine, watch it
/// download/load if it isn't ready yet.
struct ModelsSettingsView: View {
    let parakeet: any LocalTranscriber
    let whisper: any LocalTranscriber
    @Bindable var settings: SettingsState

    @State private var parakeetState: ModelState
    @State private var whisperState: ModelState

    /// Seeds the row states from the engines' synchronous `state` instead of a
    /// hardcoded `.notDownloaded`. The `onStateChange` replay set in
    /// `.onAppear` only arrives a frame later, which used to flash a "Download"
    /// button for an engine that is in fact already on disk.
    init(parakeet: any LocalTranscriber, whisper: any LocalTranscriber, settings: SettingsState) {
        self.parakeet = parakeet
        self.whisper = whisper
        _settings = Bindable(wrappedValue: settings)
        _parakeetState = State(initialValue: parakeet.state)
        _whisperState = State(initialValue: whisper.state)
    }

    var body: some View {
        Form {
            row(engine: .parakeet, transcriber: parakeet, state: parakeetState)
            row(engine: .whisper, transcriber: whisper, state: whisperState)
        }
        .padding()
        .onAppear {
            parakeet.onStateChange = { parakeetState = $0 }
            whisper.onStateChange = { whisperState = $0 }
        }
        // Each `.onAppear` resets these, so this only matters while the window
        // is closed — but leaving a closure pointing at a dead view's state
        // hanging off a process-lifetime object is worth a line to avoid.
        .onDisappear {
            parakeet.onStateChange = nil
            whisper.onStateChange = nil
        }
    }

    @ViewBuilder
    private func row(engine: Engine, transcriber: any LocalTranscriber, state: ModelState) -> some View {
        HStack {
            Button {
                settings.selectedEngine = engine
            } label: {
                HStack {
                    Image(systemName: settings.selectedEngine == engine ? "largecircle.fill.circle" : "circle")
                    Text(transcriber.modelName)
                    Spacer()
                    stateView(state, transcriber: transcriber)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func stateView(_ state: ModelState, transcriber: any LocalTranscriber) -> some View {
        switch state {
        case .notDownloaded:
            Button("Download") {
                Task { try? await transcriber.prepare() }
            }
            .buttonStyle(.bordered)
        case .downloading(let progress):
            if let progress {
                ProgressView(value: progress)
                    .frame(width: 80)
            } else {
                ProgressView()
                    .frame(width: 80)
                    .scaleEffect(0.6)
            }
        case .loading:
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text("Loading…").foregroundStyle(.secondary)
            }
        case .ready:
            Text("Downloaded").foregroundStyle(.secondary)
        case .failed(let message):
            // Both adapters clear `prepareTask` when a load throws, so calling
            // `prepare()` again really does retry from scratch — until now
            // there was no way for the user to ask for that.
            HStack(spacing: 8) {
                Text(message)
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .help(message)
                Button("Retry") {
                    Task { try? await transcriber.prepare() }
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
