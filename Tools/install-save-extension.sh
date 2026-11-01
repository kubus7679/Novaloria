#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERVER="${1:?Usage: bash Tools/install-save-extension.sh /path/to/freecol}"
JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home}"
if [ ! -f "$SERVER/FreeCol.jar" ]; then
  echo "Missing FreeCol.jar in $SERVER" >&2
  exit 1
fi
TEMPORARY="$(mktemp -d)"
trap 'rm -f "$TEMPORARY/net/sf/freecol/common/networking/SaveGameMessage.class"; rmdir "$TEMPORARY/net/sf/freecol/common/networking" "$TEMPORARY/net/sf/freecol/common" "$TEMPORARY/net/sf/freecol" "$TEMPORARY/net/sf" "$TEMPORARY/net" "$TEMPORARY" 2>/dev/null || true' EXIT
"$JAVA_HOME/bin/javac" --release 11 -cp "$SERVER/FreeCol.jar" -d "$TEMPORARY" \
  "$ROOT/Tools/server/SaveGameMessage.java"
"$JAVA_HOME/bin/jar" --update --file "$SERVER/FreeCol.jar" -C "$TEMPORARY" \
  net/sf/freecol/common/networking/SaveGameMessage.class
echo "Save extension installed. Save your running game before restarting the Java server."
