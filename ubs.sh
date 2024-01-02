#!/bin/bash

################################################################################
# Setup                                                                        #
################################################################################

set -eu -o pipefail
# set -vx


################################################################################
# Get CPU Information                                                          #
################################################################################

#TODO: Clean up dupulicated code

set +e # Ignore errors

# Get online CPUs list base
# Example: On-line CPU(s) list: 0-2,5,7 -> 0-2 5 7
online_cpus_list_base=($(
  LANG=C lscpu |                                  # Get CPU information
  grep -- 'On-line CPU(s) list:' |                # Get only the line with "On-line CPU(s) list:"
  sed 's/On-line CPU(s) list: *//' |              # Remove "On-line CPU(s) list: "
  tr ',' '\n'                                     # Split into lines
))

# Get offline CPUs list base
# Example: Off-line CPU(s) list: 3-4,6 -> 3-4 6
offline_cpus_list_base=($(
  LANG=C lscpu |                                  # Get CPU information
  grep -- 'Off-line CPU(s) list:' |               # Get only the line with "Off-line CPU(s) list:"
  sed 's/Off-line CPU(s) list: *//' |             # Remove "Off-line CPU(s) list: "
  tr ',' '\n'                                     # Split into lines
))

set -e # Stop ignoring errors

# Get online CPUs list
# Example: 0-2 5 7 -> 0 1 2 5 7
online_cpus_list=($(
  echo $(
    # Obtains only ranged CPU information.
    for cpu in "${online_cpus_list_base[@]}"; do
      if [[ $cpu == *'-'* ]]; then
        IFS='-' read -r start end <<< "$cpu"
        seq $start $end
      else
        echo "$cpu"
      fi
    done
  ) |
  tr ' ' '\n' |   # Split into lines
  sort -n         # Sort numerically
))

# Get online accessable CPUs
# Example: 0 1 2 5 7 -> 1 2 5 7
online_all_accessable_cpus_list=()
for cpu in "${online_cpus_list[@]}"; do
  if [ -e "/sys/devices/system/cpu/cpu${cpu}/online" ]; then
    online_all_accessable_cpus_list+=("$cpu")
  fi
done

# Get offline CPUs
# Example: 3-4 6 -> 3 4 6
offline_cpus_list=($(
  echo $(
    # Obtains only ranged CPU information.
    for cpu in "${offline_cpus_list_base[@]}"; do
      if [[ $cpu == *'-'* ]]; then
        IFS='-' read -r start end <<< "$cpu"
        seq $start $end
      else
        echo "$cpu"
      fi
    done
  ) |
  tr ' ' '\n' |   # Split into lines
  sort -n         # Sort numerically
))

# Get offline accessable CPUs
# Example: 3 4 6 -> 3 4 6
offline_all_accessable_cpus_list=()
for cpu in "${offline_cpus_list[@]}"; do
  if [ -e "/sys/devices/system/cpu/cpu${cpu}/online" ]; then
    offline_all_accessable_cpus_list+=("$cpu")
  fi
done

# Get all CPUs list
# Example: 0 1 2 3 4 5 6 7
all_cpus_list=($(
  echo "${online_cpus_list[@]}" "${offline_cpus_list[@]}" |
  tr ' ' '\n' |  # Split into lines
  sort -n |      # Sort numerically in reverse order
  uniq           # Remove duplicates
))

# Get all accessable CPUs list
# Example: 1 2 3 4 5 6 7
all_accessable_cpus_list=()
for cpu in "${all_cpus_list[@]}"; do
  if [ -e "/sys/devices/system/cpu/cpu${cpu}/online" ]; then
    all_accessable_cpus_list+=("$cpu")
  fi
done

# Get all CPUs status
# Example: 1 0 1 1 0 1 0 1
all_cpus_status_list=()
for cpu in "${all_cpus_list[@]}"; do
  printf '%s\0' "${online_cpus_list[@]}" | grep -qx "$cpu" && all_cpus_status_list+=("1") || all_cpus_status_list+=("0")
done

# Get all CPUs accessability
# Example: 0 1 1 1 1 1 1 1
all_cpus_accessability_list=()
for cpu in "${all_cpus_list[@]}"; do
  printf '%s\0' "${all_accessable_cpus_list[@]}" | grep -qx "$cpu" && all_cpus_accessability_list+=("1") || all_cpus_accessability_list+=("0")
done

set +e # Ignore errors

# Get number of CPUs
num_of_all_cpus=${#all_cpus_list[@]}

#echo "Number of CPUs: $num_of_all_cpus"

# Get number of accessable CPUs
num_of_accessable_cpus=${#all_accessable_cpus_list[@]}

#echo "Number of accessable CPUs: $num_of_accessable_cpus"

# Get number of online CPUs
num_of_online_cpus=${#online_cpus_list[@]}

#echo "Number of online CPUs: $num_of_online_cpus"

# Get number of accessable online CPUs
num_of_accessable_online_cpus=${#online_all_accessable_cpus_list[@]}

#echo "Number of accessable online CPUs: $num_of_accessable_online_cpus"

# Get number of offline CPUs
num_of_offline_cpus=${#offline_cpus_list[@]}

#echo "Number of offline CPUs: $num_of_offline_cpus"

# Get number of accessable offline CPUs
num_of_accessable_offline_cpus=${#offline_all_accessable_cpus_list[@]}

#echo "Number of accessable offline CPUs: $num_of_accessable_offline_cpus"

set -e # Stop ignoring errors

################################################################################
# Functions                                                                    #
################################################################################

# Check Root
function checkRoot() {
  if [ $(whoami) != "root" ]; then
    echo "This command requires ROOT to run" >&2
    echo "Example: sudo $(basename $0)" >&2
    exit 1
  fi
}

# Short Help Message
function showShortHelpMessage() {
  echo "Usage: $(basename $0) [OPERATION] [ARG]" >&2
  echo "Try \`$(basename $0) help\` for more information." >&2
}

# Help Message
function showHelpMessage() {
  cat << EOF >&2
Usage: $(basename $0) [OPERATION] [ARG]
Controls the number of CPUs enabled/disabled or displays that information.

Specific Usage:
  $(basename $0) [info]             Show the current CPU status. Shown as "#"(Online) or "-"(Offline) for each CPU.
  $(basename $0) [enable] NUMBER    Enables the specified number of CPUs. Root required. 
  $(basename $0) disable NUMBER     Disables the specified number of CPUs. Root required.
  $(basename $0) help               Show this help message.

Notes:
  - CPU0 is always enabled and cannot be disabled in most systems.
  - CPU's status character will be colored yellow if this script fails to get the CPU's status.
EOF
}

# Parse Arguments
function parseArgs() {
  local operation=""
  local arg=""
  if [ "$#" -eq 0 ]; then
    # No arguments
    operation="info"
  elif [ "$#" -eq 1 ]; then
    # One Argument
    if echo "$1" | grep -qE '^[0-9]+$'; then
      operation="enable"
      arg="$1"
    else
      operation="$1"
    fi
  elif [ "$#" -eq 2 ]; then
    # Two Arguments
    operation="$1"
    arg="$2"
  else
    echo "Error: Too many arguments" >&2
    showShortHelpMessage
    exit 1
  fi

  case "$operation" in
    "info" | "help" | "--help")
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
      elif ! echo "$arg" | grep -qE '^[0-9]+$'; then
        echo "Error: Invalid argument: $arg" >&2
        showShortHelpMessage
        exit 1
      fi

      if [ "$operation" == "enable" ]; then
        if [ "$arg" -lt "$(($num_of_all_cpus-$num_of_accessable_cpus))" ]; then
          echo "Error: Argument is too small: $arg" >&2
          echo "Unaccessable CPUs: $(($num_of_all_cpus-$num_of_accessable_cpus))" >&2
          exit 1
        fi
      elif [ "$operation" == "disable" ]; then
        if [ "$arg" -gt "$num_of_accessable_cpus" ]; then
          echo "Error: Argument is too large: $arg" >&2
          echo "Accessable CPUs: $num_of_accessable_cpus" >&2
          exit 1
        fi
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

# Show CPU Path
function showCpuPath() {
  echo "/sys/devices/system/cpu/cpu${*}/online"
}

# Show CPU Info
function showInfo() {
  percentage=$((num_of_online_cpus * 100 / num_of_all_cpus))
  echo -n "${num_of_online_cpus}/${num_of_all_cpus} CPU(s) = ${percentage}% POWER "

  echo -n "["

  for i in "${all_cpus_list[@]}"; do
    if [ "${all_cpus_status_list[$i]}" -eq 1 ]; then
      if [ "${all_cpus_accessability_list[$i]}" -eq 1 ]; then
        echo -en "\e[32m#"
      else
        echo -en "\e[33m#"
      fi
    else
      if [ "${all_cpus_accessability_list[$i]}" -eq 1 ]; then
        echo -en "\e[31m-"
      else
        echo -en "\e[33m_"
      fi
    fi
  done
  echo -en "\e[m] "

  echo ""

  if [ $percentage -le 10 ]; then
    echo -en "\e[1m\e[3m\e[4m\e[5m\e[37m\e[42m"
    echo -n "ULTIMATE BATTERY SAVER!!!!!!!!"
  elif [ $percentage -le 20 ]; then
    echo -en "\e[1m\e[37m\e[42m"
    echo -n "SUPER BATTERY SAVER!!!"
  elif [ $percentage -le 40 ]; then
    echo -en "\e[1m"
    echo -n "Battery Saving!"
  elif [ $percentage -le 60 ]; then
    echo -en "Balanced Power!"
  elif [ $percentage -le 80 ]; then
    echo -en "\e[1m"
    echo -n "High Power!"
  elif [ $percentage -le 99 ]; then
    echo -en "\e[1m\e[41m"
    echo -n "SUPER POWER!!!"
  else
    echo -en "\e[1m\e[3m\e[4m\e[5m\e[37m\e[41m"
    echo -n "ULTIMATE POWER!!!!!!!!"
  fi
  echo -e "\e[0m"
}


################################################################################
# Parse Arguments                                                              #
################################################################################

result=($(parseArgs "$@") "")
operation="${result[0]}"
arg="${result[1]}"

#echo "Operation is" "$operation"
#echo "Argument is" "$arg"

case "$operation" in
  "enable")
    checkRoot

    enable=(${all_accessable_cpus_list[@]:0:$(($arg-($num_of_all_cpus-$num_of_accessable_cpus)))})
    disable=(${all_accessable_cpus_list[@]:$(($arg-($num_of_all_cpus-$num_of_accessable_cpus)))})
    for cpu in "${enable[@]}"; do
      echo 1 > $(showCpuPath $cpu)
    done
    for cpu in "${disable[@]}"; do
      echo 0 > $(showCpuPath $cpu)
    done

    $0 info

    ;;
  "disable")
    checkRoot

    disable=(${all_accessable_cpus_list[@]:0:$(($arg))})
    enable=(${all_accessable_cpus_list[@]:$(($arg))})
    for cpu in "${enable[@]}"; do
      echo 1 > $(showCpuPath $cpu)
    done
    for cpu in "${disable[@]}"; do
      echo 0 > $(showCpuPath $cpu)
    done

    $0 info

    ;;
  "info")
    showInfo
    ;;
  "help" | "--help")
    showHelpMessage
    ;;
  *)
    echo "Error: Unknown operation: $operation" >&2
    showShortHelpMessage
    exit 1
    ;;
esac


