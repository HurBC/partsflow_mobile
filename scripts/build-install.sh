#!/usr/bin/env bash
# Compila un APK (debug por defecto, solo arm64) con los dart-defines de env/staging.json y lo instala en el teléfono.
# Uso: scripts/build-install.sh [auto|adb|taildrop|none]
#   auto (por defecto): adb si hay un dispositivo conectado; si no, Taildrop.
#   none: solo compila.
# Variables opcionales: FLUTTER (binario), ENV_FILE (dart-defines), TAILDROP_TARGET (equipo en Tailscale),
#   BUILD=release para un APK ~5x más chico (instala mucho más rápido por Wi-Fi/Tailscale).
set -euo pipefail

mode="${1:-auto}"
root="$(cd "$(dirname "$0")/.." && pwd)"
flutter="${FLUTTER:-$HOME/.local/share/flutter/bin/flutter}"
env_file="${ENV_FILE:-$root/env/staging.json}"
target="${TAILDROP_TARGET:-}"
build="${BUILD:-debug}"
apk="$root/build/app/outputs/flutter-apk/app-$build.apk"

[[ -f "$env_file" ]] || { echo "Falta $env_file (ej: {\"API_BASE_URL\": \"https://.../api/\"})" >&2; exit 1; }

has_adb_device() { command -v adb >/dev/null && adb devices | awk 'NR > 1 && $2 == "device"' | grep -q .; }

cd "$root"
"$flutter" build apk "--$build" --target-platform android-arm64 --dart-define-from-file="$env_file"

if [[ "$mode" == auto ]]; then
  if has_adb_device; then mode=adb; else mode=taildrop; fi
fi

case "$mode" in
  adb)
    has_adb_device || { echo "adb no ve ningún dispositivo (adb connect <ip>:<puerto>)" >&2; exit 1; }
    adb install -r "$apk"
    ;;
  taildrop)
    [[ -n "$target" ]] || { echo "Define TAILDROP_TARGET con el nombre del teléfono en Tailscale" >&2; exit 1; }
    tailscale file cp "$apk" "$target:"
    echo "APK enviado a $target por Taildrop: ábrelo desde la notificación del teléfono para instalarlo."
    ;;
  none)
    echo "APK listo: $apk"
    ;;
  *)
    echo "Modo desconocido: $mode (auto|adb|taildrop|none)" >&2
    exit 1
    ;;
esac
