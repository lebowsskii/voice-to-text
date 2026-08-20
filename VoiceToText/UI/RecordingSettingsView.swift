import SwiftUI
import KeyboardShortcuts

/// The "Recording" section of Settings: which microphone to record from, and
/// the hotkey that toggles dictation. Cancel stays a hardcoded Esc — not
/// user-rebindable, since Esc-to-cancel is the expected convention.
struct RecordingSettingsView: View {
    @Bindable var settings: SettingsState

    @State private var devices: [AudioDeviceLister.Device] = []

    /// `nil` (system default) needs its own tag distinct from any real UID,
    /// since `Picker` selection can't tag two rows with the same `nil` value
    /// as the built-in device gets unplugged/replugged.
    private static let systemDefaultTag = ""

    var body: some View {
        Form {
            Section("Microphone") {
                Picker("Input device", selection: deviceSelection) {
                    Text("System Default").tag(Self.systemDefaultTag)
                    ForEach(pickerDevices) { device in
                        Text(device.name).tag(device.uid)
                    }
                }
            }

            Section("Hotkey") {
                KeyboardShortcuts.Recorder("Toggle dictation:", name: .toggleDictation) { shortcut in
                    settings.toggleDictationShortcutDescription = shortcut?.description ?? "Not set"
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            devices = AudioDeviceLister.inputDevices()
        }
    }

    /// The saved device may no longer be plugged in. Rather than let the
    /// `Picker` fall back to a blank selection (the invalid-selection trap
    /// the Gemini model picker already works around), show it anyway, so the
    /// user sees what's selected and can deliberately switch away from it.
    private var pickerDevices: [AudioDeviceLister.Device] {
        guard let selectedUID = settings.selectedMicDeviceUID,
              !devices.contains(where: { $0.uid == selectedUID }) else {
            return devices
        }
        return devices + [AudioDeviceLister.Device(uid: selectedUID, name: "Not connected")]
    }

    private var deviceSelection: Binding<String> {
        Binding(
            get: { settings.selectedMicDeviceUID ?? Self.systemDefaultTag },
            set: { settings.selectedMicDeviceUID = $0 == Self.systemDefaultTag ? nil : $0 }
        )
    }
}
