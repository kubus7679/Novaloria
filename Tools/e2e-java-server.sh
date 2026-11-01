#!/usr/bin/env bash
#
# End-to-end validation of the Swift client against the real Java FreeCol server.
#
# Uses Docker, or a local Java checkout with LOCAL_FREECOL_DIR.
# Each probe starts an isolated server, never an existing game.
#
# Usage:
#   Tools/e2e-java-server.sh
#
# Environment:
#   FREECOL_IMAGE   Docker image (default: docker-freecol-server:latest)
#   FREECOL_PORT    Host port (default: 3541)
#   KEEP_SERVER     Set to 1 to leave the container running afterwards
#   STRICT_SKIPS    Set to 1 to treat probes that skipped (no reachable target)
#                   as failures
#   ONLY            Space-separated probe names to run (e.g. "combat recruitment")
#   LOCAL_FREECOL_DIR  Built Java checkout instead of Docker
#   JAVA_BIN        Java executable for local mode (default: java)

set -euo pipefail

IMAGE="${FREECOL_IMAGE:-docker-freecol-server:latest}"
PORT="${FREECOL_PORT:-3541}"
CONTAINER="freecol-swift-e2e"
VOLUME="freecol-swift-e2e-data"
KEEP_SERVER="${KEEP_SERVER:-0}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_FREECOL_DIR="${LOCAL_FREECOL_DIR:-}"
JAVA_BIN="${JAVA_BIN:-java}"
SERVER_PID=""
LOG_DIR="$(mktemp -d)"
if [ -n "$LOCAL_FREECOL_DIR" ]; then
  LOCAL_FREECOL_DIR="$(cd "$LOCAL_FREECOL_DIR" && pwd)"
  PORT="${FREECOL_PORT:-3559}"
  if [ "$KEEP_SERVER" = "1" ]; then
    echo "KEEP_SERVER=1 is only supported in Docker mode." >&2
    exit 1
  fi
fi

stop_local_server() {
  if [ -n "$SERVER_PID" ]; then
    if kill -0 "$SERVER_PID" 2>/dev/null; then
      kill "$SERVER_PID"
    fi
    wait "$SERVER_PID" 2>/dev/null || true
    SERVER_PID=""
  fi
}

cleanup() {
  if [ -n "$LOCAL_FREECOL_DIR" ]; then
    stop_local_server
  elif [ "$KEEP_SERVER" != "1" ]; then
    docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
    docker volume rm "$VOLUME" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [ -n "$LOCAL_FREECOL_DIR" ]; then
  if [ ! -f "$LOCAL_FREECOL_DIR/FreeCol.jar" ] || [ ! -d "$LOCAL_FREECOL_DIR/data" ]; then
    echo "LOCAL_FREECOL_DIR needs FreeCol.jar and data/." >&2
    exit 1
  fi
elif ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Docker image '$IMAGE' not found." >&2
  echo "Build it from the Java FreeCol checkout:" >&2
  echo "  docker compose -f ../freecol/docker/docker-compose.yml build" >&2
  exit 1
fi

if [ -z "$LOCAL_FREECOL_DIR" ]; then
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
fi

start_server() {
  # Server args are '|'-separated so values may contain spaces (--difficulty|Very Easy).
  # An explicit --difficulty replaces the Easy default.
  local server_args=()
  [ -n "${1:-}" ] && IFS='|' read -ra server_args <<< "$1"
  local difficulty=(--difficulty Easy)
  [[ "${1:-}" == *--difficulty* ]] && difficulty=()
  local server_log="$LOG_DIR/$name-server.log"
  if [ -n "$LOCAL_FREECOL_DIR" ]; then
    stop_local_server
    if nc -z 127.0.0.1 "$PORT" >/dev/null 2>&1; then
      echo "Port $PORT is already occupied; refusing to touch the existing server." >&2
      exit 1
    fi
    local directory="$LOG_DIR/$name-data"
    mkdir -p "$directory/config" "$directory/cache" "$directory/data"
    local index
    for index in "${!server_args[@]}"; do
      if [[ "${server_args[$index]}" == /fixtures/* ]]; then
        server_args[$index]="$ROOT/Tools/fixtures/${server_args[$index]#/fixtures/}"
      fi
    done
    cat > "$directory/options.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<clientOptions>
  <option id="model.option.languageOption" value="clientOptions.gui.languageOption.autoDetectLanguage"/>
  <option id="model.option.usePixmaps" value="true"/>
  <option id="model.option.useOpenGL" value="false"/>
  <option id="model.option.useXRender" value="false"/>
</clientOptions>
XML
    (
      cd "$LOCAL_FREECOL_DIR"
      exec "$JAVA_BIN" -Djava.awt.headless=true -Xmx2G -jar FreeCol.jar \
        --default-locale en --server --private --server-ip 127.0.0.1 --server-port "$PORT" \
        --user-config-directory "$directory/config" --user-cache-directory "$directory/cache" \
        --user-data-directory "$directory/data" --clientOptions "$directory/options.xml" \
        --log-file "$server_log" \
        ${difficulty[@]+"${difficulty[@]}"} ${server_args[@]+"${server_args[@]}"}
    ) >"$LOG_DIR/$name-console.log" 2>&1 &
    SERVER_PID=$!
  else
    docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
    docker run -d --name "$CONTAINER" -p "$PORT":3541 -v "$VOLUME":/data \
      -v "$ROOT/Tools/fixtures":/fixtures:ro \
      "$IMAGE" ${difficulty[@]+"${difficulty[@]}"} ${server_args[@]+"${server_args[@]}"} >/dev/null
  fi
  echo "==> Waiting for Java server on 127.0.0.1:$PORT"
  for _ in $(seq 1 30); do
    if [ -n "$SERVER_PID" ] && ! kill -0 "$SERVER_PID" 2>/dev/null; then
      break
    fi
    if nc -z 127.0.0.1 "$PORT" >/dev/null 2>&1; then
      sleep 2
      return 0
    fi
    sleep 1
  done
  echo "Java server did not come up; logs:" >&2
  if [ -n "$LOCAL_FREECOL_DIR" ]; then
    tail -n 40 "$LOG_DIR/$name-console.log" >&2
  else
    docker logs "$CONTAINER" >&2 || true
  fi
  exit 1
}

PASSED=()
FAILED=()
SKIPPED=()
STRICT_SKIPS="${STRICT_SKIPS:-0}"
ONLY="${ONLY:-}"
E2E_LOG_LEVEL="${E2E_LOG_LEVEL:-error}"
SEED_TRADE_ROUTE="${E2E_SEED_TRADE_ROUTE:-33333}"

# run_probe NAME TITLE "SERVER_ARGS" ENV=VALUE...
# Starts a fresh server, runs one CLI probe and classifies it as passed,
# skipped (probe printed "skipped") or failed. A failure never aborts the suite.
run_probe() {
  local name="$1" title="$2" server_args="$3"
  shift 3
  if [ -n "$ONLY" ] && [[ " $ONLY " != *" $name "* ]]; then
    return 0
  fi
  echo "==> $title"
  start_server "$server_args"
  local log="$LOG_DIR/$name.log" status=0
  (cd "$ROOT" && env FREECOL_CLI_REAL_SERVER_ONLY=1 REAL_SERVER_HOST=127.0.0.1 \
    REAL_SERVER_PORT="$PORT" FREECOL_LOG="$E2E_LOG_LEVEL" "$@" swift run FreeColProtocolCLI) >"$log" 2>&1 || status=$?
  grep -E "^\s+(PASS|FAIL)|skipped|^[0-9]+ passed" "$log" || true
  if [ "$status" -ne 0 ] || grep -q "^  FAIL" "$log"; then
    FAILED+=("$name")
    tail -n 25 "$log"
  elif grep -Eq '(^|[[:space:]])SKIP[[:space:]]|skipped:|skipped -|^[0-9]+ passed, [1-9][0-9]* skipped' "$log"; then
    SKIPPED+=("$name")
  else
    PASSED+=("$name")
  fi
}

run_probe smoke "Smoke probe (connect / login / launch transport)" "" \
  REAL_SERVER_E2E=1
run_probe deep "Deep probe (pre-game to in-game on a fresh server)" "" \
  REAL_SERVER_DEEP_E2E=1
run_probe gameplay "Gameplay probe (colony, warehouse, trade route, market, move and end turn)" "" \
  REAL_SERVER_GAMEPLAY_E2E=1 REAL_SERVER_REQUIRE_MARKET_TRADE=1 \
  REAL_SERVER_REQUIRE_COLONY_FOUNDING=1
run_probe reject "Rejection probe (illegal action produces a Java server error reply)" "" \
  REAL_SERVER_REJECT_E2E=1
run_probe traderoute "Trade Route probe (assignment, client-driven setCurrentStop, endTurn invariance)" "--seed|$SEED_TRADE_ROUTE|--europeans|2" \
  REAL_SERVER_TRADE_ROUTE_E2E=1
run_probe multiplayer "Multiplayer Turn Gating probe (2+ players, turn ownership validation)" "" \
  REAL_SERVER_MULTIPLAYER_E2E=1 REAL_SERVER_PLAYER_COUNT=2
run_probe nativetrade "Native Trade Session probe (open/buy/haggle/close against real settlement)" "--load-savegame|/fixtures/native-trade.fsg" \
  REAL_SERVER_NATIVE_TRADE_E2E=1 REAL_SERVER_USERNAME=FreeColE2ENativeTrade
run_probe abandon "Colony abandonment probe (remove empty colony and release tile)" "--load-savegame|/fixtures/abandon-e2e.fsg" \
  REAL_SERVER_USERNAME=FreeColE2ENativeTrade REAL_SERVER_ABANDON_E2E=1
run_probe disembark "Disembark probe (unload exhausted passenger in Europe)" "--load-savegame|/fixtures/scenario-e2e.fsg" \
  REAL_SERVER_USERNAME=FreeColE2ENativeTrade REAL_SERVER_DISEMBARK_E2E=1
if [ "${RUN_SAVE_E2E:-0}" = "1" ]; then
  run_probe save "Savegame export probe (requires optional save extension)" "--load-savegame|/fixtures/scenario-e2e.fsg" \
    REAL_SERVER_USERNAME=FreeColE2ENativeTrade REAL_SERVER_SAVE_E2E=1 \
    REAL_SERVER_SAVE_PATH="$LOG_DIR/exported.fsg"
  if [ -f "$LOG_DIR/exported.fsg" ]; then
    run_probe saveload "Reload exported savegame and verify gameplay" "--load-savegame|$LOG_DIR/exported.fsg" \
      REAL_SERVER_USERNAME=FreeColE2ENativeTrade REAL_SERVER_DISEMBARK_E2E=1
  fi
fi
run_probe diplomacy "Diplomacy probe (AI accepts peace and a 100-gold gift)" "--load-savegame|/fixtures/scenario-e2e.fsg" \
  REAL_SERVER_USERNAME=FreeColE2ENativeTrade REAL_SERVER_SCENARIO_FIXTURE=1 REAL_SERVER_DIPLOMACY_E2E=1
run_probe tribute "Tribute probe (AI accepts peace and pays 100 gold)" "--load-savegame|/fixtures/tribute-e2e.fsg" \
  REAL_SERVER_USERNAME=FreeColE2ENativeTrade REAL_SERVER_SCENARIO_FIXTURE=1 REAL_SERVER_TRIBUTE_E2E=1
run_probe combat "Combat probe (attack enemy unit, verify combat result)" "--load-savegame|/fixtures/scenario-e2e.fsg" \
  REAL_SERVER_USERNAME=FreeColE2ENativeTrade REAL_SERVER_SCENARIO_FIXTURE=1 REAL_SERVER_COMBAT_E2E=1
run_probe missionaryspy "Missionary & Spy probe (send missionary, spy settlement)" "--load-savegame|/fixtures/scenario-e2e.fsg" \
  REAL_SERVER_USERNAME=FreeColE2ENativeTrade REAL_SERVER_SCENARIO_FIXTURE=1 REAL_SERVER_MISSIONARY_SPY_E2E=1
run_probe recruitment "Recruitment probe (sail to Europe, recruit, emigrate, purchase)" "--difficulty|Very Easy|--seed|33333" \
  REAL_SERVER_RECRUITMENT_E2E=1

echo
echo "==> E2E summary (logs in $LOG_DIR)"
echo "    passed : ${#PASSED[@]} ${PASSED[*]:-}"
echo "    skipped: ${#SKIPPED[@]} ${SKIPPED[*]:-}"
echo "    failed : ${#FAILED[@]} ${FAILED[*]:-}"
if [ "${#FAILED[@]}" -gt 0 ]; then
  exit 1
fi
if [ "$STRICT_SKIPS" = "1" ] && [ "${#SKIPPED[@]}" -gt 0 ]; then
  echo "STRICT_SKIPS=1: skipped probes count as failures" >&2
  exit 2
fi
echo "==> E2E validation finished"
