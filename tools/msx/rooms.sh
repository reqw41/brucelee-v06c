#!/bin/sh
# Снимки 20 комнат MSX-версии (orig/msx/*.rom, Comptiq 1985): openMSX без окна, машина BounderMSX1 (~/.openMSX),
# номер комнаты — E101 (+ игрок E115), подмена в точке 4237 (старт игры обнуляет E101). -> build/msx/rNN.png, VRAM/ОЗУ.
set -e
cd "$(dirname "$0")/../.."
ROM=$(ls orig/msx/*.rom | head -1); OUT=$PWD/build/msx; mkdir -p "$OUT"
for r in $(seq 0 19); do
  ROOM=$r OUT=$OUT SDL_VIDEODRIVER=dummy openmsx -machine BounderMSX1 -cart "$ROM" -command "set renderer none" \
    -command "set mute on" -script tools/msx/room.tcl >/dev/null 2>&1 &
  [ $((r % 5)) -eq 4 ] && wait
done; wait
cd "$OUT" && python3 -c "
import sys; sys.path.insert(0,'../../tools/msx')
from s2 import render
for i in range(20):
  n='r%02d'%i; render(open(n+'_vram.bin','rb').read(), open(n+'_regs.bin','rb').read()).save(n+'.png')"
echo "build/msx/r00..r19.png"
