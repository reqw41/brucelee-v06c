#!/bin/sh
# Запуск Bruce Lee в Emu80 (окно): rom/BruceLee-v06c.r0m на платформе vector, порт MCP 19788.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP=~/projects/emu80v4/Emu80qt-mcp.app/Contents/MacOS
TMP="${TMPDIR:-/tmp}/brucelee_emu80"; mkdir -p "$TMP"
pkill -f "Emu80qt-mcp.*brucelee" 2>/dev/null || true
cp "$ROOT/rom/BruceLee-v06c.r0m" "$TMP/brucelee.r0m"
cd "$APP"
QT_PLUGIN_PATH=/opt/homebrew/share/qt/plugins EMU80_MCP_PORT=19788 nohup ./Emu80qt-mcp --platform vector --run "$TMP/brucelee.r0m" >"$TMP/emu80.log" 2>&1 &
echo "Emu80 запущен: vector brucelee.r0m (MCP порт 19788)"
