import Foundation
import CoreML

/// Plug-in classifier for a BirdNET CoreML model.
/// 1. Download weights: https://huggingface.co/tphakala/BirdNET-v2.4 (TFLite)
///    or https://huggingface.co/justinchuby/BirdNET-onnx (ONNX)
/// 2. Convert on a Mac with coremltools → input: float32 [1, 48000] @16 kHz.
/// 3. Add the .mlmodel to the Xcode target, then use this class instead of
///    SoundAnalysisClassifier in AppState. No binaries are bundled here.
final class BirdNetClassifier: SoundClassifier {
    private var model: MLModel?

    init(modelName: String = "BirdNET") {
        let config = MLModelConfiguration()
        config.computeUnits = .all
        self.model = try? BirdNetHelper.loadModel(named: modelName, config: config)
    }

    func analyze(_ pcm: [Int16], completion: @escaping (String, Double) -> Void) {
        guard let model else {
            completion("birdnet-model-missing", 0)
            return
        }
        // BirdNET consumes 3-second windows of float32 @16 kHz. Buffer until we
        // have enough samples, then run a single forward pass.
        let window = 48000
        guard pcm.count >= window else { return }
        var floats = [Float](repeating: 0, count: window)
        for i in 0..<window { floats[i] = Float(pcm[i]) / 32768.0 }
        guard let input = try? BirdNetHelper.inputArray(from: floats),
              let out = try? model.prediction(from: BirdNetHelper.pack(input)) else {
            completion("birdnet-error", 0)
            return
        }
        let (species, conf) = BirdNetHelper.topLabel(from: out)
        completion(species, conf)
    }
}

enum BirdNetHelper {
    static func loadModel(named name: String, config: MLModelConfiguration) throws -> MLModel {
        let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc")!
        return try MLModel(contentsOf: url, configuration: config)
    }

    static func inputArray(from floats: [Float]) throws -> MLMultiArray {
        let arr = try MLMultiArray(shape: [1, NSNumber(value: floats.count)], dataType: .float32)
        for (i, v) in floats.enumerated() { arr[i] = NSNumber(value: v) }
        return arr
    }

    static func pack(_ arr: MLMultiArray) -> MLFeatureProvider {
        // Adjust feature name to match your converted model's input, commonly "audio".
        try! MLDictionaryFeatureProvider(dictionary: ["audio": arr])
    }

    static func topLabel(from out: MLFeatureProvider) -> (String, Double) {
        // Adjust output feature name to match your conversion, commonly "output".
        guard let dict = out.featureValue(for: "output")?.dictionaryValue else {
            return ("birdnet-no-output", 0)
        }
        let top = dict.max { a, b in a.value.doubleValue < b.value.doubleValue }
        return (top?.key ?? "?", Double(top?.value.doubleValue ?? 0))
    }
}
