#!/bin/bash

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
  echo "  $(basename $0) enable NUMBER      Enables the specified number of CPUs, starting from CPU0, and disables the rest. Root required." >&2
  echo "  $(basename $0) disable NUMBER     Disables the specified number of CPUs, starting from CPU1, and enables the rest. Root required." >&2
  echo "  $(basename $0) info               Show the current CPU activation status." >&2
  echo "  $(basename $0) help               Show this help message." >&2
  echo "" >&2
  echo "Notes:" >&2
  echo "  - \`$(basename $0) NUMBER\` == \`$(basename $0) enable NUMBER\`." >&2
  echo "  - \`$(basename $0)\` == \`$(basename $0) info\`." >&2
  #echo "  - To enable or disable the CPU, you must run as root." >&2
}

showHelpMessage

OPERATION=""
ARG=""
# Parse Arguments
function parseArgs() {
  if [ $# -eq 0 ]; then
    # No arguments
    OPERATION="info"
  elif [ $# -eq 1 ]; then
    # One Argument
    OPERATION="enable"
    ARG="$1"
  elif [ $# -eq 2 ]; then
    # Two Arguments
    OPERATION="$1"
    ARG="$2"
  else
    echo "Error: Too many arguments" >&2
    showShortHelpMessage
    exit 1
  fi

  case "$OPERATION" in
    "info" | "help")
      ;;
    "enable" | "disable")
      if [ -z "$ARG" ]; then
        echo "Error: Missing argument after $OPERATION" >&2
        showShortHelpMessage
        exit 1
      fi
      if ! [[ "$ARG" =~ ^[0-9]+$ ]]; then
        echo "Error: Invalid argument $ARG after $OPERATION" >&2
        showShortHelpMessage
        exit 1
      fi
      ;;
    *)
      echo "Error: Invalid operation: $OPERATION" >&2
      showShortHelpMessage
      exit 1
      ;;
  esac
}

showHelpMessage

