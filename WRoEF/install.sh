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
# install.sh - Fix Edith Finch aspect ratio on 16:10 display
################################################################################

error() { zenity --warning --text="ERROR: ${1}"; }

readonly STEAM_PATH="${HOME}/.local/share/Steam/steamapps"
readonly SD_CARD=$(lsblk --output MOUNTPOINT | grep -Eo '^.*mmcblk[0-9]p1')
readonly SD_STEAM_PATH="${SD_CARD}/steamapps"

readonly GAME='EdithFinch'
readonly APP_ID='501300'

# Use the storage the game is installed on
if [[ -d "${STEAM_PATH}/common/${GAME}" ]]; then
    readonly GAME_DIR="${STEAM_PATH}/common/${GAME}"
elif [[ -d "${SD_STEAM_PATH}/common/${GAME}" ]]; then
    readonly GAME_DIR="${SD_STEAM_PATH}/common/${GAME}"
else
    error "${GAME} must first be installed"
    exit 1
fi

readonly BIN_DIR="${GAME_DIR}/FinchGame/Binaries/Win64"
readonly C_DRIVE="${STEAM_PATH}/compatdata/${APP_ID}/pfx/drive_c"
readonly APP_DATA="${C_DRIVE}/users/steamuser/AppData/Local"
readonly CONF_DIR="${APP_DATA}/FinchGame/Saved/Config/WindowsNoEditor"
readonly TMP_DIR="/tmp/ez_${GAME}"

# http://wiki.bash-hackers.org/snipplets/print_horizontal_line
info_sep() { printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' - ; }
banner() { info_sep; printf '%s...\n' "${1}"; info_sep; }

verify_environment() {
    # Directory for staging files
    [[ -d ${TMP_DIR} ]] || mkdir ${TMP_DIR}
}
configure_mod() {

    banner "Setting proper resolution in config file"
    sed -Ei 's/(ResolutionSizeX=)[0-9]+/\11280/' \
            "${CONF_DIR}/GameUserSettings.ini"
    sed -Ei 's/(ResolutionSizeY=)[0-9]+/\1800/' \
            "${CONF_DIR}/GameUserSettings.ini"
}
install_mod() {
    local time mod url
    banner "Backing up executable"
    time=$(date +%s)
    cp ${BIN_DIR}/FinchGame.exe ${BIN_DIR}/FinchGame_${time}.exe.bkp

    banner "Downloading new executable"
    mod='WRoEF_16x10.7z'
    url="https://raw.githubusercontent.com/dotfil/ezdeck/main/WRoEF/${mod}"
    wget  ${url} -P ${TMP_DIR}

    banner "Replacing executable"
    7z x -y "${TMP_DIR}/${mod}" -o"${BIN_DIR}"
}
clean_environment() {
    rm -Rf "${TMP_DIR}"
}
main() {
    verify_environment
    install_mod
    configure_mod
    clean_environment
}
main
