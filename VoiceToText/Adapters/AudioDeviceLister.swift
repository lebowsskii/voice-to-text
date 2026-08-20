import AVFoundation

/// Enumerates the microphones the system currently knows about, for the
/// Settings picker.
enum AudioDeviceLister {

    struct Device: Identifiable, Hashable {
        let uid: String
        let name: String
        var id: String { uid }
    }

    static func inputDevices() -> [Device] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        .devices
        .map { Device(uid: $0.uniqueID, name: $0.localizedName) }
    }
}
