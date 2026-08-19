import AppKit
import SwiftUI

/// Horizontal-tab shell for the whole Settings window. Only "Models" is
/// implemented; "Recording" (mic + hotkey) and "About" (permissions) are
/// later steps and get placeholders so this shell isn't rebuilt twice.
struct SettingsWindow: View {
    let parakeet: any LocalTranscriber
    let whisper: any LocalTranscriber
    @Bindable var settings: SettingsState

    var body: some View {
        TabView {
            ModelsSettingsView(parakeet: parakeet, whisper: whisper, settings: settings)
                .tabItem { Label("Models", systemImage: "gearshape") }

            Text("Coming soon")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .tabItem { Label("Recording", systemImage: "mic") }

            Text("Coming soon")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .padding()
        .frame(minWidth: 380, minHeight: 560)
        // Settings is opened by temporarily flipping the app to a regular
        // activation policy (see `openSettingsWindow` in VoiceToTextApp) so
        // the window can be raised and shows up in Cmd+Tab. This view
        // disappearing means the window closed — flip back to accessory so
        // the app returns to living only in the menu bar.
        .onDisappear {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
