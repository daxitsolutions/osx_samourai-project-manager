#!/usr/bin/env bash
set -euo pipefail

APP_NAME="SamouraiProjectManager"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_BIN="$ROOT_DIR/.build/debug/$APP_NAME"
DEBUG_MODE=0

if [[ "${1:-}" == "--debug" ]]; then
  DEBUG_MODE=1
fi

TS="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="/tmp/${APP_NAME}-run-${TS}.log"

log() {
  printf '[run.sh] %s\n' "$*"
}

debug() {
  if [[ "$DEBUG_MODE" -eq 1 ]]; then
    printf '[run.sh][debug] %s\n' "$*"
  fi
}

terminate_previous_instances() {
  local existing_pids
  existing_pids="$(pgrep -f "(${ROOT_DIR}/)?\\.build/.*/${APP_NAME}" || true)"
  if [[ -z "$existing_pids" ]]; then
    return
  fi

  log "Ancienne(s) instance(s) détectée(s), arrêt propre avant relance..."
  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    kill "$pid" >/dev/null 2>&1 || true
  done <<<"$existing_pids"
  sleep 0.3
}

attempt_focus() {
  local pid="$1"

  if osascript -e "tell application \"$APP_NAME\" to activate" >/dev/null 2>&1; then
    debug "Activation AppleScript OK (tell application)."
    return 0
  fi

  if osascript \
    -e 'tell application "System Events"' \
    -e "set frontmost of (first process whose unix id is $pid) to true" \
    -e 'end tell' >/dev/null 2>&1; then
    debug "Activation AppleScript OK (System Events / unix id)."
    return 0
  fi

  return 1
}

cd "$ROOT_DIR"

if [[ "$DEBUG_MODE" -eq 1 ]]; then
  log "Mode DEBUG actif"
  log "Logs: $LOG_FILE"
  {
    echo "===== ENV ====="
    date
    whoami
    pwd
    uname -a
    sw_vers || true
    echo "TTY: $(tty || true)"
    echo "================"
  } >"$LOG_FILE" 2>&1
fi

log "Build en cours..."
if [[ "$DEBUG_MODE" -eq 1 ]]; then
  swift build >>"$LOG_FILE" 2>&1
else
  swift build >/dev/null
fi

if [[ ! -x "$BUILD_BIN" ]]; then
  log "Binaire introuvable: $BUILD_BIN"
  exit 1
fi

terminate_previous_instances

log "Lancement de $APP_NAME..."
SWIFT_BACKTRACE=enable "$BUILD_BIN" >>"$LOG_FILE" 2>&1 &
app_pid=$!

sleep 1

if ! kill -0 "$app_pid" 2>/dev/null; then
  log "Le process s'est arrêté immédiatement (PID $app_pid)."
  log "Consulte les logs: $LOG_FILE"
  if [[ "$DEBUG_MODE" -eq 1 ]]; then
    echo "----- LOG TAIL -----"
    tail -n 120 "$LOG_FILE" || true
    echo "--------------------"
  fi
  exit 1
fi

# Tentative de focus (optionnelle, peut être bloquée par macOS permissions).
if ! attempt_focus "$app_pid"; then
  log "Impossible de forcer le focus automatiquement."
  log "Clique la fenêtre app ou autorise Automatisation/Accessibilité pour ton terminal."
  debug "Activation AppleScript refusée/bloquée (tell application + System Events)."
fi

if [[ "$DEBUG_MODE" -eq 1 ]]; then
  debug "PID app: $app_pid"
  debug "Process list match:"
  pgrep -fl "$APP_NAME" || true
  debug "Dernières lignes log:"
  tail -n 40 "$LOG_FILE" || true
fi

log "$APP_NAME lancé (PID $app_pid)."
log "Important: c'est une app GUI, le clavier doit aller dans la fenêtre app, pas dans la console."
if [[ "$DEBUG_MODE" -eq 1 ]]; then
  log "Pour suivre les logs en live: tail -f $LOG_FILE"
fi
