# Running F1 Race Replay with Docker 🏎️

The project is a **graphical** application (Arcade/OpenGL + PySide6 Qt). To run it
inside a container, the image provides a virtual display (`Xvfb`) and serves it to
your browser over **noVNC**. You get the full GUI frontend without needing Docker
Desktop's X11/GPU passthrough.

## Prerequisites

- **Docker** installed (Docker Desktop on Windows).
- A network connection: the app downloads live F1 telemetry from FastF1 on first run.

## Quick start (GUI in the browser)

```bash
# 1. Build the image
docker compose build

# 2. Start the app
docker compose up -d

# 3. Open the GUI in your browser
#    http://localhost:6080/vnc.html
#    (click "Connect" — no password is required)
```

The Qt **session-selection** window appears. Pick a year/round and enjoy the replay.

First load of a session downloads telemetry, so it may take a while. Subsequent
loads use the cached data (persisted in a Docker volume, see below).

## Alternative run modes

`docker compose run` runs a one-off container (builds first if needed). Examples:

```bash
# Text-based CLI session loader
docker compose run --rm replay python main.py --cli

# List the rounds available for a season
docker compose run --rm replay python main.py --list-rounds --year 2024

# Directly run a specific race replay (no GUI selection)
docker compose run --rm replay python main.py --viewer --year 2024 --round 12

# Sprint / Qualifying
docker compose run --rm replay python main.py --viewer --year 2024 --round 12 --sprint
docker compose run --rm replay python main.py --viewer --year 2024 --round 12 --qualifying
```

> For a raw VNC client (TigerVNC, RealVNC) use port `5900` instead of noVNC.

## Ports

| Port | Purpose                              |
|------|--------------------------------------|
| 6080 | noVNC **browser GUI** (`/vnc.html`)  |
| 5900 | Raw VNC (optional)                   |
| 9999 | Telemetry TCP stream (from replay)   |

## Persistent storage

The container pins down its FastF1 cache and computed data with Docker volumes so
you don't re-download telemetry every restart:

| Volume            | Container path       |
|-------------------|----------------------|
| `fastf1_cache`    | `/app/.fastf1-cache` |
| `computed_data`   | `/app/computed_data` |

To reuse an existing local cache instead of downloading afresh, uncomment the
read-only bind mount in `docker-compose.yml` and point it at your host cache:

```yaml
# - ./local_fastf1_cache:/app/.fastf1-cache:ro
```

## Notes & troubleshooting

- **OpenGL** is provided via Mesa **software** rendering (`llvmpipe`) — no GPU
  needed. For large/long sessions the replay is CPU-rendered, which is fine for
  normal use.
- **GUI subprocesses:** the Insights Menu / telemetry viewer are launched as
  separate processes inside the same container and reuse the same display, so they
  appear in noVNC too.
- **Cache flag:** if you previously ran the app and have older telemetry, re-run
  with `--refresh-data` to regenerate Safety Car data (see `README.md`).
- **Stop everything:** `docker compose down` (add `-v` to also delete volumes).

## Files

- `Dockerfile` — image build (virtual display + Mesa + Python deps + app).
- `docker-compose.yml` — ports, volumes, run modes.
- `entrypoint.sh` — starts Xvfb/openbox/x11vnc/noVNC then the app.
- `.dockerignore` — keeps secrets/caches/docs/images out of the build context.