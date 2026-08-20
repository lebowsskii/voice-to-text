import SwiftUI

/// Horizontal-tab shell for the whole Settings window. "About" (permissions)
/// is a later step and gets a placeholder so this shell isn't rebuilt twice.
struct SettingsWindow: View {
    let parakeet: any LocalTranscriber
    let whisper: any LocalTranscriber
    let geminiCatalog: GeminiModelCatalog
    @Bindable var settings: SettingsState

    var body: some View {
        TabView {
            ModelsSettingsView(parakeet: parakeet, whisper: whisper, geminiCatalog: geminiCatalog, settings: settings)
                .tabItem { Label("Models", systemImage: "gearshape") }

            RecordingSettingsView(settings: settings)
                .tabItem { Label("Recording", systemImage: "mic") }

            Text("Coming soon")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .padding()
        .frame(minWidth: 450, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity)
    }
}
