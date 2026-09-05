# BirdPi — the ~$12 bird-watching mic

**⚠️ Untested on hardware.** The firmware and iOS code here are written to spec but have not been compiled or flashed. Expect small fixes (typical first-flash friction: board package versions, PDM pin defines, Info.plist keys). Treat this as a validated design + 90%-there codebase, not a turnkey product.

**What it is:** a Seeed XIAO ESP32-S3 Sense (~$10) with a built-in PDM microphone that streams 16 kHz audio over WiFi to your iPhone. Classification runs **on the iPhone** using Apple's Sound Analysis framework or a BirdNET CoreML model. Total BOM: **~$10–14**.

**What it is NOT:** standalone. If your phone leaves the WiFi, it's a paperweight that hums quietly to itself. This is the honest tradeoff that gets the price from $60 → $12: the $4 mic + $8 MCU does capture and streaming; the $1000 phone you already own does the machine learning.

## Bill of Materials

| Item | Price | Notes |
|---|---|---|
| Seeed XIAO ESP32-S3 Sense | $8–14 | BUILT-IN PDM microphone, no extra mic needed |
| 402030 LiPo battery, 250–400 mAh | $4–6 | Optional; can run off USB power instead |
| TP4056 charger board (if battery) | $1 | Or use XIAO's built-in LiPo charge circuit |
| Hot glue / conformal potting compound | ~$0–3 | Weatherproofing, no 3D printer needed |
| **Total** | **~$10–14** | vs. PUC ($249) or full Pi build (~$60) |

## The Comparison

| | BirdPi (this repo) | Pi Zero route (Alternatives below) | Haizon PUC |
|---|---|---|---|
| **Price** | ~$12 | ~$60 | $249 |
| **Standalone?** | No — needs your iPhone on same WiFi | Yes | Yes |
| **Classification** | On iPhone (Sound Analysis / BirdNET CoreML) | On-device BirdNET-Pi | On-device |
| **Power** | LiPo + deep-sleep duty cycle, days-weeks | Wall power, always-on | Battery, days |
| **Weatherproof** | Hot glue / potting | 3D printed case | IP-rated |
| **Setup** | Flash firmware, open app | Flash SD, SSH in | None |

## Architecture

```
[Bird chirps] → [XIAO PDM mic @16kHz] → [WiFi → WebSocket binary frames]
                                              ↓
                          [iPhone SwiftUI app (ios/)] → [Sound Analysis / BirdNET CoreML]
                                              ↓
                                    [Species + confidence on screen / log]
```

## What's in this repo

- `firmware/` — Arduino (ESP32 core) sketch for the XIAO: PDM capture → WebSocket stream → deep-sleep duty cycling. Chosen over ESPHome because ESPHome has no first-class raw-audio-streaming component; micro-Python/Arduino gives direct control of the PDM driver and WS frames. (See BUILD.md.)
- `ios/` — Minimal SwiftUI app that receives the WebSocket audio and runs classification via Apple's native Sound Analysis (`SNAudioStreamAnalyzer`) with a pluggable hook for a BirdNET CoreML model if/when one is converted.
- `BUILD.md` — Full flashing, pairing, and wiring (hint: there's basically no wiring).
- `POWER.md` — duty-cycle design + realistic battery runtime estimates.
- `ENCLOSURE.md` — hot glue / conformal potting weatherproofing (no 3D print).
- `pi-alternative/` — the original $60 Pi Zero + BirdNET-Pi design, kept as the standalone-on-prem option.

## Honest Limitations

1. **Not standalone.** Kill switch: phone leaves WiFi = no classification. This is a deliberate cost trade, not an accident.
2. **iPhone must be on same LAN** (or you tunnel via Tailscale — works, but that's your problem to configure).
3. **No compiled proof.** Firmware and iOS code are untested on real hardware in this repo.
4. **BirdNET-on-iOS is not a solved path.** No first-party iOS BirdNET app accepts externally streamed audio. We hook into Apple's Sound Analysis framework, which ships with ~4000-category sound classes including some bird species — decent, not BirdNET-grade. For BirdNET-grade results you'd need to convert the BirdNET TFLite/ONNX model to CoreML (see iOS README for leads on model sources; we don't bundle binaries).
5. **PDM mic on a $8 board** is not a research-grade mic. Expect more noise floor than the PUC's calibrated mic.
6. **Range** = whatever your WiFi reaches. No LoRa fallback in this design.

## Alternatives

<details>
<summary><strong>$60 Pi Zero route (standalone, on-prem)</strong> — the original design scope before it was cut for cost</summary>

- **Raspberry Pi Zero 2 W** + USB mic + SD card + PSU ≈ $60 total
- Runs **BirdNET-Pi** (github.com/tphakala/birdnet-pi): a full standalone bird-song classifier with a web UI, species log, live spectrogram, RTSP stream.
- No phone dependency — it classifies 24/7 on-device and logs to a local database you can graph.
- Costs more, draws more power (~5W always-on), needs a proper 3D-printed enclosure, and a Pi Zero 2 W supply chain can be flaky.
- Choose this if you want a standalone always-on unit and don't mind the price.
- Choose BirdPi above if you want the cheapest possible sensor pod and already carry the classifier in your pocket.

</details>

## Credits & prior art

- [BirdNET-Pi](https://github.com/tphakala/birdnet-pi) — the reference standalone build
- [BirdNET](https://github.com/kahst/BirdNET-Analyzer) — the model (Cornell Lab of Ornithology)
- [XIAO ESP32-S3 Sense](https://wiki.seeedstudio.com/xiao_esp32s3_getting_started/) — the $8 board with the built-in mic
- [tphakala/BirdNET-v2.4 on HuggingFace](https://huggingface.co/tphakala/BirdNET-v2.4) — official-ish model weights, TFLite/ONNX, ready for CoreML conversion
- [justinchuby/BirdNET-onnx](https://huggingface.co/justinchuby/BirdNET-onnx) — ONNX weights, coremltools converts ONNX→CoreML

Delivery-Status: pending
Battery + duty cycle notes: POWER.md
Enclosure (hot glue / potting): ENCLOSURE.md
