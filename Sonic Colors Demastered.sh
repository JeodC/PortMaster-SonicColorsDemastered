#!/bin/bash

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

export controlfolder

source $controlfolder/control.txt
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

# Variables
GAMEDIR="/$directory/ports/soniccolorsdemastered"

if [[ -f "${GAMEDIR}/swap_${CFW_NAME}.txt" ]]; then
  SWAP_SIZE="$(< "${GAMEDIR}/swap_${CFW_NAME}.txt")"  # Careful, don't go too big, it's on the root filesystem !
else
  SWAP_SIZE="0"
fi

case $CFW_NAME in
  "muOS")
    SWAP_FILE="/pm.swap"
    ;;
  "knulli")
    SWAP_FILE="/userdata/pm.swap"
    ;;
  "ArkOS")
    SWAP_FILE="/pm.swap"
    ;;
  *)
    echo "swap not implemented for $CFW_NAME"
    SWAP_SIZE="0"
    ;;
esac

# CD and set permissions
cd $GAMEDIR
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1
$ESUDO chmod +x -R $GAMEDIR/*

# Exports
export LD_LIBRARY_PATH="/usr/lib:$GAMEDIR/lib:$GAMEDIR/libs:$LD_LIBRARY_PATH"
export PATCHER_FILE="$GAMEDIR/tools/patchscript"
export PATCHER_GAME="$(basename "${0%.*}")" # This gets the current script filename without the extension
export PATCHER_TIME="2 to 5 minutes"

# dos2unix in case we need it
dos2unix "$GAMEDIR/tools/gmKtool.py"
dos2unix "$GAMEDIR/tools/Klib/GMblob.py"
dos2unix "$GAMEDIR/tools/patchscript"

# -------------------- BEGIN FUNCTIONS --------------------

create_swap()
{
  [[ "${SWAP_SIZE}" == "0" ]] && return 1
  $ESUDO fallocate -l ${SWAP_SIZE} "${SWAP_FILE}"
  $ESUDO chmod 600 "${SWAP_FILE}"
  $ESUDO mkswap "${SWAP_FILE}"
}

enable_swap()
{
  [[ "${SWAP_SIZE}" != "0" ]] && [[ ! -f "${SWAP_FILE}" ]] && create_swap
  $ESUDO swapon "${SWAP_FILE}"
}

disable_swap()
{
  [[ -f "${SWAP_FILE}" ]] && $ESUDO swapoff "${SWAP_FILE}" && $ESUDO rm "${SWAP_FILE}"
}

# --------------------- END FUNCTIONS ---------------------

# Check if patchlog.txt to skip patching
if [ ! -f patchlog.txt ]; then
    if [ -f "$controlfolder/utils/patcher.txt" ]; then
        source "$controlfolder/utils/patcher.txt"
        $ESUDO kill -9 $(pidof gptokeyb)
    else
        echo "This port requires the latest version of PortMaster." > $CUR_TTY
    fi
else
    echo "Patching process already completed. Skipping."
fi

# Display loading splash
if [ -f "$GAMEDIR/patchlog.txt" ]; then
    [[ "$CFW_NAME" == "muOS" ]] && $ESUDO ./tools/splash "splash.png" 1 
    $ESUDO ./tools/splash "splash.png" 2000
fi

# Run the game
$GPTOKEYB "gmloader.aarch64" -c "./sonic.gptk" &
pm_platform_helper "$GAMEDIR/gmloader.aarch64"

[[ $DEVICE_RAM -le 1 ]] && enable_swap

./gmloader.aarch64 -c "gmloader.json"

[[ -f "${SWAP_FILE}" ]] && disable_swap

# Kill processes
pm_finish
