# Enclosure — Hot Glue & Conformal Potting (no 3D printer)

The XIAO ESP32-S3 Sense stack (board + mic mezzanine) is tiny. Weatherproofing it doesn't need a printed case.

## Option A: Hot glue blob (cheapest, ~$0)

1. Flash and **test the full pipeline first** — potting makes rework painful.
2. Solder battery (if used) to the BAT pads; hot-glue the battery to the back of the board stack.
3. On a sheet of parchment paper, lay down a puddle of hot glue slightly larger than the board.
4. Press the board stack into the puddle **mic-side up** (never bury the mic port — that muffles everything).
5. Once cooled, flood-cover everything *except* a small ring around the mic and the USB-C port with more glue. 3–4 mm thickness minimum for rain.
6. Add a loop of glue as a hanging tab before the last layer cools.

Pros: free, 10 minutes. Cons: ugly, glue shrinks slightly (small gaps after months outdoors), not UV-stable — yellowing is cosmetic, cracking is not. Re-coat yearly.

## Option B: Conformal coating / potting compound (~$3)

- **Acrylic conformal spray** (e.g. MG Chemicals 419D): spray the populated PCB bottom + components, leave the mic and connector exposed. Light rain protection only — needs a housing for real weather.
- **Epoxy potting** (e.g. MG Chemicals 832): best durability. Pot the board in a small plastic puck or bottle-cap mold, mic opening shielded with a removable pin/tape, removed after cure. Fully waterproof, ~24 h cure. USB-C port must stay accessible or accept that re-flashing requires digging it out — **use OTA updates or finalize firmware before potting.**

## Practical notes

- Whatever the coating, **keep the PDM mic port open** and facing down/sideways (rain-shielded) — pointing up collects water. A tiny overhang or a dab of silicone around the mic edge deflects drips without sealing it.
- Battery + electronics together in one potting blob makes thermal expansion cracks more likely in temperature swings; pot the board, strap the battery separately with a zip tie and give it its own dab of silicone.
- If you need real maintenance access, don't pot — a $2 zip-lock container + zip tie beats both options for changeability, at the cost of some class.
