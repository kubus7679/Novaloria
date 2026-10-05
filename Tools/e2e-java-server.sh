#!/usr/bin/env bash
#
# End-to-end validation of the Swift client against the real Java FreeCol server.
#
# Requires Docker. Uses a dedicated container + volume so it never touches an
# existing FreeCol server instance.
#
# Usage:
#   Tools/e2e-java-server.sh
#
# Environment:
#   FREECOL_IMAGE   Docker image (default: docker-freecol-server:latest)
#   FREECOL_PORT    Host port (default: 3541)
#   KEEP_SERVER     Set to 1 to leave the container running afterwards

set -euo pipefail

IMAGE="${FREECOL_IMAGE:-docker-freecol-server:latest}"
PORT="${FREECOL_PORT:-3541}"
CONTAINER="freecol-swift-e2e"
VOLUME="freecol-swift-e2e-data"
KEEP_SERVER="${KEEP_SERVER:-0}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cleanup() {
  if [ "$KEEP_SERVER" != "1" ]; then
    docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
    docker volume rm "$VOLUME" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Docker image '$IMAGE' not found." >&2
  echo "Build it from the Java FreeCol checkout:" >&2
  echo "  docker compose -f ../freecol/docker/docker-compose.yml build" >&2
  exit 1
fi

echo "==> Preparing volume $VOLUME"
docker volume create "$VOLUME" >/dev/null
# The headless server aborts if the client options file is missing.
docker run --rm -i -v "$VOLUME":/data --entrypoint sh "$IMAGE" -c '
  mkdir -p /data/config/freecol/freecol
  if [ ! -f /data/config/freecol/freecol/options.xml ]; then
    cat > /data/config/freecol/freecol/options.xml
  fi
  chown -R freecol:freecol /data/config
' <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<clientOptions>
  <option id="model.option.languageOption" value="clientOptions.gui.languageOption.autoDetectLanguage"/>
  <option id="model.option.usePixmaps" value="true"/>
  <option id="model.option.useOpenGL" value="false"/>
  <option id="model.option.useXRender" value="false"/>
</clientOptions>
XML

start_server() {
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  docker run -d --name "$CONTAINER" -p "$PORT":3541 -v "$VOLUME":/data \
    "$IMAGE" --difficulty Easy >/dev/null
  echo "==> Waiting for Java server on 127.0.0.1:$PORT"
  for _ in $(seq 1 30); do
    if nc -z 127.0.0.1 "$PORT" >/dev/null 2>&1; then
      sleep 2
      return 0
    fi
    sleep 1
  done
  echo "Java server did not come up; logs:" >&2
  docker logs "$CONTAINER" >&2 || true
  exit 1
}

echo "==> Smoke probe (connect / login / launch transport)"
start_server
(cd "$ROOT" && FREECOL_CLI_REAL_SERVER_ONLY=1 REAL_SERVER_E2E=1 \
  REAL_SERVER_HOST=127.0.0.1 REAL_SERVER_PORT="$PORT" \
  swift run FreeColProtocolCLI)

echo "==> Deep probe (pre-game to in-game on a fresh server)"
start_server
(cd "$ROOT" && FREECOL_CLI_REAL_SERVER_ONLY=1 REAL_SERVER_DEEP_E2E=1 \
  REAL_SERVER_HOST=127.0.0.1 REAL_SERVER_PORT="$PORT" \
  swift run FreeColProtocolCLI)

echo "==> Gameplay probe (market trade, colony founding when available, move and end turn)"
start_server
(cd "$ROOT" && FREECOL_CLI_REAL_SERVER_ONLY=1 REAL_SERVER_GAMEPLAY_E2E=1 \
  REAL_SERVER_REQUIRE_MARKET_TRADE=1 \
  REAL_SERVER_HOST=127.0.0.1 REAL_SERVER_PORT="$PORT" \
  swift run FreeColProtocolCLI)

echo "==> E2E validation finished"
