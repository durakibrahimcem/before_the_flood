#!/usr/bin/env bash
# Builds the files to upload: tools/release.sh [OUT_DIR]
# Exports into a temporary folder first, so OUT_DIR always holds a whole release.
set -eu
repo=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
out=$(realpath -m "${1:-$repo/build/release}")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/web" "$work/windows" "$out"

timeout 300 "$repo/tools/g" --headless --path "$repo/game" --export-release Web "$work/web/index.html" > "$work/web.log" 2>&1
timeout 300 "$repo/tools/g" --headless --path "$repo/game" --export-release Windows "$work/windows/BeforeTheFlood.exe" > "$work/windows.log" 2>&1

# A broken pipe truncated one export, and a short pck still looks like a build.
[ "$(stat -c %s "$work/web/index.pck")" -gt 10000000 ] || { echo "The Web pck is too small."; exit 1; }
[ -f "$work/web/index.wasm" ] || { echo "The Web export is incomplete."; exit 1; }
[ -f "$work/windows/libeffekseer.x86_64.dll" ] || { echo "The Windows build is missing its DLL."; exit 1; }

cat > "$work/windows/OKU-README.txt" <<'EOF'
Before the Flood

Türkçe
BeforeTheFlood.exe dosyasına çift tıkla. Önce zip'i bir klasöre çıkar.
Oyun imzalı olmadığı için Windows uyarı verebilir: Ek bilgi, sonra Yine de çalıştır.
WASD ile yürü, E ile etkileşime gir. T'ye dokun: yıllar arasında atla.
T'ye basılı tut: zamanı kaydır. Esc: duraklat ve ayarlar.

English
Unzip the folder first, then double-click BeforeTheFlood.exe.
The game isn't signed, so Windows may warn you: More info, then Run anyway.
WASD to walk, E to interact. Tap T to jump between years.
Hold T to run time. Esc pauses and opens settings.

Ebru Erkılıç, İbrahim Cem Durak
EOF

(cd "$work/web" && zip -q -r "$work/before-the-flood-web.zip" .)
(cd "$work/windows" && zip -q -r "$work/before-the-flood-windows.zip" .)
mv -f "$work/before-the-flood-web.zip" "$work/before-the-flood-windows.zip" "$out/"
ls -la "$out"/*.zip
