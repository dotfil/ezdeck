#!/bin/env bash
################################################################################
# @@@@@@@@@@@@@@@@@@@@@@@@@@                                                    
# @@@                   @@@ @@@@@@@&      @@@@@@@@@     @@@@@@@/  @@@#   &@@@%  
# @@@                 %@@@  @@@@@@@@@@@,  @@@/////   %@@@@@//@@   @@@# &@@@*    
# @@@@@@@@@@@%      /@@@    @@@@    @@@@  @@@@@@@@  *@@@&         @@@@@@@       
# @@@              @@@      @@@@    @@@@  @@@/////  *@@@&         @@@@@@@@@     
# @@@            @@@        @@@@@@@@@@@   @@@@@@@@@  (@@@@@@@@@*  @@@#  @@@@@   
# @@@          @@@/         &&&&&&&       &&&&&&&&&     &@@@@@    &&&(    &&&&* 
# @@@@@@@@@@@@@@@@@@@@@@@@@@                                                    
################################################################################
# install.sh - Add controller support to Oblivion Steam Version on Linux
################################################################################

error() { zenity --warning --text="ERROR: ${1}"; }

readonly STEAM_PATH="${HOME}/.local/share/Steam/steamapps"
readonly SD_CARD=$(lsblk --output MOUNTPOINT | grep -Eo '^.*mmcblk[0-9]p1')
readonly SD_STEAM_PATH="${SD_CARD}/steamapps"

readonly GAME='Oblivion'
readonly APP_ID='22330'

# Use the storage the game is installed on
if [[ -d "${STEAM_PATH}/common/${GAME}" ]]; then
    readonly GAME_DIR="${STEAM_PATH}/common/${GAME}"
elif [[ -d "${SD_STEAM_PATH}/common/${GAME}" ]]; then
    readonly GAME_DIR="${SD_STEAM_PATH}/common/${GAME}"
else
    error "${GAME} must first be installed"
    exit 1
fi

readonly C_DRIVE="${STEAM_PATH}/compatdata/${APP_ID}/pfx/drive_c"
readonly APP_DATA="${C_DRIVE}/users/steamuser/AppData/Local"
readonly CONF_DIR="${C_DRIVE}/users/steamuser/Documents/My Games/Oblivion"
readonly TMP_DIR="/tmp/ez_${GAME}"

# eval $(sed 's/OblivionLauncher.exe/obse_loader.exe/g' <<< "%command%")
readonly SED_CMD="sed 's/OblivionLauncher.exe/obse_loader.exe/'"
readonly LAUNCH_CMD="eval \$(${SED_CMD} <<< \"%command%\")"

declare LOCAL_CONFIG

# http://wiki.bash-hackers.org/snipplets/print_horizontal_line
info_sep() { printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' - ; }
banner() { info_sep; printf '%s...\n' "${1}"; info_sep; }
error() { zenity --warning --text="ERROR: ${1}"; }

verify_environment() {
    banner "Check if Steam is running"
    if [[ ! -z $(ps -o pid --no-headers -C steamwebhelper) ]]; then
        error "Please close Steam and run again."
        exit 1
    fi
    banner "Create ${TMP_DIR} for staging files"
    [[ -d ${TMP_DIR} ]] || mkdir ${TMP_DIR}
}
install_mod() {
    local mod url

    # OBSE
    banner "Downloading OBSE"
    mod='obse_0021.zip'
    url="http://obse.silverlock.org/download/${mod}"
    curl  ${url} -o ${TMP_DIR}/${mod}
    unzip "${TMP_DIR}/${mod}" -d "${TMP_DIR}"

    # Vanilla NorthernUIAway
    banner "Downloading Vanilla NorthernUIAway"
    mod='NorthernUIAway-Vanilla.zip'
    url="https://raw.githubusercontent.com/dotfil/ezdeck/main/oblivion/${mod}"
    curl  ${url} -o ${TMP_DIR}/${mod}
    unzip "${TMP_DIR}/${mod}" -d "${TMP_DIR}/Data"

    banner "Installing mods"
    cp -rf "${TMP_DIR}/obse_1_2_416.dll" \
            "${TMP_DIR}/obse_editor_1_2.dll" \
            "${TMP_DIR}/obse_steam_loader.dll" \
            "${TMP_DIR}/obse_loader.exe" \
            "${TMP_DIR}/Data" \
            "${GAME_DIR}"
}
configure_mod() {
    # Increase cursor speed in map to be more like Xbox value
    sed -E 's/(fMapMenuPanSpeed=[ ]+)[0-9.]+/\19.0000/' \
            -i "${GAME_DIR}/Data/OBSE/Plugins/NorthernUI.ini"

    # Increase analog stick sensitivity
    if [[ -f "${CONF_DIR}/NorthernUI.ctrl.txt" ]]; then
        banner "Setting sensitivity in config file"
        sed -Ei 's/(fSensitivity[XY]=)[0-9.]+/\13.5/' \
                "${CONF_DIR}/NorthernUI.ctrl.txt"
    else
        tee "${CONF_DIR}/NorthernUI.ctrl.txt" <<-EOF
			Version=0x02000300
			bSwapSticksGameplay=0
			bSwapSticksMenuMode=0
			fSensitivityX=3.500000
			fSensitivityY=3.500000
			iSensitivityRun=95
			sUseSchemeName=
		EOF
    fi
}
select_local_config() {
    local -a conf
    local -i id index
    local user select

    # Determine if multiple localconfig.vdf files exist
    readarray -t conf < <(find ${STEAM_PATH}/../userdata/*/config \
            -type f -name "localconfig.vdf")

    if [[ ${#conf[@]} -gt 1 ]]; then
        banner "$(printf '%s%s\n' \
                "${#conf[@]} IDs found. Select which will be used for " \
                "Oblivion launch command modification.")"

        for ((i = 0 ; i < ${#conf[@]}; i++)); do
            id=$(sed -E 's;^.*userdata/(.*)/config.*;\1;' <<< "${conf[$i]}")
            user=$(sed -En 's/^.*"PersonaName"[ \t]+"(.*)"/\1/p' "${conf[$i]}")
            printf "%s %u %s\n" "$((${i}+1))" "${id}" "${user}"
        done
        info_sep
        read -r -p "Selection: " -i "1" -e select
    else
        banner "Found ${#conf[@]} localconfig.vdf file"
        select=1
    fi

    # Use selected localconfig.vdf or restart if bad value was entered
    if [[ ${select} =~ ^[0-9]+$ ]] && [[ ${select} -le ${#conf[@]} ]] \
            && [[ ${select} -gt 0 ]]; then
        index=$((${select}-1))
        banner "$(basename ${conf[${index}]}) (${select}) has been selected."
    else
        error 'Invalid value. Enter number corresponding to account.'
        select_local_config
    fi

    # Return path to selected localconfig.vdf
    LOCAL_CONFIG="${conf[${index}]}"
}
# Edit the Oblivion launch command to use obse_loader rather than the default
# OblivionLauncher. This can supposedly be accomplished by renaming
# obse_loader.exe to OblivionLauncher.exe in the Oblivion directory, however I
# was unable to get that working. This method is preferred anyway as the default
# launcher is preserved and the user can return to vanilla by simply clearing
# the launch command.
#
# The following is the launch command being used:
#   eval $(sed 's/OblivionLauncher.exe/obse_loader.exe/g' <<< "%command%")
edit_launch_command() {
    banner "Launch command will be written in ${LOCAL_CONFIG}"

    # Find Steam apps section to discover where to search for app ID
    readarray lines < <(sed '/Software/,/apps/!d;=' ${LOCAL_CONFIG})
    if [[ ${lines[5]} =~ '"Valve"' ]] && [[ ${lines[9]} =~ '"Steam"' ]] \
            && [[ ${#lines[@]} -eq 14 ]]; then
        banner 'Located Steam Apps'
    else
        error "Unable to locate Steam apps in ${LOCAL_CONFIG}. Exiting..."
        exit 1
    fi

    # Store the line number for app ID block start range in $start
    local -i start=${lines[12]}
    start=$(sed -n "${start},/\"${APP_ID}\"/!d;=" ${LOCAL_CONFIG} | tail -n 1)
    # Find matching curly brace to determine line number end of range for app ID
    local -a stack
    local -i end=$((( $(sed -n "${start},\$p;=" ${LOCAL_CONFIG} \
            | while read char; do
                if [[ ${char} == '{' ]]; then
                    stack+=('{')
                elif [[ ${char} == '}' ]] && [[ ${#stack[@]} -gt 0 ]]; then
                    unset stack[${#stack[@]}-1]
                    [[ $((${#stack[@]})) -eq 0 ]] && break
                fi
                printf '%s\n' ${char}
            done \
            | tail -n 1) \
            + 1 )))

    local results=$(sed -n "${start},${end}p" ${LOCAL_CONFIG})
    # Sometimes "LaunchOptions" won't exist and needs to be created
    if [[ ! -z $(grep -o 'LaunchOptions' <<< "${results}") ]]; then
        sed -Ei \
        "${start},${end}s;(LaunchOptions\"[\t]+\").*(\"$);\1${LAUNCH_CMD}\2;" \
                "${LOCAL_CONFIG}"
    else
        # Duplicate end line to use as insertion point for LaunchOptions
        cat <(head -n${end} ${LOCAL_CONFIG}) <(tail -n+${end} ${LOCAL_CONFIG}) \
                > ${TMP_DIR}/tmp_local_config.vdf
        sed -Ei "${end}s;};\t\"LaunchOptions\"\t\t\"${LAUNCH_CMD}\";" \
                ${TMP_DIR}/tmp_local_config.vdf

        mv ${TMP_DIR}/tmp_local_config.vdf ${LOCAL_CONFIG}
    fi
    # Double quotes need to be escaped in localconfig.vdf
    sed -Ei "${start},${end}s;\"%command%;\\\\&\\\\;" "${LOCAL_CONFIG}"
}
# OBSE Steam version on Linux fix
# reddit.com/r/linux_gaming/comments/e794nb/oblivion_obse_for_steam_proton/
obse_fix() {
    # only patch obse_loader.exe as OblivionLauncher.exe is bypassed with new
    # launch command
    printf '\x90\x90\x90' \
            | dd conv=notrunc \
            of=${GAME_DIR}/obse_loader.exe \
            bs=1 \
            seek=$((0x14cb)) 
}
clean_environment() {
    rm -Rf "${TMP_DIR}"
}
main() {
    verify_environment
    install_mod
    configure_mod
    select_local_config
    edit_launch_command
    obse_fix
    clean_environment
}
main
