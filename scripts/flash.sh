#!/usr/bin/env bash
# BirdPi flash helper — builds + uploads firmware/birdpi_xiao.ino via arduino-cli.
# Requires: arduino-cli with the esp32 core installed (see BUILD.md).
set -euo pipefail

SKETCH_DIR="$(cd "$(dirname "$0")/../firmware" && pwd)"
FQBN="esp32:esp32:xiao_esp32s3"

if ! command -v arduino-cli >/dev/null 2>&1; then
  echo "arduino-cli not found — install: brew install arduino-cli" >&2
  exit 1
fi

arduino-cli compile --fqbn "$FQBN" "$SKETCH_DIR"
echo "Compile OK. Pick a port:"
arduino-cli board list
read -r -p "Port (e.g. /dev/cu.usbmodem* or /dev/ttyUSB0): " PORT
arduino-cli upload --fqbn "$FQBN" --port "$PORT" "$SKETCH_DIR"
echo "Flashed. Open serial monitor:"
echo "  arduino-cli monitor --port $PORT --config 115200"
