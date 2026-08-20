import AVFoundation
import CoreAudio
import Foundation
import os

/// Records the input device selected in Settings (or the system default) and
/// hands back 16 kHz mono samples.
final class MicRecorder: AudioSource {

    /// The sample rate every engine in this app expects.
    static let targetSampleRate: Double = 16_000

    var onLevel: ((Float) -> Void)?

    private let settings: SettingsState
    private let engine = AVAudioEngine()
    private var samples: [Float] = []
    private let samplesLock = NSLock()
    private var tapInstalled = false
    private let log = Logger(subsystem: "com.lebowsskii.voicetotext", category: "recorder")

    init(settings: SettingsState) {
        self.settings = settings
    }

    func start() throws {
        guard !engine.isRunning else {
            throw DictationError.microphoneUnavailable
        }

        // Must come before anything touches `engine.inputNode`. Without a
        // granted microphone, AVAudioEngine does not fail — it starts happily
        // and delivers a stream of zeroes, so the user would see the panel, the
        // timer and a flat waveform, then get silence with no error at all.
        try checkMicrophoneAccess()

        teardown()

        samplesLock.withLock {
            samples.removeAll(keepingCapacity: true)
        }

        let input = engine.inputNode
        applySelectedDevice(to: input)
        let inputFormat = input.outputFormat(forBus: 0)

        // With no usable input device the node reports a degenerate 0 Hz format.
        // Caught here because `installTap` with such a format raises an
        // Objective-C exception, which Swift cannot catch — it takes the app down.
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw DictationError.microphoneUnavailable
        }

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw DictationError.microphoneUnavailable
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw DictationError.microphoneUnavailable
        }

        engine.prepare()
        try engine.start()

        // The converter is captured by the tap rather than stored on `self`: it
        // is used only from the tap thread, and a stored property would be
        // written here on the main thread while being read there.
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.append(buffer, converter: converter, target: targetFormat)
        }
        tapInstalled = true
        log.info("Recording started at \(inputFormat.sampleRate) Hz")
    }

    func stop() -> AudioClip {
        teardown()
        let result = samplesLock.withLock {
            AudioClip(samples: samples, sampleRate: Self.targetSampleRate)
        }
        log.info("Recording stopped, \(result.duration, format: .fixed(precision: 1)) s captured")
        return result
    }

    func cancel() {
        teardown()
        samplesLock.withLock {
            samples.removeAll()
        }
    }

    private func teardown() {
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        if engine.isRunning {
            engine.stop()
        }
    }

    /// Points this recorder's own `AVAudioEngine` at the device chosen in
    /// Settings, scoped to this app — unlike changing the system-wide default
    /// input device, it leaves every other app's input alone. A `nil`
    /// selection, or a device that has since been unplugged, is left as the
    /// engine's own default rather than surfaced as an error: falling back
    /// silently beats failing a dictation over a stale device choice.
    private func applySelectedDevice(to input: AVAudioInputNode) {
        guard let uid = settings.selectedMicDeviceUID else { return }
        guard let deviceID = Self.deviceID(forUID: uid) else {
            log.info("Selected mic device is no longer available, using system default")
            return
        }
        guard let audioUnit = input.audioUnit else { return }

        var mutableID = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &mutableID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        if status != noErr {
            log.error("Failed to select mic device \(uid): OSStatus \(status)")
        }
    }

    private static func deviceID(forUID uid: String) -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslateUIDToDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var cfUID = uid as CFString

        let status = withUnsafeMutablePointer(to: &cfUID) { uidPtr in
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                UInt32(MemoryLayout<CFString>.size),
                uidPtr,
                &propertySize,
                &deviceID
            )
        }

        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    /// Throws unless the microphone is ours to use. On a first run this also
    /// raises the system dialog — asynchronously, so this attempt cannot record
    /// either way and says so instead of pretending to.
    private func checkMicrophoneAccess() throws {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return
        case .notDetermined:
            log.info("Microphone access not determined yet, prompting")
            AVCaptureDevice.requestAccess(for: .audio) { [log] granted in
                log.info("Microphone access \(granted ? "granted" : "denied")")
            }
            throw DictationError.microphonePermissionNeeded
        case .denied, .restricted:
            log.error("Microphone access denied")
            throw DictationError.microphoneUnavailable
        @unknown default:
            throw DictationError.microphoneUnavailable
        }
    }

    private func append(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter, target: AVAudioFormat) {
        let ratio = target.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
        guard let converted = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }

        var consumed = false
        var error: NSError?
        converter.convert(to: converted, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }

        if let error {
            log.error("Sample rate conversion failed: \(error.localizedDescription)")
            return
        }

        guard let channel = converted.floatChannelData?[0] else { return }
        let frames = Int(converted.frameLength)
        let chunk = Array(UnsafeBufferPointer(start: channel, count: frames))

        samplesLock.withLock {
            samples.append(contentsOf: chunk)
        }

        report(level: chunk)
    }

    /// Root mean square, scaled so normal speech lands in the upper half of the bar.
    private func report(level chunk: [Float]) {
        guard !chunk.isEmpty, let onLevel else { return }

        let sumOfSquares = chunk.reduce(Float(0)) { $0 + $1 * $1 }
        let rms = (sumOfSquares / Float(chunk.count)).squareRoot()
        let normalized = min(1, rms * 12)

        DispatchQueue.main.async { onLevel(normalized) }
    }
}
