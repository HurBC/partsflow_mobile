#!/usr/bin/env bash
# Compila las APK release (arm64 y armv7) y las publica como GitHub Release del tag
# v<version de pubspec.yaml>. Se corre desde main, con el árbol limpio.
#
# Uso: scripts/release-apk.sh [env]        env por defecto: staging (env/staging.json)
#      NOTES_FILE=notas.md scripts/release-apk.sh   notas propias en vez de las generadas
set -euo pipefail
cd "$(dirname "$0")/.."

flutter="${FLUTTER:-$HOME/.local/share/flutter/bin/flutter}"
env_file="env/${1:-staging}.json"
[ -f "$env_file" ] || { echo "falta $env_file" >&2; exit 1; }

version=$(sed -n 's/^version: *\([0-9.]*\)+.*/\1/p' pubspec.yaml)
tag="v$version"

[ -z "$(git status --porcelain)" ] || { echo "hay cambios sin commit" >&2; exit 1; }
git fetch -q origin main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || { echo "HEAD no es origin/main" >&2; exit 1; }
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null || gh release view "$tag" >/dev/null 2>&1; then
  echo "$tag ya existe: sube la versión en pubspec.yaml" >&2
  exit 1
fi

# La APK pública no escribe el log de diagnóstico (cuerpos de requests) en logcat.
tmp_env=$(mktemp --suffix=.json)
trap 'rm -f "$tmp_env"' EXIT
jq '.PF_DEBUG_LOG = false' "$env_file" >"$tmp_env"

"$flutter" build apk --release --split-per-abi --target-platform android-arm,android-arm64 \
  --dart-define-from-file="$tmp_env"

out=build/app/outputs/flutter-apk
dist=build/release-apk
rm -rf "$dist" && mkdir -p "$dist"
cp "$out/app-arm64-v8a-release.apk" "$dist/partsflow-$tag-arm64.apk"
cp "$out/app-armeabi-v7a-release.apk" "$dist/partsflow-$tag-armv7.apk"

notes=(--generate-notes)
[ -n "${NOTES_FILE:-}" ] && notes=(--notes-file "$NOTES_FILE")

git tag -a "$tag" -m "Partsflow $tag"
git push -q origin "$tag"
gh release create "$tag" "$dist"/*.apk --title "Partsflow $tag" "${notes[@]}"
