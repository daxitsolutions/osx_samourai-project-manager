#!/usr/bin/env bash
# Plantage du 2 novembre (#75) : l'installation doit remplacer l'app existante, pas fusionner avec elle.
# Usage : bash tests/scripts/package-install-replace.sh (depuis la racine du dépôt). Aucune écriture dans /Applications.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Ancienne app avec un fichier obsolète, nouvelle app signée ad hoc sans ce fichier.
mkdir -p "$WORK/dest/Demo.app/Contents/Resources/old.lproj" "$WORK/new/Demo.app/Contents/MacOS"
echo obsolete > "$WORK/dest/Demo.app/Contents/Resources/old.lproj/Localizable.strings"
cp /usr/bin/true "$WORK/new/Demo.app/Contents/MacOS/Demo"
printf '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleExecutable</key><string>Demo</string><key>CFBundleIdentifier</key><string>test.demo</string></dict></plist>' > "$WORK/new/Demo.app/Contents/Info.plist"
codesign --force --deep --sign - "$WORK/new/Demo.app" >/dev/null 2>&1

APP_NAME=Demo DEST_DIR="$WORK/dest" APP_BUNDLE="$WORK/new/Demo.app" bash -c "
  set -euo pipefail
  log() { :; }
  $(sed -n '/^install_bundle() {/,/^}/p' "$ROOT/package.sh")
  install_bundle
"

[[ ! -e "$WORK/dest/Demo.app/Contents/Resources/old.lproj" ]] || { echo "ÉCHEC : fichier obsolète conservé"; exit 1; }
codesign --verify --deep "$WORK/dest/Demo.app" || { echo "ÉCHEC : signature invalide après installation"; exit 1; }
echo "réussi : ancienne app remplacée, signature valide"
