#!/usr/bin/env bash
set -euo pipefail

RED="\033[37m"
BRED="\033[1;37m"
RESET="\033[0m"

do_clear() {
  if [ "${NO_CLEAR:-}" = "1" ]; then
    printf "\n--------------------\n\n"
    return 0
  fi
  if clear -x >/dev/null 2>&1; then
    clear -x
  else
    clear
  fi
}

box_print() {
  local __text="$1"
  local __label="Command: "
  local __line="${__label}${__text}"
  local __len=${#__line}
  local __h="+"; for ((i=0;i<__len+2;i++)); do __h+="-"; done; __h+="+"
  printf "\n%s\n" "$__h"
  printf "| %b |\n" "${BRED}${__line}${RESET}"
  printf "%s\n" "$__h"
}

run_step() {
  local __desc="$1"
  local __cmd="$2"
  do_clear
  printf "\n%b%s%b\n\n" "$RED" "Next: ${__desc}" "$RESET"
  box_print "$__cmd"
  printf "\n\n"
  read -r -p "Press Enter to run, or type 's' to skip: " __ans </dev/tty || true
  if [ "${__ans:-}" = "s" ]; then
    printf "Skipped\n"
    return 0
  fi
  printf "Running...\n\n"
  set +e
  bash -c "$__cmd"
  __code=$?
  set -e
  if [ "$__code" -ne 0 ]; then
    read -r -p "Command failed. Press Enter to continue, or type 'q' to quit: " __cont </dev/tty || true
    if [ "${__cont:-}" = "q" ]; then
      exit "$__code"
    fi
  fi
  while true; do
    read -r -p "Press Enter for next, or type 'r' to rerun: " __post </dev/tty || true
    if [ "${__post:-}" = "r" ]; then
      do_clear
      box_print "$__cmd"
      printf "Running...\n\n"
      set +e
      bash -c "$__cmd"
      __code=$?
      set -e
      if [ "$__code" -ne 0 ]; then
        read -r -p "Command failed. Press Enter to continue rerun prompt, or type 'q' to quit: " __cont2 </dev/tty || true
        if [ "${__cont2:-}" = "q" ]; then
          exit "$__code"
        fi
      fi
      continue
    fi
    break
  done
  printf "\n"
}

STEPS=""

if [ "${1:-}" != "" ] && [ -f "$1" ]; then
  STEPS_CONTENT=$(sed -E '/^[[:space:]]*#/d;/^[[:space:]]*$/d' "$1")
else
  STEPS_CONTENT="$STEPS"
fi

if [ -z "${STEPS_CONTENT//[$'\t\r\n ']}" ]; then
  printf "No steps provided. Supply a file with lines of 'description|command' or set the STEPS variable in the script.\n" 1>&2
  exit 1
fi

while IFS='|' read -r __desc __cmd; do
  [ -z "${__desc:-}" ] && continue
  run_step "$__desc" "$__cmd"
done <<< "$STEPS_CONTENT"

printf "\nAll steps completed.\n"