#!/usr/bin/env bash
set -euo pipefail

PY_PATH="/usr/local/bin/status-led.py"
SERVICE_PATH="/etc/systemd/system/status-led.service"

echo "==> Prüfe: läuft als root?"
if [[ "${EUID}" -ne 0 ]]; then
  echo "Bitte mit sudo ausführen: sudo $0"
  exit 1
fi

echo "==> Pakete installieren (python3-libgpiod)..."
apt update
apt install -y python3-libgpiod

echo "==> Python LED Controller schreiben: ${PY_PATH}"
cat > "${PY_PATH}" <<'PYEOF'
#!/usr/bin/env python3
import math
import signal
import subprocess
import time

import gpiod
from gpiod.line import Direction, Value

CHIP = "/dev/gpiochip0"
LINE = 17  # GPIO17 = physischer Pin 11

stopping = False

def handle_signal(signum, frame):
    global stopping
    stopping = True

signal.signal(signal.SIGTERM, handle_signal)
signal.signal(signal.SIGINT, handle_signal)

def pwm(req, duty: float, period: float = 0.02):
    """Software-PWM: duty 0..1, period in Sekunden."""
    duty = max(0.0, min(1.0, duty))
    on_time = period * duty
    off_time = period - on_time

    if on_time > 0:
        req.set_value(LINE, Value.ACTIVE)
        time.sleep(on_time)
    if off_time > 0:
        req.set_value(LINE, Value.INACTIVE)
        time.sleep(off_time)

def breathe_until_running(req):
    """Atmen bis systemd 'running' ist (oder bis SIGTERM kommt)."""
    last_check = 0.0
    t0 = time.monotonic()

    while not stopping:
        now = time.monotonic()
        if now - last_check > 0.5:
            last_check = now
            r = subprocess.run(
                ["systemctl", "is-system-running"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            if r.returncode == 0:  # "running"
                return

        # Atmen mit Sinus (Periodendauer ~2.5s)
        x = (now - t0) * (2.0 * math.pi / 2.5)
        duty = 0.05 + 0.95 * ((math.sin(x) + 1.0) / 2.0)  # 0.05..1.0
        pwm(req, duty, period=0.02)

def steady_on(req):
    req.set_value(LINE, Value.ACTIVE)

def blink(req, seconds=10.0, hz=4.0):
    half = 0.5 / hz
    end = time.monotonic() + seconds
    state = False
    while time.monotonic() < end:
        state = not state
        req.set_value(LINE, Value.ACTIVE if state else Value.INACTIVE)
        time.sleep(half)

def main():
    settings = gpiod.LineSettings(
        direction=Direction.OUTPUT,
        output_value=Value.INACTIVE,
    )
    req = gpiod.request_lines(
        CHIP,
        consumer="status-led",
        config={LINE: settings},
    )

    try:
        # 1) Boot: atmen bis running
        breathe_until_running(req)

        if stopping:
            blink(req, seconds=3.0, hz=4.0)
            req.set_value(LINE, Value.INACTIVE)
            return

        # 2) Laufzeit: dauerhaft an
        steady_on(req)

        # 3) Warten bis Shutdown
        while not stopping:
            time.sleep(0.2)

        # 4) Shutdown: blinken
        blink(req, seconds=10.0, hz=4.0)
        req.set_value(LINE, Value.INACTIVE)

    finally:
        try:
            req.release()
        except Exception:
            pass

if __name__ == "__main__":
    main()
PYEOF

chmod +x "${PY_PATH}"

echo "==> systemd Service schreiben: ${SERVICE_PATH}"
cat > "${SERVICE_PATH}" <<'SVCEOF'
[Unit]
Description=GPIO Status LED (breathe on boot, steady when running, blink on shutdown)
After=local-fs.target
Before=multi-user.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/status-led.py
Restart=no
KillSignal=SIGTERM
TimeoutStopSec=15

[Install]
WantedBy=multi-user.target
SVCEOF

echo "==> systemd neu laden, Service aktivieren & starten..."
systemctl daemon-reload
systemctl enable status-led.service
systemctl restart status-led.service

echo
echo "✅ Fertig!"
echo "   Status: systemctl status status-led.service --no-pager"
echo "   Logs:   journalctl -u status-led.service -e --no-pager"
echo
echo "Hinweis: Beim nächsten Neustart solltest du das 'Atmen' während des Bootens sehen."