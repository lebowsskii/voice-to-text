import SwiftUI
import AppKit

/// The "Models" section of Settings: pick the active engine, watch it
/// download/load if it isn't ready yet.
struct ModelsSettingsView: View {
    let parakeet: any LocalTranscriber
    let whisper: any LocalTranscriber
    let geminiCatalog: GeminiModelCatalog
    @Bindable var settings: SettingsState

    @State private var parakeetState: ModelState
    @State private var whisperState: ModelState
    @State private var geminiKeyDraft: String
    @State private var isGeminiExpanded: Bool

    /// Seeds the row states from the engines' synchronous `state` instead of a
    /// hardcoded `.notDownloaded`. The `onStateChange` replay set in
    /// `.onAppear` only arrives a frame later, which used to flash a "Download"
    /// button for an engine that is in fact already on disk.
    init(parakeet: any LocalTranscriber, whisper: any LocalTranscriber, geminiCatalog: GeminiModelCatalog, settings: SettingsState) {
        self.parakeet = parakeet
        self.whisper = whisper
        self.geminiCatalog = geminiCatalog
        _settings = Bindable(wrappedValue: settings)
        _parakeetState = State(initialValue: parakeet.state)
        _whisperState = State(initialValue: whisper.state)
        _geminiKeyDraft = State(initialValue: settings.geminiAPIKey)
        // Always starts collapsed — only the arrow opens it from here, so
        // Settings doesn't open with the Gemini card sprawled out every time.
        _isGeminiExpanded = State(initialValue: false)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                group(engine: .parakeet, transcriber: parakeet, state: parakeetState)
                group(engine: .whisper, transcriber: whisper, state: whisperState)
                geminiGroup()
            }
            .padding()
        }
        .onAppear {
            parakeet.onStateChange = { parakeetState = $0 }
            whisper.onStateChange = { whisperState = $0 }
        }
        // Nothing else ever picks a Gemini model: the stored selection starts
        // empty, so without this the picker renders blank (SwiftUI logs an
        // "invalid selection" and does *not* auto-select) and dictation goes
        // out with no model name. Fires on appear as well as on every refresh,
        // so the disk-cached list seeds a selection too — not just a fetch.
        .onChange(of: geminiCatalog.models, initial: true) { _, models in
            settings.geminiSelectedModel = GeminiModelCatalog.defaultedSelection(
                current: settings.geminiSelectedModel,
                from: models
            )
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
    private func geminiGroup() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gemini by Google")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            geminiCard()
        }
    }

    @ViewBuilder
    private func geminiCard() -> some View {
        // The observable flag, not `geminiAPIKey` — that one is a computed
        // Keychain passthrough, which `@Observable` cannot track, so a view
        // reading it registers no dependency and never redraws on a save.
        let hasKey = settings.hasGeminiAPIKey
        let isSelected = settings.selectedEngine == .gemini

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    // The lock stands in for the radio whenever there's no
                    // key — Gemini can't be selected yet, but the row (and
                    // the arrow beside it) stays tappable so the user can
                    // still get to the key field to fix that.
                    Image(systemName: hasKey ? (isSelected ? "largecircle.fill.circle" : "circle") : "lock.fill")
                        .foregroundStyle(isSelected && hasKey ? Color.accentColor : .secondary)
                        .imageScale(.large)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Gemini")
                            .font(.headline)
                        Text("Audio is sent to Google's Gemini API for transcription.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    guard hasKey else { return }
                    settings.selectedEngine = .gemini
                }
                .help(hasKey ? "" : "Add an API key below to select Gemini")

                Spacer()

                // Separate from the row's own tap gesture above so it can
                // open/close the detail regardless of whether a key is set —
                // selecting the engine and expanding the card are two
                // different actions.
                Button {
                    isGeminiExpanded.toggle()
                } label: {
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isGeminiExpanded ? 90 : 0))
                        .foregroundStyle(.secondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .animation(.default, value: isGeminiExpanded)
                .help(isGeminiExpanded ? "Collapse" : "Expand")
            }

            if isGeminiExpanded {
                geminiDetail(hasKey: hasKey)
            }
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
    }

    @ViewBuilder
    private func geminiDetail(hasKey: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SecureField("API key", text: $geminiKeyDraft)
                .textFieldStyle(.roundedBorder)

            Link("Get an API key from Google AI Studio", destination: URL(string: "https://aistudio.google.com/api-keys")!)
                .font(.caption)

            HStack(spacing: 8) {
                Button("Save") {
                    settings.geminiAPIKey = geminiKeyDraft
                    Task { await geminiCatalog.refresh(apiKey: geminiKeyDraft) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(geminiKeyDraft.isEmpty)

                Button("Clear") {
                    geminiKeyDraft = ""
                    settings.geminiAPIKey = ""
                    // Gemini can't transcribe without a key, and its card now
                    // renders as locked — leaving it selected would show a
                    // greyed-out card as the active engine and fail every
                    // dictation from here on.
                    if settings.selectedEngine == .gemini {
                        settings.selectedEngine = .parakeet
                    }
                }
                .disabled(!settings.hasGeminiAPIKey)
            }

            // Without a key there's nothing to fetch a model list with, and a
            // stale cached list from a previously-saved key would offer
            // models the user can no longer actually call — so the field
            // drops to manual entry, disabled, until a key is saved.
            if hasKey && !geminiCatalog.models.isEmpty {
                Picker("Model", selection: $settings.geminiSelectedModel) {
                    ForEach(geminiCatalog.models, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .labelsHidden()
            } else {
                TextField("Model name", text: $settings.geminiSelectedModel)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!hasKey)
                    .help(!hasKey ? "Add an API key to pick a model" : (geminiCatalog.lastFetchFailed ? "Couldn't fetch the model list — enter a model name manually" : ""))
            }

            Toggle("Disable thinking", isOn: $settings.geminiDisableThinking)
                .disabled(!hasKey || GeminiTranscriber.modelsWithoutThinkingConfig.contains(settings.geminiSelectedModel))
        }
        .padding(.leading, 36) // aligns under the label, past the leading icon
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
            // The radio swaps for a lock so a model that can't be selected
            // yet reads as unavailable at a glance.
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
