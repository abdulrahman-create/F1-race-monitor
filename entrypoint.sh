#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# F1 Race Replay - container entrypoint
#
# Starts the headless display stack (Xvfb + x11vnc + noVNC) so the Arcade/Qt
# GUI can render, then launches the requested command (default: the Qt GUI).
#
# Access the GUI in your browser at http://localhost:6080/vnc.html
# ---------------------------------------------------------------------------
set -e

: "${DISPLAY:=:99}"
: "${RESOLUTION:=1440x900x24}"
: "${NOVNC_PORT:=6080}"
NOVNC_DIR=/usr/share/novnc

echo "[entrypoint] Starting Xvfb on ${DISPLAY} at ${RESOLUTION}..."
Xvfb "${DISPLAY}" -screen 0 "${RESOLUTION}" -ac +extension GLX +render -noreset >/tmp/xvfb.log 2>&1 &
XVFB_PID=$!

# Small window manager so Qt/Arcade windows can map + focus correctly
echo "[entrypoint] Starting openbox..."
openbox-session >/tmp/openbox.log 2>&1 &
OPENBOX_PID=$!

# Wait for the display to be ready
for i in $(seq 1 30); do
  if xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1; then
    echo "[entrypoint] Display ${DISPLAY} is ready."
    break
  fi
  sleep 0.5
done

# Monitor: x11vnc exports the X display over VNC
echo "[entrypoint] Starting x11vnc on :5900..."
x11vnc -display "${DISPLAY}" -forever -shared -nopw -quiet -rfbport 5900 >/tmp/x11vnc.log 2>&1 &
VNC_PID=$!

# Browser: noVNC proxies websocket:6080 -> vnc:5900
if [ -d "${NOVNC_DIR}" ]; then
  echo "[entrypoint] Starting noVNC on :${NOVNC_PORT}..."
  websockify --web="${NOVNC_DIR}" "${NOVNC_PORT}" localhost:5900 >/tmp/novnc.log 2>&1 &
  NOVNC_PID=$!
else
  echo "[entrypoint] WARNING: noVNC dir '${NOVNC_DIR}' not found - browser GUI unavailable."
  NOVNC_PID=
fi

# Wait a moment so proxies are up before launching the app
sleep 2

cleanup() {
  echo "[entrypoint] Shutting down display stack..."
  [ -n "${NOVNC_PID}" ] && kill "${NOVNC_PID}" 2>/dev/null || true
  kill "${VNC_PID}" 2>/dev/null || true
  kill "${OPENBOX_PID}" 2>/dev/null || true
  kill "${XVFB_PID}" 2>/dev/null || true
  exit 0
}
trap cleanup SIGTERM SIGINT EXIT

# ---------------------------------------------------------------------------
echo "[entrypoint] Launching: $*"
echo "             GUI available at http://localhost:${NOVNC_PORT}/vnc.html"
exec "$@"