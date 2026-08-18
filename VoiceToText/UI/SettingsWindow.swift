import SwiftUI

/// Sidebar shell for the whole Settings window. Only "Models" is
/// implemented; "Recording" (mic + hotkey) and "About" (permissions) are
/// later steps and get placeholders so this shell isn't rebuilt twice.
struct SettingsWindow: View {
    private enum Section: String, CaseIterable, Identifiable {
        case models = "Models"
        case recording = "Recording"
        case about = "About"
        var id: String { rawValue }
    }

    let parakeet: any LocalTranscriber
    let whisper: any LocalTranscriber
    @Bindable var settings: SettingsState

    @State private var selection: Section? = .models

    var body: some View {
        NavigationSplitView {
            List(Section.allCases, selection: $selection) { section in
                Text(section.rawValue).tag(section)
            }
        } detail: {
            switch selection ?? .models {
            case .models:
                ModelsSettingsView(parakeet: parakeet, whisper: whisper, settings: settings)
            case .recording, .about:
                Text("Coming soon")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 480, minHeight: 320)
    }
}
