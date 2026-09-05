import Foundation
import SoundAnalysis

/// Classification via Apple Sound Analysis (built-in classifier, iOS 17+).
/// Swap for `BirdNetClassifier` if you add a converted BirdNET .mlmodel —
/// both conform to the same protocol, so nothing else changes.
protocol SoundClassifier {
    func analyze(_ pcm: [Int16], completion: @escaping (String, Double) -> Void)
}

final class SoundAnalysisClassifier: SoundClassifier {
    private let analyzer: SNAudioStreamAnalyzer
    private let queue = DispatchQueue(label: "birdpi.soundanalysis")
    private var request: SNClassifySoundRequest?

    init() {
        analyzer = SNAudioStreamAnalyzer(format: Self.pcmFormat())
        do {
            request = try SNClassifySoundRequest()  // iOS 17 built-in sound classifier
        } catch {
            print("[BirdPi] classify request failed: \(error)")
        }
    }

    static func pcmFormat() -> AVAudioFormat {
        AVAudioFormat(commonFormat: .pcmFormatFloat32,
                      sampleRate: 16000,
                      channels: 1,
                      interleaved: true)!
    }

    func analyze(_ pcm: [Int16], completion: @escaping (String, Double) -> Void) {
        queue.async { [weak self] in
            guard let self, let request = self.request else { return }
            // Int16 → Float32 in [-1, 1]
            var floats = [Float](repeating: 0, count: pcm.count)
            for (i, s) in pcm.enumerated() { floats[i] = Float(s) / 32768.0 }
            guard let buf = AVAudioPCMBuffer(pcmFormat: Self.pcmFormat(),
                                             frameCapacity: AVAudioFrameCount(floats.count)) else { return }
            buf.frameLength = AVAudioFrameCount(floats.count)
            floats.withUnsafeBufferPointer { src in
                buf.floatChannelData![0].update(from: src.baseAddress!, count: floats.count)
            }
            do {
                try self.analyzer.analyze(buffer: buf) { result in
                    guard let result else { return }
                    if let top = result.classifications.first {
                        completion(top.identifier, Double(top.confidence))
                    }
                }
            } catch {
                print("[BirdPi] analyze error: \(error)")
            }
        }
    }
}

// AVAudioFormat import shim
import AVFoundation
