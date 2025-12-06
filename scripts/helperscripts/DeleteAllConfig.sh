#!/bin/bash

# Get the base directory dynamically
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$( cd "$SCRIPT_DIR/../.." && pwd )"

echo "This script will delete all config files"
echo "including mpd.conf and the like."
echo "Base directory: $BASE_DIR"
read -r -p "Do you want to proceed? [y/N] " response
case "$response" in
    [Yy][Ee][Ss]|[Yy])
        ;;
    *)
        echo "Exiting script."
        exit
        ;;
esac
echo "Proceeding and deleting."

sudo rm /etc/sudoers.d/www-data
sudo rm /etc/sudoers.d/mopidy

#sudo rm /etc/samba/smb.conf

# these ones we will leave
#sudo rm $BASE_DIR/htdocs/config.php
#sudo rm $BASE_DIR/settings/rfid_trigger_play.conf

# these ones we delete
sudo rm /etc/lighttpd/lighttpd.conf
sudo rm /etc/lighttpd/conf-available/15-fastcgi-php.conf
sudo rm /etc/php/*/fpm/php.ini 2>/dev/null
sudo rm $BASE_DIR/settings/Audio_iFace_Name
sudo rm $BASE_DIR/settings/Audio_Folders_Path
sudo rm $BASE_DIR/settings/Audio_Volume_Change_Step
sudo rm $BASE_DIR/settings/Max_Volume_Limit
sudo rm $BASE_DIR/settings/Idle_Time_Before_Shutdown
sudo rm $BASE_DIR/settings/Second_Swipe
sudo rm $BASE_DIR/settings/Playlists_Folders_Path
sudo rm $BASE_DIR/settings/ShowCover
sudo rm $BASE_DIR/scripts/gpio-buttons.py
sudo rm /etc/systemd/system/phoniebox-rfid-reader.service
sudo rm /etc/systemd/system/phoniebox-startup-sound.service
sudo rm /etc/systemd/system/phoniebox-gpio-buttons.service
sudo rm /etc/systemd/system/phoniebox-idle-watchdog.service
sudo rm /etc/systemd/system/rfid-reader.service
sudo rm /etc/systemd/system/startup-sound.service
sudo rm /etc/systemd/system/gpio-buttons.service
sudo rm /etc/systemd/system/idle-watchdog.service
sudo rm /etc/systemd/system/autohotspot.service
sudo rm /etc/mpd.conf
sudo rm /etc/locale.gen
sudo rm /etc/default/locale
sudo rm /etc/mopidy/mopidy.conf
