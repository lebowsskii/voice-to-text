import SwiftUI

/// The floating pill: ✕ on the left edge, waveform and timer in the middle,
/// ✓ on the right edge. Doubles as the error surface — a failed dictation has
/// to be visible somewhere, and this is the thing the user is already looking at.
struct RecordingPanelView: View {
    /// A plain `let` is enough: SwiftUI tracks reads of an `@Observable` during
    /// body evaluation, and every property here is read-only from the outside.
    let controller: DictationController

    private let barCount = 14

    var body: some View {
        if let error = controller.lastError {
            errorPill(error)
        } else {
            recordingPill
        }
    }

    private func errorPill(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.yellow)

            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(2)
                .frame(maxWidth: 320, alignment: .leading)

            Button {
                controller.dismissError()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 22, height: 22)
                    .background(.white.opacity(0.12), in: .circle)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(9)
        .background(.black.opacity(0.92), in: .capsule)
        .overlay(Capsule().stroke(.white.opacity(0.14)))
    }

    private var recordingPill: some View {
        HStack(spacing: 12) {
            Button {
                controller.cancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 22, height: 22)
                    .background(.white.opacity(0.12), in: .circle)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help("Discard recording (Esc)")

            centre
                .frame(minWidth: 96)

            Button {
                controller.toggle()
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 22, height: 22)
                    .background(.green, in: .circle)
                    .foregroundStyle(.black.opacity(0.8))
            }
            .buttonStyle(.plain)
            .disabled(controller.state == .transcribing)
            .opacity(controller.state == .transcribing ? 0 : 1)
            .help("Finish and paste")
        }
        .padding(7)
        .background(.black.opacity(0.92), in: .capsule)
        .overlay(Capsule().stroke(.white.opacity(0.14)))
    }

    @ViewBuilder
    private var centre: some View {
        switch controller.state {
        case .transcribing:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small).tint(.white)
                Text("Transcribing…")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
            }
        default:
            HStack(spacing: 9) {
                waveform
                timer
            }
        }
    }

    private var waveform: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(.green)
                    .frame(width: 2.5, height: height(for: index))
            }
        }
        .frame(height: 16)
        .animation(.easeOut(duration: 0.12), value: controller.level)
    }

    /// Bars taper towards the edges so the level reads as a shape, not a block.
    private func height(for index: Int) -> CGFloat {
        let centreDistance = abs(Double(index) - Double(barCount - 1) / 2)
        let falloff = 1 - (centreDistance / Double(barCount)) * 1.2
        let value = Double(controller.level) * falloff
        return max(3, CGFloat(value) * 16)
    }

    private var timer: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            Text(elapsed(at: context.date))
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private func elapsed(at now: Date) -> String {
        guard let startedAt = controller.startedAt else { return "0:00" }
        let seconds = Int(now.timeIntervalSince(startedAt))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
