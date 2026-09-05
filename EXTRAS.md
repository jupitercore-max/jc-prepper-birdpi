# EXTRAS.md — Optional upgrades

## 1. BirdWeather.com integration (free for BirdNET-Pi boxes)

The original BirdNET-Pi has built-in support for streaming its detections to [birdweather.com](https://www.birdweather.com/), and BirdWeather accepts BirdNET-Pi stations without charge — you request a station ID via their app/site and enable the integration in BirdNET-Pi's Tools → Settings. Community stations powered by BirdNET-Pi have been part of the BirdWeather map since 2022 (see the BirdNET-Pi GitHub Discussion #82 where the integration launched).

- Enable it in the BirdNET-Pi web UI (Tools → Settings → BirdWeather integration) and enter your station ID/token.
- Note this sends your detections **and approximate location** to the public cloud — the whole point of this project is local-first, so treat it as an opt-in, not a default. Our installer leaves it OFF.

## 2. Solar power sizing

Pi Zero 2 W + mic draws roughly **1.5–3 W** average (zero-load ~1 W, spikes ~2.5 W during detection; see CNX Software's measurements). 24/7 budget:

- Daily energy: ~3 W × 24 h = **~72 Wh/day** (be generous: plan 100 Wh)
- Solar panel: **20 W** panel covers winter/cloudy days in most temperate climates (10 W is marginal).
- Battery: **2× 18650 (≈6000 mAh @ 3.7 V ≈ 22 Wh)** minimum for one dark day; a **12 V 7 Ah SLA (84 Wh)** or a 20 W panel + 10 Ah LiFePO₄ pack is the set-and-forget option.
- Charge controllers: any small TP4056-based solar LiIon board works for 18650 builds; use a real PWM controller for SLA/LiFePO₄.
- Wire for the weather: UV-rated cable, gland entries, battery inside the enclosure (but away from the Pi — batteries hate heat).

## 3. GPS (optional upgrade path — not in default install)

The PUC has onboard GPS for geotagging detections. For a fixed backyard station you don't need it; the Pi knows where it is because you put it there. If you want GPS (e.g. portable/roving deployments):

- Cheap UART GPS modules (u-blox NEO-6M ~$12, NEO-M8N ~$25) wire to the Pi's UART (GPIO14/15) and speak NMEA over serial.
- Enable with `enable_uart=1` in config.txt + read with `gpsd`/`gpspipe`.
- **We have NOT wired or tested this path** — it's listed as an upgrade, not a feature. Combining GPS coords with BirdNET-Pi detections would require a small script of your own.

## 4. 3D-printable enclosures

Weatherproofing options beyond the generic IP65 junction box in the BOM:

- **Junction box route (recommended, cheapest):** any IP65 ABS/polycarbonate junction box ~120×80×55 mm. Drill a downward-facing sound hole + weep hole + cable gland. ~$10.
- **Printable options:** search Printables and Thingiverse for "Raspberry Pi Zero weatherproof enclosure" or "birdhouse Pi camera" — several designs (e.g. Pi Zero weatherproof boxes, birdhouse-style hides) work with minor modification for a mic port instead of a camera lens. We don't endorse one specific STL; print in PETG or ASA (PLA sags in summer sun), orient the sound port down, and add a drip lip.
- **Acoustic note:** a small external tube/port facing the mic improves pickup vs a mic flush against plastic. Even a 20 mm section of 10 mm ID tube helps.

## 5. USB mic alternative

If I2S wiring isn't for you: a $6 USB sound-card dongle + any USB lavalier mic works with BirdNET-Pi with zero config.txt changes. Slightly worse high-frequency response than a MEMS I2S mic, but far simpler. Recommended if this is a gift or a kid/club project.

## 6. Pi 4/5 upgrade

Same install.sh, same mic wiring, better latency and headroom for more species/other services. The BOM cost roughly doubles; everything else is identical.
