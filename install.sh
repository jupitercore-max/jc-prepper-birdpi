#!/usr/bin/env bash
# =============================================================================
# jc-prepper-birdpi install.sh
# One-script setup for a BirdNET-Pi bird-song ID station on Raspberry Pi.
# Assumes: FRESH Raspberry Pi OS Lite (64-bit), booted, networked, you are root
# or have sudo. Run as:  bash install.sh
# Idempotent-ish: safe to re-run; each step checks before acting.
# =============================================================================
set -euo pipefail

STATION_NAME_TEMPLATE="birdpi"        # base name; BirdNET-Pi appends if needed
CONF_FILE="config/birdnet-pi-defaults.conf"
BIRDNET_PI_REPO="https://github.com/mcguirepr89/BirdNET-Pi.git"

log()  { echo -e "\033[1;32m[birdpi]\033[0m $*"; }
warn() { echo -e "\033[1;33m[birdpi]\033[0m $*" >&2; }
die()  { echo -e "\033[1;31m[birdpi] FATAL:\033[0m $*" >&2; exit 1; }

# ---------------------------------------------------------------- guard rails
[[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run as root (or with sudo): sudo bash $0"

ARCH="$(uname -m)"
[[ "$ARCH" == "aarch64" ]] || die "This installer requires a 64-bit OS (aarch64). You are on '$ARCH'.
Flash Raspberry Pi OS Lite 64-bit: https://www.raspberrypi.com/software/"

if grep -qi 'raspbian\|raspberry pi os\|debian' /etc/os-release 2>/dev/null; then
  # shellcheck source=/dev/null
  . /etc/os-release
  log "Detected ${PRETTY_NAME:-Debian-ish}"
else
  die "This does not look like Raspberry Pi OS / Debian. Aborting."
fi

if [[ "$(awk '/^ Revision|^Model/ {print $0}' /proc/cpuinfo 2>/dev/null | grep -c .)" -eq 0 ]] \
   && ! grep -q 'Raspberry Pi' /proc/device-tree/model 2>/dev/null; then
  warn "Could not confirm this is a Raspberry Pi. Continuing anyway (any aarch64 SBC may work)."
fi
grep -q 'Raspberry Pi' /proc/device-tree/model 2>/dev/null \
  && log "Board: $(tr -d '\0' < /proc/device-tree/model)"

# ---------------------------------------------------------------- apt deps
log "Installing base dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq \
  git curl wget jq python3 python3-pip python3-venv \
  alsa-utils sox libsox-fmt-all flac \
  sqlite3 nginx-light jq > /dev/null

# ---------------------------------------------------------------- swap (512MB RAM board)
if ! swapon --show=NAME,SIZE | grep -q '/swapfile'; then
  log "Adding 1GB swap (Zero 2 W has 512MB RAM)..."
  fallocate -l 1G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile >/dev/null
  swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
else
  log "Swap already present, skipping."
fi

# ---------------------------------------------------------------- I2S mic (config.txt)
# Newer Raspberry Pi OS keeps boot config at /boot/firmware/config.txt.
CFG="/boot/config.txt"
[[ -f /boot/firmware/config.txt ]] && CFG="/boot/firmware/config.txt"
if ! grep -q '^dtparam=i2s=on' "$CFG"; then
  log "Enabling I2S in $CFG ..."
  {
    echo ""
    echo "# --- jc-prepper-birdpi: I2S MEMS mic ---"
    echo "dtparam=i2s=on"
    echo "dtoverlay=i2s-mic"
  } >> "$CFG"
else
  log "I2S already enabled, skipping."
fi

# ---------------------------------------------------------------- clone/install BirdNET-Pi
if [[ -d /home/pi/BirdNET-Pi || -d "${SUDO_USER_HOME:-/root}/BirdNET-Pi" ]]; then
  log "BirdNET-Pi directory already present, skipping clone."
else
  log "Cloning BirdNET-Pi..."
  TARGET="${SUDO_USER_HOME:-/root}"
  git clone --depth 1 "$BIRDNET_PI_REPO" "$TARGET/BirdNET-Pi"
fi

BIRDNET_DIR="${SUDO_USER_HOME:-/root}/BirdNET-Pi"
[[ -d "$BIRDNET_DIR" ]] || BIRDNET_DIR="/home/pi/BirdNET-Pi"
[[ -d "$BIRDNET_DIR" ]] || die "BirdNET-Pi clone missing at expected path."

# ---------------------------------------------------------------- non-interactive install
# BirdNET-Pi's installer is interactive; we pre-seed its answers via environment
# variables its newInstaller script reads. Keys we set:
#   PIEPWELL  = web UI password seed (random, print once at end)
#   REC       = 24/7 recording ON
#   DT_CON    = confidence threshold 0.7 (documented in our defaults file)
#   Full disk / cache cleanup daily
if [[ -f "$BIRDNET_DIR/newInstaller.sh" ]]; then
  log "Running BirdNET-Pi installer non-interactively..."
  INSTALLER="$(find "$BIRDNET_DIR" -maxdepth 1 \( -name newInstaller.sh -o -name install.sh \) 2>/dev/null | head -1)"
  # Pre-seed a random UI password; printed once at the end.
  UI_PW="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16 || true)"
  cat > /etc/birdpi-install-env <<EOF
# Pre-seeded answers for BirdNET-Pi non-interactive install (jc-prepper-birdpi)
export PIEPWELL="${UI_PW}"
export STATION_ID="${STATION_NAME_TEMPLATE}"
EOF
  bash "$INSTALLER" < /dev/null || warn "BirdNET-Pi installer returned nonzero — check output above."
else
  die "BirdNET-Pi installer script not found in $BIRDNET_DIR — repo layout changed? File an issue."
fi

# ---------------------------------------------------------------- apply our defaults
log "Applying pre-tuned defaults from $CONF_FILE ..."
if [[ -f "$(dirname "$0")/$CONF_FILE" ]]; then
  SRC="$(dirname "$0")/$CONF_FILE"
else
  SRC="$CONF_FILE"  # allow running from repo root
fi
[[ -f "$SRC" ]] || die "Defaults file not found: $SRC"

# BirdNET-Pi keeps main config at /etc/birdnet/birdnet.conf
mkdir -p /etc/birdnet
CONF="/etc/birdnet/birdnet.conf"
if [[ -f "$CONF" ]]; then
  cp "$CONF" "$CONF.bak.$(date +%s)"
  while IFS='=' read -r key val; do
    [[ -z "$key" || "$key" =~ ^# ]] && continue
    if grep -qE "^${key}=" "$CONF"; then
      sed -i "s|^${key}=.*|${key}=${val}|" "$CONF"
    else
      echo "${key}=${val}" >> "$CONF"
    fi
  done < "$SRC"
  log "Defaults applied (backup saved alongside)."
else
  cp "$SRC" "$CONF"
  warn "No existing birdnet.conf found — copied defaults to $CONF as a base."
fi

# ---------------------------------------------------------------- disable HTTPS for LAN use
# BirdNET-Pi's nginx config redirects to HTTPS; for LAN-only use we keep plain HTTP.
if [[ -f /etc/nginx/sites-enabled/default ]]; then
  if grep -q 'return 301 https' /etc/nginx/sites-enabled/default; then
    log "Disabling HTTPS redirect for LAN use..."
    sed -i '/return 301 https/d' /etc/nginx/sites-enabled/default
    nginx -t 2>/dev/null && systemctl reload nginx || true
  else
    log "No HTTPS redirect found, skipping."
  fi
fi

# ---------------------------------------------------------------- done
log "Setup complete. Rebooting in 10 seconds (Ctrl+C to abort)..."
echo ""
echo "  -------------------------------------------"
echo "  Station name : ${STATION_NAME_TEMPLATE}"
echo "  Web UI       : http://${STATION_NAME_TEMPLATE}.local  (or http://<pi-ip>)"
echo "  Web password : ${UI_PW:-<see /etc/birdpi-install-env>}"
echo "  Config       : /etc/birdnet/birdnet.conf"
echo "  -------------------------------------------"
echo ""
sleep 10
reboot
