#!/usr/bin/env bash

# Auto-detect paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
JUKEBOX_HOME_DIR="$( cd "$SCRIPT_DIR/../../.." && pwd )"
BUTTONS_USB_ENCODER_DIR="${JUKEBOX_HOME_DIR}/components/controls/buttons_usb_encoder"
CURRENT_USER="${SUDO_USER:-$(whoami)}"
VENV_PATH="/home/${CURRENT_USER}/.venv/phoniebox"

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
printf "Please make sure that the Buttons USB Encoder and the buttons are connected before continuing...\n"
question "Continue"

# make files executable
sudo chmod +x "${BUTTONS_USB_ENCODER_DIR}"/register_buttons_usb_encoder.py
sudo chmod +x "${BUTTONS_USB_ENCODER_DIR}"/buttons_usb_encoder.py
sudo chmod +x "${BUTTONS_USB_ENCODER_DIR}"/map_buttons_usb_encoder.py

# choose buttons usb encoder device
"${BUTTONS_USB_ENCODER_DIR}"/register_buttons_usb_encoder.py

# setup buttons
"${BUTTONS_USB_ENCODER_DIR}"/map_buttons_usb_encoder.py

printf "\nStart phoniebox-buttons-usb-encoder service...\n"

# Create service file with correct paths
sudo tee /etc/systemd/system/phoniebox-buttons-usb-encoder.service > /dev/null << EOF
[Unit]
Description=Phoniebox Buttons USB Encoder
After=mpd.service

[Service]
User=${CURRENT_USER}
Group=${CURRENT_USER}
Restart=always
RestartSec=5
WorkingDirectory=${JUKEBOX_HOME_DIR}
ExecStart=${VENV_PATH}/bin/python3 ${BUTTONS_USB_ENCODER_DIR}/buttons_usb_encoder.py

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl start phoniebox-buttons-usb-encoder.service
sudo systemctl enable phoniebox-buttons-usb-encoder.service

printf "Done.\n"
