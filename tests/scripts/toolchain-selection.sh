#!/usr/bin/env bash
# Issue #75 : vérifie le choix de chaîne d'outils de package.sh et run.sh sans compiler.
# Usage : bash tests/scripts/toolchain-selection.sh (depuis la racine du dépôt).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

extract() { sed -n '/^use_xcode_toolchain() {/,/^}/p' "$ROOT/$1"; }
[[ "$(extract package.sh)" == "$(extract run.sh)" ]] || { echo "ÉCHEC : fonctions différentes"; exit 1; }

# $1 = sortie simulée de xcode-select -p, $2 = racine Applications simulée, $3 = DEVELOPER_DIR initial
scenario() {
  mkdir -p "$WORK/bin"
  printf '#!/bin/sh\necho "%s"\n' "$1" > "$WORK/bin/xcode-select"; chmod +x "$WORK/bin/xcode-select"
  PATH="$WORK/bin:$PATH" DEVELOPER_DIR="$3" bash -c "
    set -euo pipefail
    log() { :; }
    $(extract package.sh | sed "s#/Applications/#$2/#g")
    use_xcode_toolchain
    echo \"\${DEVELOPER_DIR:-}\"
  " 2>&1 || echo "exit=$?"
}

APPS="$WORK/Applications"; mkdir -p "$APPS/Xcode.app/Contents/Developer"
NO_APPS="$WORK/Empty"; mkdir -p "$NO_APPS"
check() { [[ "$2" == "$3" ]] && echo "réussi : $1" || { echo "ÉCHEC : $1 → '$2' au lieu de '$3'"; exit 1; }; }

check "CLT active + Xcode installé → Xcode" "$(scenario /Library/Developer/CommandLineTools "$APPS" "")" "$APPS/Xcode.app/Contents/Developer"
check "Xcode déjà actif → inchangé" "$(scenario /Applications/Xcode.app/Contents/Developer "$APPS" "")" ""
check "DEVELOPER_DIR explicite → respecté" "$(scenario /Library/Developer/CommandLineTools "$APPS" /opt/Custom)" "/opt/Custom"
check "CLT active sans Xcode → arrêt" "$(scenario /Library/Developer/CommandLineTools "$NO_APPS" "")" "exit=1"
echo "Tous les scénarios ont réussi."
