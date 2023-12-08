#!/system/xbin/bash


# Show CPU Path
showCpuPath () {
  echo "/sys/devices/system/cpu/cpu${*}/online"
}

# Help Message
showHelpMessage () {
  echo "Usage: $0 <ActiveCPUs>" >&2
  echo "Enables the specified number of CPUs and disables all the rest." >&2
}

# Arg Check
if [ $* ]; then
  :
else
  showHelpMessage $@
  exit 2
fi


# Check root
if [ $(whoami) != "root" ]; then
  echo "This command requires ROOT to run" >&2
  echo "Example: sudo $0" >&2
  exit 2
fi


# Check arg >= 1
if [ $* -lt 1 ]; then
  echo "Arg: $*; Required: >=1" >&2
  showHelpMessage $@
  exit 1
fi


# Check Available CPUs Count
for ((i=1; i>=0; i+=1)); do
  if [ ! -e $(showCpuPath $i) ]; then
    break
  fi
done
availableCpus=$i
#echo "Available CPU(s): ${availableCpus}" >&2

# Is arg < availableCpus
if [ $* -gt $availableCpus ]; then
  echo "Arg: $*; Available: ${availableCpus}" >&2
  showHelpMessage $@
  exit 1
fi


# Let's GO
i=0
for i in $(seq 1 $(($* - 1))); do
  echo 1 > $(showCpuPath $i)
done

for i in $(seq $((i + 1)) $(($availableCpus - 1))); do
  echo 0 > $(showCpuPath $i)
done

percentage=$(($* * 100 / availableCpus))
echo "Enabled $*/${availableCpus} CPU(s) = ${percentage}% power"

if [ $percentage -le 10 ]; then
  echo -en "\e[1m\e[3m\e[4m\e[5m\e[37m\e[42mULTIMATE BATTERY SAVER!!!!!!!!"
elif [ $percentage -le 20 ]; then
  echo -en "\e[1m\e[37m\e[42mSUPER BATTERY SAVER!!!"
elif [ $percentage -le 40 ]; then
  echo -en "\e[1mBattery Saving!"
elif [ $percentage -le 60 ]; then
  echo -en "Balanced Power!"
elif [ $percentage -le 80 ]; then
  echo -en "\e[1mHigh Power!"
elif [ $percentage -le 99 ]; then
  echo -en "\e[1m\e[41m\e[41mSUPER POWER!!!"
else
  echo -en "\e[1m\e[3m\e[4m\e[5m\e[37m\e[41mULTIMATE POWER!!!!!!!!"
fi
echo -e "\e[0m"
