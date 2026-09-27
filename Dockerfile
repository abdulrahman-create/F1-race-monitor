# -- F1 Race Replay - Docker image ------------------------------------------
# Runs the interactive GUI (Arcade/OpenGL + PySide6) inside a headless
# container using a virtual display (Xvfb) + x11vnc + noVNC, accessible in
# your browser at http://localhost:6080
#
# Build:     docker build -t f1-race-replay .
# Run:       see docker-compose.yml  (or the docs/DOCKER.md run commands)

FROM python:3.11-slim-bookworm

# Avoid interactive prompts and keep Python non-buffered
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    DISPLAY=:99 \
    RESOLUTION=1440x900x24 \
    NOVNC_PORT=6080 \
    TZ=UTC

# ---------------------------------------------------------------------------
# System dependencies:
#   - xvfb/x11vnc/novnc  -> virtual display + remote access
#   - openbox             -> lightweight window manager (needed by arcade/qt)
#   - mesa-utils/libgl1   -> software OpenGL (llvmpipe) so arcade renders
#   - libgles2/libglu1    -> GLES/GLU backends used by pyglet/arcade
#   - im-config/fonts     -> sensible fonts for the Qt UI
#   - curl                -> noVNC self-resolution at entrypoint
#   - libxkbcommon etc.   -> Qt X11 runtime deps
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        xvfb \
        x11vnc \
        novnc \
        websockify \
        openbox \
        x11-utils \
        libgl1 \
        libglu1-mesa \
        libgles2 \
        mesa-utils \
        libxkbcommon-x11-0 \
        libxcb-icccm4 \
        libxcb-image0 \
        libxcb-keysyms1 \
        libxcb-randr0 \
        libxcb-render-util0 \
        libxcb-shape0 \
        libxcb-xinerama0 \
        libxcb-xkb1 \
        libxcb-cursor0 \
        libxcb-util1 \
        libxkbcommon0 \
        libegl1 \
        libglib2.0-0 \
        libdbus-1-3 \
        libfontconfig1 \
        libfreetype6 \
        fonts-dejavu-core \
        curl \
        xauth \
        x11-xkb-utils \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user to run the GUI
RUN useradd --create-home --shell /bin/bash replay

WORKDIR /app

# ---------------------------------------------------------------------------
# Python dependencies (layer cached separately from app code)
# ---------------------------------------------------------------------------
COPY requirements.txt requirements.txt
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# ---------------------------------------------------------------------------
# Application code
# ---------------------------------------------------------------------------
COPY . .

# FastF1 + computed data live here by default (see src/lib/settings.py)
# Owned by the `replay` user so Docker named volumes mounted at these paths
# inherit `replay` ownership (otherwise the non-root user can't write them).
RUN mkdir -p /app/.fastf1-cache /app/computed_data \
    && chown -R replay:replay /app/.fastf1-cache /app/computed_data

# Entrypoint starts the display stack then runs the requested command
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# noVNC ships no index.html, so a reverse proxy routing "/" to the container
# returns 404 at the root. Add a tiny redirect so "/" lands on vnc.html.
RUN printf '%s\n' \
    '<!DOCTYPE html>' \
    '<html><head><meta charset="utf-8">' \
    '<meta http-equiv="refresh" content="0; url=vnc.html">' \
    '<title>F1 Race Replay</title></head>' \
    '<body><a href="vnc.html">Open F1 Race Replay</a></body></html>' \
    > /usr/share/novnc/index.html

# Browser GUI (noVNC), telemetry TCP stream, VNC (optional)
EXPOSE 6080 9999 5900

USER replay

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# Default: launch the Qt session-selection GUI
CMD ["python", "main.py"]