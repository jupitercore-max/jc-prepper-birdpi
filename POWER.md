# Power & Duty Cycling

## Why modem-sleep duty cycle (not deep sleep) by default

The WebSocket needs to stay alive; true deep sleep kills it and forces a full reconnect (~4 s: WiFi join + TCP + WS handshake). So the default firmware duty cycle is:

- **30 s listening** — PDM capture, WiFi active, WS streaming (this is the power-hungry phase)
- **90 s "off"** — `WiFi.setSleep(true)` modem sleep, PDM off, socket kept warm with WS pings

That's a **25% duty cycle**, and detection latency of up to 2 minutes between windows — fine for ambient bird monitoring, wrong for a feeder-triggered use case.

## Runtime estimates (realistic, not datasheet numbers)

Assumptions: 3000 mAh·g cheap LiPo at its rated capacity, 3.7 V, measured currents typical for an ESP32-S3 with WiFi active:

| Phase | Current draw |
|---|---|
| WiFi on, PDM streaming | ~80–120 mA (average; TX bursts push peaks to 250+ mA) |
| Modem sleep, PDM off | ~2–5 mA |
| True deep sleep | ~10–150 µA |

**25% duty cycle (30s/90s), 500 mAh LiPo:**

Average current ≈ 0.25×100 mA + 0.75×3.5 mA ≈ **27.6 mA**
Runtime ≈ 500 / 27.6 ≈ **18 hours per charge.** Not great. This is why the default config alone isn't the battery story.

**Better: aggressive deep sleep (`BIRDPI_AGGRESSIVE_SLEEP=1`, 30 s on / 5 min off):**

Average current ≈ (30/330)×100 mA + (300/330)×0.05 mA ≈ **9.6 mA** (reconnect overhead included roughly)
Runtime ≈ 500 / 9.6 ≈ **~2 days per charge** with a 500 mAh cell.

**350 mAh (smaller 402030) + 30s/10min duty:**

Average ≈ (30/630)×100 mA ≈ **4.8 mA** → 350/4.8 ≈ **~3 days per charge.**

Rule of thumb: **expect 2–4 days per charge with a small LiPo and a ≤1-minute-per-10-minutes listening schedule.** Not months. If you need months, this isn't the right architecture — that's a LoRa + edge-ML design, not a WiFi-streaming one.

## USB power

For a yard-mounted unit near an outlet, skip the LiPo entirely — micro-USB power bank or a phone charger. Duty cycling still helps thermals (the XIAO gets warm streaming continuously) but battery math stops mattering.

## Battery monitoring

The firmware reads the BAT pad via `analogReadMilliVolts(A0)` on the XIAO's onboard divider and reports `vbat_mv` in the status ping — the iOS app can show battery level. Calibrate against your actual cell; the XIAO's divider is approximate.
