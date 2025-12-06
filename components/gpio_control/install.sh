#!/usr/bin/env bash

# Get the base directory dynamically
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$( cd "$SCRIPT_DIR/../.." && pwd )"
CURRENT_USER="${SUDO_USER:-$(whoami)}"

if [[ $(id -u) != 0 ]]; then
   echo "This script should be run using sudo"
   exit 1
fi

echo "Base directory: $BASE_DIR"
echo "Current user: $CURRENT_USER"

if [[ ! -f $BASE_DIR/settings/gpio_settings.ini ]]; then
    cp $BASE_DIR/misc/sampleconfigs/gpio_settings.ini.sample $BASE_DIR/settings/gpio_settings.ini
fi

echo 'disable old services: phoniebox-gpio-buttons and phoniebox-rotary-encoder'
systemctl stop phoniebox-rotary-encoder.service 2>/dev/null
systemctl disable phoniebox-rotary-encoder.service 2>/dev/null
systemctl stop phoniebox-gpio-buttons.service 2>/dev/null
systemctl disable phoniebox-gpio-buttons.service 2>/dev/null

echo 'Install all required python modules'
python3 -m pip install --upgrade --force-reinstall -r requirements.txt

echo
echo 'Installing GPIO_Control service'
read -p "Press enter to continue " -n 1 -r

SERVICE_FILE=/etc/systemd/system/phoniebox-gpio-control.service
if [[ -f "$SERVICE_FILE" ]]; then
   echo "$SERVICE_FILE exists.";
   echo 'systemctl daemon-reload'
   systemctl daemon-reload
   echo 'restarting service'
   systemctl restart phoniebox-gpio-control.service
   read -p "Press enter to continue " -n 1 -r;
else
    # Create service file with correct paths
    VENV_PATH="/home/$CURRENT_USER/.venv/phoniebox"
    cat > /etc/systemd/system/phoniebox-gpio-control.service << EOF
[Unit]
Description=Phoniebox GPIO Control
After=network.target

[Service]
Type=simple
User=$CURRENT_USER
Group=$CURRENT_USER
WorkingDirectory=$BASE_DIR/components/gpio_control/
ExecStart=$VENV_PATH/bin/python3 $BASE_DIR/components/gpio_control/gpio_control.py
SyslogIdentifier=PhonieboxGPIOControl
StandardOutput=syslog
StandardError=syslog
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    echo "systemctl start phoniebox-gpio-control.service"
    systemctl daemon-reload
    systemctl start phoniebox-gpio-control.service
    echo "systemctl enable phoniebox-gpio-control.service"
    systemctl enable phoniebox-gpio-control.service
fi

SERVICE_STATUS="$(systemctl is-active phoniebox-gpio-control.service)"
if [[ "${SERVICE_STATUS}" = "active" ]]; then
    echo "Phoniebox GPIO Service started correctly ....."
    echo "For further configuration of GPIO-devices consult the wiki:
https://github.com/MiczFlor/RPi-Jukebox-RFID/wiki/Using-GPIO-hardware-buttons"
else
    echo ""
    FRED="\033[31m"
    FBOLD='\033[1;31m'
    RS="\033[0m"
    echo -e "$FRED"$FBOLD"Problem during installation occured $RS"
    echo "   Service not running, please check functionallity by running gpio_control.py "
    echo "   in the directory $BASE_DIR/components/gpio_control: "
    echo "      $ cd $BASE_DIR/components/gpio_control"
    echo "      $ python gpio_control.py"
    echo "   or check output of journaclctl by:"
    echo "      $ journalctl -u phoniebox-gpio-control.service -f"
    exit 1
fi
