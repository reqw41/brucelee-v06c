#!/bin/sh
# Полная сборка Bruce Lee для Вектора-06Ц: лента ZX (orig/bugfix, не в репозитории) -> эталонный образ ->
# данные -> игра build/vec/brucelee.bin -> образ с заставкой rom/BruceLee-v06c.r0m / .c00; русская — brucelee_ru.bin ->
# rom/BruceLee-v06c-ru.r0m / .c00 (tools/mkru.py).
# Нужны: Node.js, Python 3 с Pillow, tools/sjasmplus, tools/zx0/zx0 (cc -O2 -o tools/zx0/zx0 tools/zx0/*.c).
#   ./build.sh          — сборка
#   ./build.sh check    — и проверки: run80 (логика) и run80 --ship (боевой образ) на эталонах, vecroomcheck,
#                         vecwater (сдвиг воды), vecroom18 (колдун комнаты 18), vecwin (победа), vec2p (1 или 2 игрока), vecpause (ВК, АР2), veccheat (Ф1+Ф3), vecscreens (титул, меню, звук титула, игра по шагам, темп — tests/screens.json)
set -e
cd "$(dirname "$0")"
TAP="orig/bugfix/BruceLee(fixed).tap"
[ -f "$TAP" ] || { echo "нет $TAP (лента BUGFIX)"; exit 1; }
[ -x tools/zx0/zx0 ] || cc -O2 -o tools/zx0/zx0 tools/zx0/*.c
mkdir -p build/vec build/l80
[ -f build/zx_tap.bin ] || node stand/tapeload.js
[ -d build/tape/bugfix ] || python3 -I tools/tape.py "$TAP" build/tape/bugfix >/dev/null
python3 -I tools/mkroom18tiles.py
python3 -I tools/mkvecdata.py | grep колдун
python3 -I tools/mkcpcsnd.py >/dev/null
python3 -I tools/mkroom18attr.py
python3 -I tools/mkplanes.py
python3 -I tools/mkru.py
asm() { (cd "$1" && ../../tools/sjasmplus --nologo --i8080 --sym="../../$2.sym" $4 "$3") > "$2.log" 2>&1 || { cat "$2.log"; exit 1; }
        grep -E "error|^> " "$2.log" || true; ! grep -q "error:" "$2.log" || exit 1; }
asm src/i8080 build/l80/logic logic.asm
asm src/vec build/vec/brucelee main.asm
asm src/vec build/vec/brucelee_ru main.asm -DRUS			# русская версия (07.11): шрифт и тексты — tools/mkru.py
python3 -I tools/mksplash.py
python3 -I tools/mksplash.py ru
if [ "$1" = check ]; then
  ok=0
  for g in build/golden/s*.json.gz; do
    node tools/run80.js "$g" | grep "расхожд" | sed 's/^/логика:  /'
    node tools/run80.js "$g" --ship | grep "расхожд" | sed 's/^/образ:   /'
  done
  node tools/vecroomcheck.js build/vec/brucelee.bin | tail -1
  node tools/vecwater.js build/vec/brucelee.bin
  node tools/vecscreens.js build/vec/brucelee.bin
  node tools/vecsplash.js
  node tools/vectilefix.js build/vec/brucelee.bin
  node tools/vecroom18.js build/vec/brucelee.bin
  node tools/vecwin.js build/vec/brucelee.bin
  node tools/vec2p.js build/vec/brucelee.bin
  node tools/vecpause.js build/vec/brucelee.bin
  node tools/veccheat.js build/vec/brucelee.bin
fi
