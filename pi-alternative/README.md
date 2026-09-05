> **ALTERNATIVE DESIGN (superseded scope):** the ~$60 standalone Pi Zero route.
> The current main design is the ~$12 XIAO ESP32-S3 + iPhone classifier (see top-level README).
> Kept here because it's the fully standalone, phone-free option.

# jc-prepper-birdpi (Pi Zero standalone build — alternative)

An open-source, local-first clone of the [BirdWeather PUC](https://www.birdweather.com/) — a ~$249 weatherproof bird-song ID device — built from a $15 Raspberry Pi Zero 2 W, a ~$10 MEMS microphone, and [BirdNET-Pi](https://github.com/mcguirepr89/BirdNET-Pi) (BSD-3). Instead of a paid cloud subscription, detections publish to a **dashboard on your own LAN**.

![status](https://img.shields.io/badge/status-hardware_untested-orange) ![license](https://img.shields.io/badge/license-MIT-blue)

## What it does

- Runs **BirdNET 24/7** — identifies ~6,000 bird species by sound in real time
- Serves a **local web dashboard** (charts, spectrograms, per-species stats) on your LAN
- Records and archives audio clips of every detection
- Fully **local-first**: no cloud account, no subscription, works offline
- One-script setup from a fresh Raspberry Pi OS Lite (64-bit) SD card

## BOM — total ≈ $56

| Item | Price (USD, approx.) |
|---|---|
| Raspberry Pi Zero 2 W | $15 |
| INMP441 I2S MEMS mic module | $8 |
| microSD card 32 GB (A1-class recommended) | $8 |
| 5 V/2.5 A USB power supply | $10 |
| IP65 weatherproof junction box (≈120×80×55 mm) | $10 |
| Silicone/EPDM grommets, cable glands, drip flap, desiccant pack | $5 |
| **Total** | **≈ $56** |

**Optional:** USB sound-card dongle + cheap USB mic ($10–15) as the plug-and-play audio path — see BUILD.md if I2S wiring isn't your thing.

vs. **BirdWeather PUC ≈ $249** (+ optional subscription features).

## What it does NOT do

Honest limits. Read this before you buy parts.

- **No cloud geotagging / BirdWeather map by default.** The PUC streams every detection with GPS location to birdweather.com. This build keeps everything local. (Optional BirdWeather.com integration exists for BirdNET-Pi boxes — see EXTRAS.md.)
- **No GPS out of the box.** The PUC has onboard GPS. Adding a UART GPS module (e.g. u-blox NEO-6M/NEO-M8N, ~$12) to the Pi is a documented upgrade path — see EXTRAS.md — but it is **not** wired, configured, or supported by install.sh. Don't overpromise: a stationary backyard station doesn't really need GPS anyway.
- **No dual microphones, no environmental sensors, no BLE.** The PUC packs two mics plus temp/humidity sensors. This is one mic, no sensors.
- **Lower audio quality.** The INMP441 is a decent MEMS mic, but the PUC's array and DSP are better. Expect good species detection at close-to-medium range; fewer distant/quiet detections.
- **Hobbyist-grade weatherproofing.** IP65 box + grommets ≠ factory-sealed IP67 housing. Mount under an eave if you can.
- **Slower analysis.** The Zero 2 W is the minimum-spec Pi for BirdNET-Pi. Analysis latency per clip is higher than a Pi 4/5 (see "Performance reality check" below).

## Performance reality check (Pi Zero 2 W)

BirdNET-Pi officially lists the Zero 2 W as supported **only with 64-bit Raspberry Pi OS Lite** — that's why install.sh requires it. Known constraints:

- **512 MB RAM** is tight. Expect to run Lite (no desktop), avoid other services, and keep audio retention modest. Adding swap is strongly recommended (install.sh does this).
- **Analysis latency**: community reports put full recording+inference round-trips in the tens-of-seconds range on a Zero 2 W vs near-real-time on a Pi 4/5. Birds still get identified; the "now playing" moment just lags a bit.
- **CPU**: the quad-core A53 runs BirdNET TFLite, but at close to sustained load during detection bursts. Thermals are fine in an open box, worse sealed — leave some air gap.
- If you find it too slow, the same install.sh works on **any 64-bit-capable Pi** (3B+, 4, 5) — just swap the board in the BOM and wire the mic the same way.

References: [BirdNET-Pi hardware docs](https://github.com/mcguirepr89/BirdNET-Pi) (project README / wiki — hardware table lists Pi 0W2 as "requires 64-bit Lite OS"), [BirdNET-Go hardware comparison](https://github.com/tphakala/birdnet-go/blob/main/doc/wiki/hardware.md), [CNX Software Zero 2 W power measurements](https://www.cnx-software.com/2021/12/09/raspberry-pi-zero-2-w-power-consumption/).

## Quick start

1. Flash **Raspberry Pi OS Lite (64-bit)** to a microSD (use Raspberry Pi Imager; pre-configure WiFi + SSH).
2. Boot the Pi, SSH in.
3. Run:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/jerbotclaw-max/jc-prepper-birdpi/main/install.sh | bash
   ```
   ...or clone the repo and `bash install.sh`.
4. Open `http://birdpi.local` (or the Pi's IP) on any LAN device.

Full hardware assembly (mic wiring, enclosure): **[BUILD.md](BUILD.md)**.
Optional BirdWeather.com / solar / GPS / enclosures: **[EXTRAS.md](EXTRAS.md)**.

## Verification status

**Tested logic, untested on hardware.** install.sh passes `shellcheck` (clean) and `bash -n`, and its logic has been reviewed, but it has **not** been run on physical hardware. The BirdNET-Pi project itself was archived by its original maintainer in Aug 2025 and is community-maintained; treat newer Raspberry Pi OS releases (Bookworm+) with caution and prefer Bullseye 64-bit Lite for the least friction. Expect to troubleshoot. File an issue with your experience if you build one.

## Repo contents

| File | Purpose |
|---|---|
| `install.sh` | One-script setup from fresh Raspberry Pi OS Lite 64-bit |
| `config/birdnet-pi-defaults.conf` | Pre-tuned BirdNET-Pi settings the installer applies |
| `BUILD.md` | Hardware assembly: mic wiring tables, SD flash, first boot |
| `EXTRAS.md` | BirdWeather.com integration, solar power sizing, enclosures, GPS |
| `LICENSE` | MIT |

## License

MIT — do what you want, no warranty, don't blame us if a squirrel moves in.
