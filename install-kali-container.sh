#!/usr/bin/env bash
set -euo pipefail

# Kali Container Installer for Raspberry Pi OS (Host)
# Creates a persistent Kali rolling container with proper capabilities for tools like nmap.
#
# Usage:
#   chmod +x install-kali-container.sh
#   ./install-kali-container.sh
#
# Afterward (recommended):
#   sudo reboot
#   kali
#   kali-tools

if [[ "${EUID}" -eq 0 ]]; then
  echo "Please run as your normal user (not root). This script will use sudo as needed."
  exit 1
fi

KALI_IMAGE="${KALI_IMAGE:-kalilinux/kali-rolling}"
KALI_NAME="${KALI_CONTAINER_NAME:-kali-rolling}"

echo "[*] Installing prerequisites..."
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release

echo "[*] Installing Docker if missing..."
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sudo sh
else
  echo "    Docker already installed."
fi

echo "[*] Enabling Docker service..."
sudo systemctl enable --now docker

echo "[*] Adding user '$USER' to docker group..."
sudo usermod -aG docker "$USER"

echo "[*] Pulling Kali image: $KALI_IMAGE"
sudo docker pull "$KALI_IMAGE"

# If container exists but was created without required caps, easiest is recreate.
# We'll recreate if it exists (safe and predictable).
if sudo docker ps -a --format '{{.Names}}' | grep -qx "$KALI_NAME"; then
  echo "[*] Removing existing container '$KALI_NAME' (to ensure correct capabilities/config)..."
  sudo docker rm -f "$KALI_NAME" >/dev/null
fi

echo "[*] Creating persistent container '$KALI_NAME' with NET_RAW + NET_ADMIN..."
sudo docker run -d --name "$KALI_NAME" \
  --hostname kali \
  --network host \
  --cap-add NET_RAW \
  --cap-add NET_ADMIN \
  -v "$HOME:/host-home" \
  -v /tmp:/tmp \
  --restart unless-stopped \
  "$KALI_IMAGE" sleep infinity

echo "[*] Creating host launcher: /usr/local/bin/kali"
sudo tee /usr/local/bin/kali >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

KALI_IMAGE="${KALI_IMAGE:-kalilinux/kali-rolling}"
NAME="${KALI_CONTAINER_NAME:-kali-rolling}"

# Ensure container exists; if not, create it with needed caps.
if docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; then
  docker start "$NAME" >/dev/null
else
  docker run -d --name "$NAME" \
    --hostname kali \
    --network host \
    --cap-add NET_RAW \
    --cap-add NET_ADMIN \
    -v "$HOME:/host-home" \
    -v /tmp:/tmp \
    --restart unless-stopped \
    "$KALI_IMAGE" sleep infinity
fi

exec docker exec -it "$NAME" bash
EOF
sudo chmod +x /usr/local/bin/kali

echo "[*] Creating host helper: /usr/local/bin/kali-tools"
sudo tee /usr/local/bin/kali-tools >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

NAME="${KALI_CONTAINER_NAME:-kali-rolling}"

if ! docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; then
  echo "Container '$NAME' not found. Run: kali"
  exit 1
fi

# Install a sensible starter set. You can change this to kali-linux-default if you want "fuller" Kali.
docker exec -it "$NAME" bash -lc '
  set -e
  apt update
  apt install -y kali-tools-top10
  echo
  echo "Installed: kali-tools-top10"
  echo "Your host home is mounted at: /host-home"
  echo "Tip: run nmap now: nmap 127.0.0.1"
'
EOF
sudo chmod +x /usr/local/bin/kali-tools

echo "[*] Quick sanity checks..."
echo "    kali       -> $(command -v kali || true)"
echo "    kali-tools -> $(command -v kali-tools || true)"

cat <<EOF

[✓] Done.

IMPORTANT:
- Docker group changes need a new login session. Easiest: reboot.

Next steps:
  sudo reboot
  kali
  kali-tools
  kali
  nmap 127.0.0.1

Notes:
- Files from Raspberry Pi OS home are available in container at /host-home
EOF