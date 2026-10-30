#!/usr/bin/env bash
# Genera los íconos de Android (legacy + adaptive) desde el logo de Partsflow.
# Solo necesita rsvg-convert (librsvg). Uso: scripts/gen-launcher-icons.sh [logo.png]
set -euo pipefail
cd "$(dirname "$0")/.."

logo="${1:-assets/images/partsflow_logo_circular.png}"
res=android/app/src/main/res
b64=$(base64 -w0 "$logo")
tmp=$(mktemp --suffix=.svg)
trap 'rm -f "$tmp"' EXIT

# render <px de salida> <lado del lienzo> <lado del logo> <archivo>: logo centrado, fondo transparente
render() {
  local px=$1 canvas=$2 size=$3 out=$4
  local off
  off=$(awk "BEGIN{print ($canvas-$size)/2}")
  cat >"$tmp" <<EOF
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 $canvas $canvas">
  <image x="$off" y="$off" width="$size" height="$size" xlink:href="data:image/png;base64,$b64"/>
</svg>
EOF
  rsvg-convert -w "$px" -h "$px" "$tmp" -o "$out"
}

# densidad:factor (1dp = factor px)
for d in mdpi:1 hdpi:1.5 xhdpi:2 xxhdpi:3 xxxhdpi:4; do
  name=${d%%:*} f=${d##*:}
  mkdir -p "$res/mipmap-$name"
  # Legacy (API < 26): 48dp con el logo en 44dp.
  render "$(awk "BEGIN{print 48*$f}")" 48 44 "$res/mipmap-$name/ic_launcher.png"
  # Adaptive: lienzo de 108dp; el logo en 56dp para que la punta del escudo no se corte con máscara circular.
  render "$(awk "BEGIN{print 108*$f}")" 108 56 "$res/mipmap-$name/ic_launcher_foreground.png"
done

mkdir -p "$res/mipmap-anydpi-v26"
cat >"$res/mipmap-anydpi-v26/ic_launcher.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
EOF
cat >"$res/values/ic_launcher_background.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#FFFFFF</color>
</resources>
EOF
echo "íconos generados en $res"
