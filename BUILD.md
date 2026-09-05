# BUILD.md — Hardware Assembly

Step-by-step: wire the mic, flash the SD, first boot, dashboard. Time: ~1 hour plus flashing.

> **Mic choice:** the **INMP441** is the recommended module — it's the most compatible I2S mic with the Pi's I2S peripheral and is well documented in the community. The **SPH0645** works but has a known clocking/right-slot quirk on the Pi (it historically needed a device-tree tweak or was simply unreliable); if you already have one, see the SPH0645 notes below. **Easiest path:** a $10 USB sound-card dongle + any USB mic — no wiring, no I2S quirks, just plug it in and skip to Step 3.

## Step 1 — Wire the microphone

**Power off the Pi before wiring.**

### INMP441 → Pi Zero 2 W GPIO

| INMP441 pin | Pi GPIO (physical pin) | Notes |
|---|---|---|
| VDD | 3.3 V (pin 1) | **3.3 V only — never 5 V** |
| GND | GND (pin 6 or 9) | |
| SCK (BCLK) | GPIO18 (pin 12) | I2S bit clock |
| WS (LRCL) | GPIO19 (pin 35) | I2S word select / L-R clock |
| SD (DOUT) | GPIO20 (pin 38) | I2S data in |
| L/R | GND (pin 9) | Ties mic to **left** channel |

Use short leads (<15 cm) — I2S is a digital clock signal and long wires cause noise/corruption. Dupont jumper wires work fine.

### SPH0645 → Pi Zero 2 W GPIO (if you must)

Same physical mapping as INMP441 (SCK→GPIO18, WS→GPIO19, SD→GPIO20, VDD→3.3 V, GND→GND, **L/R→GND for left channel**).

**Known quirk:** the SPH0645 expects the word-select clock to lead the bit clock (it samples on the *rising* WS edge, opposite of most I2S devices — the Adafruit write-up documents this against their board). On the Pi this has historically manifested as silence or all-zero reads. Community fixes have included device-tree overlays and, on some boards, a small RC delay on the clock line. If you get silence from an SPH0645 on a Pi Zero 2 W, don't burn an evening — an INMP441 is $8 and just works. (Adafruit documents the quirk on their SPH0645 product page: https://learn.adafruit.com/adafruit-i2s-mems-microphone-breakout)

## Step 2 — Enable I2S

install.sh does this for you, but so you know what it's doing, it appends to `/boot/config.txt` (or `/boot/firmware/config.txt` on newer OS):

```
dtparam=i2s=on
dtoverlay=i2s-mic
```

And adds a software sound card mapping so ALSA exposes the I2S mic as a capture device.

## Step 3 — Flash the SD card

1. Download **Raspberry Pi Imager**: https://www.raspberrypi.com/software/
2. Choose OS → **Raspberry Pi OS (other) → Raspberry Pi OS Lite (64-bit)**. 64-bit is **required** — BirdNET's TFLite runtime for BirdNET-Pi is aarch64-only.
3. Gear icon (⚠️ set these BEFORE flashing):
   - Hostname: `birdpi` (or anything)
   - Enable SSH (password or key)
   - Username + password
   - WiFi SSID + password, your country code
4. Flash, insert card, boot the Pi (~2 min first boot).

## Step 4 — Run the installer

SSH in (`ssh user@birdpi.local`), then:

```bash
curl -fsSL https://raw.githubusercontent.com/jerbotclaw-max/jc-prepper-birdpi/main/install.sh -o install.sh
bash install.sh
```

(or `git clone` the repo first if you prefer). The script:

- Verifies you're on aarch64 + Raspberry Pi OS
- Installs dependencies and BirdNET-Pi non-interactively
- Applies `config/birdnet-pi-defaults.conf` (confidence 0.7, 24/7 recording, daily cache cleanup)
- Adds swap (512 MB RAM is tight), disables HTTPS on the web UI for LAN use
- Reboots once at the end

Total run time on a Zero 2 W: roughly 20–40 min (compilation/installs are slow on the little board — go make coffee).

## Step 5 — Dashboard

After reboot, open on any LAN device:

- **http://birdpi.local** (or `http://<pi-ip-address>`)

You should see the BirdNET-Pi web UI: live detections, spectrograms, species charts. First detections typically appear within minutes of birds actually singing.

## Step 6 — Enclosure

- Mount the Pi + mic inside an IP65 junction box.
- **Sound hole:** drill a 6–8 mm hole facing the mic port, oriented **downward or sideways** (never straight up — rain pool). Glue a small piece of Gore-Tex fabric or fine stainless mesh behind the hole as an insect/rain barrier.
- **Drainage:** drill a 3 mm weep hole at the lowest point of the box, and/or add a drip flap above the cable gland exit.
- **Cable entry:** use a rubber cable gland for the power cable, loop the cable below the gland before it enters (drip loop).
- **Desiccant:** toss in a small silica pack; check it at season changes.
- Mount under an eave when possible. Hardware details and printable designs: see [EXTRAS.md](EXTRAS.md).

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| No mic in `arecord -l` | I2S not enabled in config.txt, or overlay name wrong for your OS version |
| Recording but silence | L/R pin floating (tie to GND), or SD/WS swapped |
| Constant static/noise | Wires too long, or 5 V on VDD (mic may be damaged — 3.3 V only) |
| Web UI unreachable | `sudo systemctl status birdnet_pi` ; check WiFi country code was set |
| Installer fails on Bookworm | BirdNET-Pi is Bullseye-era; flash the 64-bit **Bullseye Lite** image instead |
