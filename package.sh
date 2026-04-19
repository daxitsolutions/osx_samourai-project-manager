#!/usr/bin/env bash
set -euo pipefail

APP_NAME="SamouraiProjectManager"
APP_EXECUTABLE="$APP_NAME"
BUNDLE_ID="com.samourai.projectmanager"
CONFIGURATION="release"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST_DIR="/Applications"
INSTALL=1

if [[ "${1:-}" == "--no-install" ]]; then
  INSTALL=0
fi

log() {
  printf '[package.sh] %s\n' "$*"
}

build_binary() {
  log "Compilation ($CONFIGURATION) en cours..."
  mkdir -p "$ROOT_DIR/.build/clang-cache" "$ROOT_DIR/.build/swift-cache"
  CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-cache" \
  SWIFT_MODULECACHE_PATH="$ROOT_DIR/.build/swift-cache" \
  swift build -c "$CONFIGURATION" --product "$APP_EXECUTABLE"

  local bin_dir
  bin_dir="$(CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-cache" \
    SWIFT_MODULECACHE_PATH="$ROOT_DIR/.build/swift-cache" \
    swift build -c "$CONFIGURATION" --show-bin-path)"
  BUILD_BIN="$bin_dir/$APP_EXECUTABLE"

  if [[ ! -x "$BUILD_BIN" ]]; then
    log "Binaire introuvable: $BUILD_BIN"
    exit 1
  fi
}

create_bundle() {
  STAGING_DIR="$(mktemp -d "/tmp/${APP_NAME}-bundle-XXXXXX")"
  APP_BUNDLE="$STAGING_DIR/$APP_NAME.app"

  mkdir -p "$APP_BUNDLE/Contents/MacOS"
  cp "$BUILD_BIN" "$APP_BUNDLE/Contents/MacOS/$APP_EXECUTABLE"

  cat >"$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>fr</string>
  <key>CFBundleExecutable</key>
  <string>$APP_EXECUTABLE</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>15.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

  # Signature ad-hoc locale pour éviter des erreurs de lancement selon la config machine.
  if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true
  fi
}

install_bundle() {
  DEST_APP="$DEST_DIR/$APP_NAME.app"
  log "Installation dans $DEST_APP ..."

  if [[ -w "$DEST_DIR" ]]; then
    ditto "$APP_BUNDLE" "$DEST_APP"
  else
    log "Le dossier $DEST_DIR nécessite des droits administrateur."
    sudo ditto "$APP_BUNDLE" "$DEST_APP"
  fi

  log "Installation terminée: $DEST_APP"
  log "Tu peux lancer l'app depuis Finder (Applications) ou avec: open \"$DEST_APP\""
}

cleanup() {
  if [[ -n "${STAGING_DIR:-}" && -d "${STAGING_DIR:-}" ]]; then
    rm -rf "$STAGING_DIR"
  fi
}

trap cleanup EXIT

cd "$ROOT_DIR"
build_binary
create_bundle

if [[ "$INSTALL" -eq 1 ]]; then
  install_bundle
else
  log "Bundle prêt: $APP_BUNDLE"
  log "Option --no-install active: aucune copie vers /Applications."
fi
