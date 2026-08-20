import SwiftUI

/// Horizontal-tab shell for the whole Settings window.
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

            AboutSettingsView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .padding()
        .frame(minWidth: 470, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity)
    }
}
