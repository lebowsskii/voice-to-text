import SwiftUI

/// The menu bar icon. Red while recording, spinning while transcribing.
struct MenuBarLabel: View {
    let state: DictationController.State

    var body: some View {
        switch state {
        case .idle:
            Image(systemName: "waveform")
        case .recording:
            Image(systemName: "waveform.circle.fill")
                .foregroundStyle(.red)
        case .transcribing:
            Image(systemName: "ellipsis.circle")
        }
    }
}
