#!/usr/bin/env bash
# HopHop marka çıktılarını TEK kaynaktan (brand/hophop-icon.svg) üretir.
#
#   ./brand/render.sh
#
# Üretilenler:
#   app/assets/brand/hophop.png   → uygulama içi marka (giriş, ana ekran)
#   backend/public/logo.svg       → tanıtım sayfası favicon'u (vektör kopya)
#   backend/public/og.jpg         → sosyal medya önizlemesi (og-source.svg'den)
#
# NOT: android/.../mipmap-*/ic_launcher.png ve drawable-*/ic_stat_hophop.png
# özgün çizimlerdir, bilerek dokunulmaz; SVG onlardan ölçülerek çıkarıldı.
set -euo pipefail
cd "$(dirname "$0")/.."

CHROME=$(command -v google-chrome-stable || command -v chromium || command -v google-chrome)
[ -n "$CHROME" ] || { echo "✗ Chrome/Chromium gerekli (SVG→PNG için)"; exit 1; }

render() { # <svg> <boyut> <çıktı>
  "$CHROME" --headless --disable-gpu --hide-scrollbars \
    --default-background-color=00000000 \
    --window-size="$2,$2" --screenshot="$3" --virtual-time-budget=2000 \
    "file://$PWD/$1" >/dev/null 2>&1
}

mkdir -p app/assets/brand
render brand/hophop-icon.svg 512 app/assets/brand/hophop.png
echo "✓ app/assets/brand/hophop.png (512px)"

cp brand/hophop-icon.svg backend/public/logo.svg
echo "✓ backend/public/logo.svg"

# Sosyal önizleme: og-source.svg marka işaretini gömülü olarak taşır.
# Kare olmadığı için render() yerine doğrudan 1200x630 pencereyle alınır.
TMP=$(mktemp -d)
"$CHROME" --headless --disable-gpu --hide-scrollbars --window-size=1200,630 \
  --screenshot="$TMP/og.png" --virtual-time-budget=2500 \
  "file://$PWD/backend/assets/og-source.svg" >/dev/null 2>&1
python3 - "$TMP/og.png" <<'PY'
import sys
from PIL import Image
Image.open(sys.argv[1]).convert('RGB').save(
    'backend/public/og.jpg', quality=88, optimize=True, progressive=True)
print('✓ backend/public/og.jpg')
PY
rm -rf "$TMP"
