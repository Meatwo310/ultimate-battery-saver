#!/bin/bash

set -eu -o pipefail

# Show CPU Path
function showCpuPath() {
  echo "/sys/devices/system/cpu/cpu${*}/online"
}

# Short Help Message
function showShortHelpMessage() {
  echo "Usage: $(basename $0) [OPERATION] [ARG]" >&2
  echo "Try \`$(basename $0) help\` for more information." >&2
}

# Help Message
function showHelpMessage() {
  echo "Usage: $(basename $0) [OPERATION] [ARG]" >&2
  echo "Controls the number of CPUs enabled/disabled or displays that information." >&2
  echo "" >&2
  echo "Specific Usage:" >&2
  echo "  $(basename $0) enable NUMBER     Enables the specified number of CPUs, starting from CPU0, and disables the rest. Root required." >&2
  echo "  $(basename $0) disable NUMBER    Disables the specified number of CPUs, starting from CPU1, and enables the rest. Root required." >&2
  echo "  $(basename $0) info              Show the current CPU activation status." >&2
  echo "  $(basename $0) help              Show this help message." >&2
  echo "" >&2
  echo "Notes:" >&2
  echo "  - \`$(basename $0) NUMBER\` == \`$(basename $0) enable NUMBER\`." >&2
  echo "  - \`$(basename $0)\` == \`$(basename $0) info\`." >&2
}


# Parse Arguments
function parseArgs() {
  local operation=""
  local arg=""
  if [ $# -eq 0 ]; then
    # No arguments
    operation="info"
  elif [ $# -eq 1 ]; then
    # One Argument
    if [[ "$1" =~ ^[0-9]+$ ]]; then
      operation="enable"
      arg="$1"
    else
      operation="$1"
    fi
  elif [ $# -eq 2 ]; then
    # Two Arguments
    operation="$1"
    arg="$2"
  else
    echo "Error: Too many arguments" >&2
    showShortHelpMessage
    exit 1
  fi

  case "$operation" in
    "info" | "help")
      if [ ! -z "$arg" ]; then
        echo "Error: Too many arguments" >&2
        showShortHelpMessage
        exit 1
      fi
      ;;
    "enable" | "disable")
      if [ -z "$arg" ]; then
        echo "Error: Missing argument" >&2
        showShortHelpMessage
        exit 1
      fi
      ;;
    *)
      echo "Error: Invalid operation: $operation" >&2
      showShortHelpMessage
      exit 1
      ;;
  esac

  echo "$operation" "$arg"
  exit 0
}

result=($(parseArgs "$@") "")
operation="${result[0]}"
arg="${result[1]}"

echo "Operation is" "$operation"
echo "Argument is" "$arg"
