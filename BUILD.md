# BirdPi BUILD.md

## Why Arduino, not ESPHome

Checked first: ESPHome's voice/mic support (`voice_assistant`, `microphone` components) is built around Home AssistantAssistant pipelines — there's no supported component for raw continuous 16 kHz PDM capture pushed to an arbitrary WebSocket. Writing a custom ESPHome external component to do it ends up being *more* code than just writing the Arduino sketch directly. So: **Arduino (ESP32 core) + the `WebSockets` library + ESP32's built-in `PDM` (I2S-PDM) driver.** Arduino IDE or PlatformIO both work; instructions below use Arduino IDE 2.x.

## What you need

- Seeed XIAO ESP32-S3 Sense (+ the included circular PDM mic module already snapped on)
- USB-C cable (data, not charge-only)
- Arduino IDE 2.x
- LiPo + TP4056 only if running off-battery (see Power section in README)

**Wiring: near zero.** The PDM mic is a mezzanine board that stacks onto the XIAO's pads. You don't solder anything for audio. Battery (optional) goes to the `BAT` pad / built-in JST-ish pads per the Seeed wiki.

## Flash the XIAO

1. **Boards package:** Arduino IDE → Boards Manager → install `esp32` by Espressif Systems (3.x).
2. **Board:** Tools → Board → `XIAO_ESP32S3`.
3. **Libraries** (Library Manager):
   - `WebSockets` by Markus Sattler (links2004) — for the WS client
   - `ArduinoJson` — for the small metadata/status frames
4. Open `firmware/birdpi_xiao.ino`.
5. Edit the top of the file: `WIFI_SSID`, `WIFI_PASS`, `WS_HOST` (your iPhone's IP or a host running the receiver), `WS_PORT`.
6. **Enter bootloader:** tap RESET once (or hold BOOT while plugging in) if upload fails.
7. Upload. Open Serial Monitor @115200. You should see:
   ```
   [BIRDPI] WiFi connected
   [BIRDPI] PDM configured: 16000 Hz, 16-bit mono
   [BIRDPI] WS connected to ws://192.168.1.42:8765/
   ```

## Pair with the iPhone app

1. Open the `ios/` project in Xcode, run on a real iPhone (same WiFi as the XIAO).
2. The app's Settings screen shows the phone's current IP — set that as `WS_HOST` in the firmware (or make `WS_HOST` the mDNS name `birdpi.local` if you flash a static receiver elsewhere).
3. Grant **Local Network** permission when iOS prompts (required for the phone to accept inbound LAN connections).
4. Grant **Microphone** permission — needed by Sound Analysis even when analyzing a network stream.
5. Watch the app's meter: chirps → species name + confidence.

## Duty cycle behavior

The firmware does NOT deep-sleep while streaming — deep-sleep would drop the TCP/WebSocket connection. Instead:
- **Listen window** (default 30 s): PDM capture + WS streaming.
- **Off window** (default 90 s): light-sleep with WiFi modem off (`esp_wifi_stop`), keeps TCP alive. This is what gives the days-of-runtime number in the README's power section, not full deep sleep.
- True deep sleep (`esp_deep_sleep_start`) is available as a compile-time flag `BIRDPI_AGGRESSIVE_SLEEP=1` for maximum battery life at the cost of reconnect overhead (~4 s) per cycle.

## Troubleshooting

- **WS won't connect:** iPhone "Local Network" permission denied is the #1 cause. Settings → Privacy → Local Network → allow the app.
- **PDM noise/garbage:** make sure the mic mezzanine board is firmly seated; PDM CLK/DAT lines are short traces on the stack, a loose seat shows up as periodic noise spikes.
- **Upload fails:** hold BOOT while plugging USB, then upload.
- **mDNS:** not used by default; the ESP32 Arduino core's mDNS + WiFi + I2S stack can be flaky together. Static IP or receiver IP is fine.

## shellcheck

`scripts/flash.sh` (helper that wraps `arduino-cli`) is linted with shellcheck — run `shellcheck scripts/flash.sh` if you edit it.
