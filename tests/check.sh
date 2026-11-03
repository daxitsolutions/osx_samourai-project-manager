#!/bin/bash
# Vérification complète : suite métier puis smoke Merlin, arrêt au premier échec.
set -euo pipefail
cd "$(dirname "$0")/.."
swift test --parallel
check_binary_dir="$(mktemp -d)"
trap 'rm -rf "$check_binary_dir"' EXIT
swiftc -swift-version 6 \
  Sources/SamouraiProjectManagerApp/Support/MerlinProjectImportService.swift \
  tests/MerlinImportSmoke/main.swift \
  -o "$check_binary_dir/merlin-import-smoke"
"$check_binary_dir/merlin-import-smoke"
