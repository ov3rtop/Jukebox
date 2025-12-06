#!/bin/bash

# Check all conf files copied and modified after installation script

# Get the base directory dynamically
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$( cd "$SCRIPT_DIR/../.." && pwd )"

echo "************************************"
echo "*** PHONIEBOX INFO"
echo "*** Base Directory: $BASE_DIR"
echo "*** version:" $(cat $BASE_DIR/settings/version 2>/dev/null || echo "not set")
echo "*** edition:" $(cat $BASE_DIR/settings/edition 2>/dev/null || echo "not set")
echo "*** Audio_iFace_Name:" $(cat $BASE_DIR/settings/Audio_iFace_Name 2>/dev/null || echo "not set")
echo "*** Audio_Folders_Path:" $(cat $BASE_DIR/settings/Audio_Folders_Path 2>/dev/null || echo "not set")
echo "*** Audio_Volume_Change_Step:" $(cat $BASE_DIR/settings/Audio_Volume_Change_Step 2>/dev/null || echo "not set")
echo "*** Max_Volume_Limit:" $(cat $BASE_DIR/settings/Max_Volume_Limit 2>/dev/null || echo "not set")
echo "*** Idle_Time_Before_Shutdown:" $(cat $BASE_DIR/settings/Idle_Time_Before_Shutdown 2>/dev/null || echo "not set")
echo "*** Second_Swipe:" $(cat $BASE_DIR/settings/Second_Swipe 2>/dev/null || echo "not set")
echo "*** Playlists_Folders_Path:" $(cat $BASE_DIR/settings/Playlists_Folders_Path 2>/dev/null || echo "not set")
echo "*** ShowCover:" $(cat $BASE_DIR/settings/ShowCover 2>/dev/null || echo "not set")

echo "************************************"
echo "*** CONF FILES DEFAULT"
echo " "

echo "*** /etc/samba/smb.conf"
ls -lh /etc/samba/smb.conf 2>/dev/null || echo "not found"
sudo cat /etc/samba/smb.conf 2>/dev/null | grep path=

echo "*** /etc/lighttpd/lighttpd.conf"
ls -lh /etc/lighttpd/lighttpd.conf 2>/dev/null || echo "not found"

echo "*** /etc/lighttpd/conf-available/15-fastcgi-php.conf"
ls -lh /etc/lighttpd/conf-available/15-fastcgi-php.conf 2>/dev/null || echo "not found"

echo "*** /etc/php/*/fpm/php.ini"
ls -lh /etc/php/*/fpm/php.ini 2>/dev/null || echo "not found"

echo "*** /etc/sudoers.d"
ls -lh /etc/sudoers.d/ 2>/dev/null || echo "not found"

echo "*** /etc/systemd/system/phoniebox*"
ls -lh /etc/systemd/system/phoniebox-*.service 2>/dev/null || echo "not found"

echo "*** /etc/mpd.conf"
ls -lh /etc/mpd.conf 2>/dev/null || echo "not found"
sudo cat /etc/mpd.conf 2>/dev/null | grep music_directory
sudo cat /etc/mpd.conf 2>/dev/null | grep mixer_control

echo "*** /etc/dhcpcd.conf"
ls -lh /etc/dhcpcd.conf 2>/dev/null || echo "not found"
sudo cat /etc/dhcpcd.conf 2>/dev/null | grep ip_address
sudo cat /etc/dhcpcd.conf 2>/dev/null | grep routers
sudo cat /etc/dhcpcd.conf 2>/dev/null | grep domain_name_servers

echo "*** /etc/wpa_supplicant/wpa_supplicant.conf"
ls -lh /etc/wpa_supplicant/wpa_supplicant.conf 2>/dev/null || echo "not found"
sudo cat /etc/wpa_supplicant/wpa_supplicant.conf 2>/dev/null | grep country=

echo "************************************"
echo "*** +Spotify Edition"
echo " "

echo "*** /etc/locale.gen"
ls -lh /etc/locale.gen 2>/dev/null || echo "not found"

echo "*** /etc/mopidy/mopidy.conf"
ls -lh /etc/mopidy/mopidy.conf 2>/dev/null || echo "not found"
sudo cat /etc/mopidy/mopidy.conf 2>/dev/null | grep username

echo "*** ~/.config/mopidy/mopidy.conf"
ls -lh ~/.config/mopidy/mopidy.conf 2>/dev/null || echo "not found"
cat ~/.config/mopidy/mopidy.conf 2>/dev/null | grep username

which mopidyctl >/dev/null 2>&1 && sudo mopidyctl deps

echo " "
