#!/usr/bin/env bash

# Auto-detect paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
JUKEBOX_HOME_DIR="$( cd "$SCRIPT_DIR/../../.." && pwd )"
CURRENT_USER="${SUDO_USER:-$(whoami)}"

question() {
    local question=$1
    read -p "${question} (Y/n)? " choice
    case "$choice" in
      [nN][oO]|[nN]) exit 0;;
      * ) ;;
    esac
}

printf "Phoniebox directory: %s\n" "$JUKEBOX_HOME_DIR"
printf "Current user: %s\n" "$CURRENT_USER"
printf "Please make sure that the RC522 reader is wired up correctly to the GPIO ports before continuing...\n"
question "Continue"

printf "Use backward-compatible card ID (not suggested for new installations)?\n"
read -p "(y/N) " choice
case "$choice" in
  y|Y ) printf "OFF" > "${JUKEBOX_HOME_DIR}"/settings/Rfidreader_Rc522_Readmode_UID;;
  * ) printf "ON" > "${JUKEBOX_HOME_DIR}"/settings/Rfidreader_Rc522_Readmode_UID;;
esac

printf "Installing Python requirements for RC522...\n"
sudo python3 -m pip install --upgrade --force-reinstall --no-deps -q -r "${JUKEBOX_HOME_DIR}"/components/rfid-reader/RC522/requirements.txt

printf "Activating SPI...\n"
sudo raspi-config nonint do_spi 0

printf "Configure RFID reader in Phoniebox...\n"
cp "${JUKEBOX_HOME_DIR}"/scripts/Reader.py.experimental "${JUKEBOX_HOME_DIR}"/scripts/Reader.py
printf "MFRC522" > "${JUKEBOX_HOME_DIR}"/scripts/deviceName.txt
sudo chown ${CURRENT_USER}:www-data "${JUKEBOX_HOME_DIR}"/scripts/deviceName.txt
sudo chmod 644 "${JUKEBOX_HOME_DIR}"/scripts/deviceName.txt

printf "Restarting phoniebox-rfid-reader service...\n"
sudo systemctl restart phoniebox-rfid-reader.service

printf "Done.\n"
