import Foundation

/// Recorded audio in the one format every engine in this app expects:
/// 16 kHz mono float samples.
struct AudioClip: Equatable {
    let samples: [Float]
    let sampleRate: Double

    var duration: TimeInterval {
        guard sampleRate > 0 else { return 0 }
        return Double(samples.count) / sampleRate
    }

    var isEmpty: Bool { samples.isEmpty }
}
