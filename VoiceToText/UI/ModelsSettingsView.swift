import SwiftUI
import AppKit

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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                group(engine: .parakeet, transcriber: parakeet, state: parakeetState)
                group(engine: .whisper, transcriber: whisper, state: whisperState)
            }
            .padding()
        }
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
    private func group(engine: Engine, transcriber: any LocalTranscriber, state: ModelState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(transcriber.metadata.family) by \(transcriber.metadata.vendor)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            card(engine: engine, transcriber: transcriber, state: state)
        }
    }

    @ViewBuilder
    private func card(engine: Engine, transcriber: any LocalTranscriber, state: ModelState) -> some View {
        let isSelected = settings.selectedEngine == engine
        let isReady = state == .ready

        HStack(alignment: .top, spacing: 12) {
            // Dimmed together, and the radio swapped for a lock, so a model
            // that can't be selected yet reads as unavailable at a glance —
            // only the state view (Download/progress/Retry) stays at full
            // strength, since that's the one thing still actionable.
            Group {
                Image(systemName: isReady ? (isSelected ? "largecircle.fill.circle" : "circle") : "lock.fill")
                    .foregroundStyle(isSelected && isReady ? Color.accentColor : .secondary)
                    .imageScale(.large)

                VStack(alignment: .leading, spacing: 6) {
                    Text(transcriber.modelName)
                        .font(.headline)

                    HStack(spacing: 14) {
                        HStack(spacing: 4) {
                            Image(systemName: "internaldrive")
                            Text(transcriber.metadata.diskSize)
                        }
                        .help("Disk size — actual RAM usage while loaded may differ")

                        HStack(spacing: 4) {
                            Image(systemName: "globe")
                            Text(transcriber.metadata.languages)
                        }

                        Button {
                            NSWorkspace.shared.open(transcriber.metadata.infoURL)
                        } label: {
                            Image(systemName: "info.circle")
                        }
                        .buttonStyle(.plain)
                        .help("View model page")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .opacity(isReady ? 1 : 0.55)

            Spacer()

            stateView(state, transcriber: transcriber)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.2), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            // A model that isn't downloaded/loaded yet has nothing to switch
            // to — selecting it would silently leave `selectedEngine` pointing
            // at an engine that can't transcribe until it finishes preparing.
            guard isReady else { return }
            settings.selectedEngine = engine
        }
        .help(isReady ? "" : "Download this model to select it")
    }

    @ViewBuilder
    private func stateView(_ state: ModelState, transcriber: any LocalTranscriber) -> some View {
        switch state {
        case .notDownloaded:
            Button("Download") {
                Task { try? await transcriber.prepare() }
            }
            .buttonStyle(.borderedProminent)
        case .downloading(let progress):
            if let progress {
                HStack(spacing: 6) {
                    ProgressView(value: progress)
                        .frame(width: 80)
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 36, alignment: .trailing)
                }
            } else {
                ProgressView()
                    .frame(width: 80)
                    .scaleEffect(0.6)
            }
        case .loading:
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text("Loading… this can take a minute").foregroundStyle(.secondary)
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
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
