# iOS receiver app — BirdPiReceiver

Minimal SwiftUI app that:
1. Hosts a **WebSocket server** on port 8765 (using `Network.framework` `NWListener`) and accepts binary frames of 16 kHz / 16-bit mono PCM from the XIAO.
2. Pushes received samples into Apple's **Sound Analysis** `SNAudioStreamAnalyzer` for real-time classification.
3. Optionally routes the same buffer into a **BirdNET CoreML** model via `coremltools` conversion (see "BirdNET model" below). The hook is stubbed behind a `BirdNetClassifier` protocol so you can plug it in without touching the streaming path.

## Run it

- Open `BirdPiReceiver.xcodeproj` (create one: File → New → Project → iOS App, add the files in this folder).
- Deployment target iOS 17, Swift 5.9.
- Info.plist needs `NSLocalNetworkUsageDescription` and `NSMicrophoneUsageDescription` (Sound Analysis requires mic permission even for stream input).
- Settings tab shows the phone's current IP — put that into the firmware's `WS_HOST`.

## BirdNET model (bring your own, no binaries bundled)

There is **no first-party BirdNET CoreML model and no existing iOS BirdNET app that accepts externally streamed audio** — that's why this repo ships its own receiver. To get BirdNET-grade species labels:

1. Download official weights: [tphakala/BirdNET-v2.4 on HuggingFace](https://huggingface.co/tphakala/BirdNET-v2.4) (TFLite) or [justinchuby/BirdNET-onnx](https://huggingface.co/justinchuby/BirdNET-onnx) (ONNX).
2. Convert to CoreML on a Mac: `pip install coremltools`, load the ONNX/TF graph, run `.convert_to(... "mlprogram")` with input shape `[1, 48000]` (3 s @ 16 kHz float32) — BirdNET's expected window.
3. Drop the resulting `.mlmodel` into the Xcode project; `BirdNetClassifier` in `BirdNetClassifier.swift` picks it up by name.

Until a CoreML model is in place the app falls back to Apple's built-in Sound Analysis classes (`SNClassifySoundRequest`, iOS 17 system sound classifier — includes a broad animal/bird category set, coarser than BirdNET's ~6000 species).

## Honest status

Untested on device in this repo. Streaming code follows Apple's documented `NWListener` + `SNAudioStreamAnalyzer` APIs; expect Xcode signing/permission friction, not logic rewrites.
