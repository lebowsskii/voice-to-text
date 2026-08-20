import AppKit
import AVFoundation
import ApplicationServices
import SwiftUI

/// The "About" section of Settings: app identity, a link back to the repo,
/// and live status for the two macOS permissions the app depends on. Reads
/// `AVCaptureDevice`/`AXIsProcessTrusted` directly rather than through the
/// DI'd `AccessibilityChecking` protocol `PasteInserter` uses — that
/// indirection exists so `PasteInserterTests` can fake it, but this view
/// only ever displays state, never gates behavior, so there's nothing to fake.
struct AboutSettingsView: View {
    /// Bumped to force a re-read of both permissions below — there's no
    /// notification for "the user granted a permission", so this piggybacks
    /// on the app regaining focus, which is what actually happens right
    /// after they do that in System Settings and switch back.
    @State private var refreshTick = 0

    private var microphoneAuthorized: Bool {
        _ = refreshTick
        return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    private var accessibilityTrusted: Bool {
        _ = refreshTick
        return AXIsProcessTrusted()
    }

    var body: some View {
        VStack(spacing: 20) {
            header

            Form {
                Section("Permissions") {
                    permissionRow(
                        title: "Microphone",
                        granted: microphoneAuthorized,
                        settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
                    )
                    permissionRow(
                        title: "Accessibility",
                        granted: accessibilityTrusted,
                        settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                    )
                }
            }
            .formStyle(.grouped)
        }
        .padding(.top, 12)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshTick += 1
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)

            Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "VoiceToText")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Version \(marketingVersion) (\(buildNumber))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Link("View on GitHub", destination: URL(string: "https://github.com/lebowsskii/voice-to-text")!)
                .font(.caption)
        }
    }

    private var marketingVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    @ViewBuilder
    private func permissionRow(title: String, granted: Bool, settingsURL: String) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(granted ? .green : .orange)
            Text(title)
            Spacer()
            if granted {
                Text("Granted").foregroundStyle(.secondary)
            } else {
                Button("Open Settings") {
                    NSWorkspace.shared.open(URL(string: settingsURL)!)
                }
            }
        }
    }
}
