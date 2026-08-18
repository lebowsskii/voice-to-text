import SwiftUI

/// The "Models" section of Settings: pick the active engine, watch it
/// download/load if it isn't ready yet.
struct ModelsSettingsView: View {
    let parakeet: any LocalTranscriber
    let whisper: any LocalTranscriber
    @Bindable var settings: SettingsState

    @State private var parakeetState: ModelState = .notDownloaded
    @State private var whisperState: ModelState = .notDownloaded

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
            // Prevent the row's own tap-to-select from also firing.
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
            Text(message)
                .foregroundStyle(.red)
                .lineLimit(1)
                .help(message)
        }
    }
}
