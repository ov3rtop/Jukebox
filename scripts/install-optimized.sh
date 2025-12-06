#!/bin/bash
#
# Phoniebox Optimierte Installation
# Für Raspberry Pi 3B mit Raspberry Pi OS Bookworm/Bullseye
#
# Verwendung:
#   ./install-optimized.sh
#

# Nicht bei Fehler sofort abbrechen (wir behandeln Fehler manuell)
# set -e

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Banner
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║     🎵  PHONIEBOX - Optimierte Installation  🎵              ║"
echo "║                                                               ║"
echo "║     Version: 2.9.x (optimiert)                               ║"
echo "║     Für: Raspberry Pi 3B                                      ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Root-Check
if [[ $EUID -eq 0 ]]; then
    log_error "Bitte NICHT als root ausführen!"
    log_info "Verwende: ./install-optimized.sh"
    exit 1
fi

# Pfade
HOME_DIR="$HOME"
INSTALL_DIR="$HOME_DIR/RPi-Jukebox-RFID"
SHARED_DIR="$INSTALL_DIR/shared"
SETTINGS_DIR="$INSTALL_DIR/settings"

# Prüfe ob bereits installiert
if [ -d "$INSTALL_DIR" ]; then
    log_warn "Phoniebox ist bereits installiert in: $INSTALL_DIR"
    read -p "Trotzdem fortfahren? (j/N): " confirm
    if [[ ! "$confirm" =~ ^[jJyY]$ ]]; then
        exit 0
    fi
fi

# System-Update
log_info "System wird aktualisiert..."
sudo apt update
sudo apt upgrade -y
log_success "System aktualisiert"

# Pakete installieren
log_info "Installiere System-Pakete..."
sudo apt install -y \
    samba samba-common-bin \
    gcc \
    lighttpd php-fpm php-cgi php \
    at \
    mpd mpc mpg123 \
    git \
    ffmpeg \
    spi-tools \
    netcat-traditional \
    alsa-utils \
    lsof procps \
    python3 python3-dev python3-pip python3-venv \
    python3-setuptools python3-wheel python3-mutagen python3-spidev \
    swig \
    tar unzip wget || log_warn "Einige Pakete konnten nicht installiert werden"

# Raspberry Pi spezifische Pakete (optional, nicht kritisch)
if [ -f /etc/rpi-issue ] || grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
    log_info "Raspberry Pi erkannt, installiere spezifische Pakete..."
    sudo apt install -y raspberrypi-kernel-headers 2>/dev/null || log_warn "raspberrypi-kernel-headers nicht verfügbar (nicht kritisch)"
fi

log_success "System-Pakete installiert"

# Repository klonen oder aktualisieren
log_info "Lade Phoniebox-Code..."
if [ -d "$INSTALL_DIR/.git" ]; then
    cd "$INSTALL_DIR"
    git pull || log_warn "Git pull fehlgeschlagen"
else
    git clone --depth 1 https://github.com/MiczFlor/RPi-Jukebox-RFID.git "$INSTALL_DIR" || {
        log_error "Git clone fehlgeschlagen"
        exit 1
    }
fi
cd "$INSTALL_DIR"
log_success "Code geladen"

# Python Virtual Environment
log_info "Richte Python-Umgebung ein..."
python3 -m venv "$HOME_DIR/.venv/phoniebox"
source "$HOME_DIR/.venv/phoniebox/bin/activate"

pip install --upgrade pip
pip install -r requirements.txt || log_warn "Einige Python-Pakete konnten nicht installiert werden"
pip install -r requirements-GPIO.txt || log_warn "GPIO-Pakete konnten nicht installiert werden"

log_success "Python-Umgebung eingerichtet"

# Verzeichnisse erstellen
log_info "Erstelle Verzeichnisse..."
mkdir -p "$SHARED_DIR/audiofolders"
mkdir -p "$SHARED_DIR/shortcuts"
mkdir -p "$INSTALL_DIR/logs"
touch "$INSTALL_DIR/logs/debug.log"
log_success "Verzeichnisse erstellt"

# Lighttpd konfigurieren
log_info "Konfiguriere Webserver..."

# PHP-Version ermitteln
PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;" 2>/dev/null || echo "8.2")
log_info "PHP Version: $PHP_VERSION"

# Stoppe lighttpd während der Konfiguration
sudo systemctl stop lighttpd 2>/dev/null || true

# Alte Phoniebox-Konfiguration entfernen falls vorhanden
sudo rm -f /etc/lighttpd/conf-enabled/15-phoniebox.conf 2>/dev/null || true
sudo rm -f /etc/lighttpd/conf-available/15-phoniebox.conf 2>/dev/null || true

# Backup der originalen Konfiguration
if [ ! -f /etc/lighttpd/lighttpd.conf.backup ]; then
    sudo cp /etc/lighttpd/lighttpd.conf /etc/lighttpd/lighttpd.conf.backup
fi

# Lighttpd Hauptkonfiguration erstellen
sudo tee /etc/lighttpd/lighttpd.conf > /dev/null << EOF
# Phoniebox Lighttpd Konfiguration
server.modules = (
    "mod_indexfile",
    "mod_access",
    "mod_alias",
    "mod_redirect",
)

server.document-root        = "$INSTALL_DIR/htdocs"
server.upload-dirs          = ( "/var/cache/lighttpd/uploads" )
server.errorlog             = "/var/log/lighttpd/error.log"
server.pid-file             = "/run/lighttpd.pid"
server.username             = "www-data"
server.groupname            = "www-data"
server.port                 = 80

# Zugriff auf versteckte Dateien verweigern
url.access-deny             = ( "~", ".inc" )

# Index-Dateien
index-file.names            = ( "index.php", "index.html" )

# MIME-Types
include_shell "/usr/share/lighttpd/create-mime.conf.pl"

# Module für FastCGI
server.modules += ( "mod_fastcgi" )

# PHP über FastCGI (PHP-FPM)
fastcgi.server = ( ".php" => ((
    "socket" => "/run/php/php${PHP_VERSION}-fpm.sock",
    "broken-scriptfilename" => "enable"
)))
EOF

# PHP-FPM Konfiguration anpassen
PHP_FPM_CONF="/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf"
if [ -f "$PHP_FPM_CONF" ]; then
    # Stelle sicher, dass der Socket existiert
    sudo sed -i 's/^listen = .*/listen = \/run\/php\/php'"${PHP_VERSION}"'-fpm.sock/' "$PHP_FPM_CONF"
    sudo sed -i 's/^;listen.owner = .*/listen.owner = www-data/' "$PHP_FPM_CONF"
    sudo sed -i 's/^;listen.group = .*/listen.group = www-data/' "$PHP_FPM_CONF"
    sudo sed -i 's/^;listen.mode = .*/listen.mode = 0660/' "$PHP_FPM_CONF"
fi

# Upload-Verzeichnis erstellen
sudo mkdir -p /var/cache/lighttpd/uploads
sudo chown www-data:www-data /var/cache/lighttpd/uploads

# PHP-FPM neu starten
sudo systemctl restart php${PHP_VERSION}-fpm 2>/dev/null || sudo systemctl restart php-fpm 2>/dev/null || log_warn "PHP-FPM konnte nicht gestartet werden"

# Lighttpd aktivieren und starten
sudo systemctl enable lighttpd
sudo systemctl start lighttpd
if sudo systemctl is-active --quiet lighttpd; then
    log_success "Webserver konfiguriert und gestartet"
else
    log_error "Webserver konnte nicht gestartet werden!"
    log_info "Prüfe Logs mit: sudo journalctl -xeu lighttpd.service"
    log_info "Und: sudo lighttpd -t -f /etc/lighttpd/lighttpd.conf"
fi

# PHP-FPM aktivieren
sudo systemctl enable php${PHP_VERSION}-fpm 2>/dev/null || sudo systemctl enable php-fpm 2>/dev/null || true

# MPD konfigurieren
log_info "Konfiguriere MPD..."
sudo mkdir -p /var/lib/mpd/music
sudo mkdir -p /var/lib/mpd/playlists
sudo ln -sf "$SHARED_DIR/audiofolders" /var/lib/mpd/music/audiofolders 2>/dev/null || true

# MPD Konfiguration
sudo tee /etc/mpd.conf > /dev/null << 'EOF'
music_directory     "/var/lib/mpd/music"
playlist_directory  "/var/lib/mpd/playlists"
db_file             "/var/lib/mpd/tag_cache"
log_file            "/var/log/mpd/mpd.log"
pid_file            "/run/mpd/pid"
state_file          "/var/lib/mpd/state"
sticker_file        "/var/lib/mpd/sticker.sql"

user                "mpd"
bind_to_address     "localhost"
port                "6600"

auto_update         "yes"
follow_outside_symlinks "yes"
follow_inside_symlinks  "yes"

input {
    plugin "curl"
}

audio_output {
    type        "alsa"
    name        "ALSA"
    mixer_type  "software"
}

filesystem_charset  "UTF-8"
EOF

# MPD-Verzeichnisse Berechtigungen
sudo mkdir -p /var/log/mpd
sudo mkdir -p /run/mpd
sudo chown -R mpd:audio /var/lib/mpd
sudo chown -R mpd:audio /var/log/mpd

# MPD für Autostart aktivieren und starten
sudo systemctl enable mpd
sudo systemctl restart mpd

# Warten bis MPD bereit ist und Datenbank aktualisieren
sleep 2
mpc update --wait 2>/dev/null || true
log_success "MPD konfiguriert und aktiviert"

# Skripte ausführbar machen
log_info "Setze Berechtigungen..."
chmod +x "$INSTALL_DIR/scripts/"*.sh 2>/dev/null || true
chmod +x "$INSTALL_DIR/scripts/"*.py 2>/dev/null || true

# WICHTIG: Home-Verzeichnis muss für www-data lesbar sein!
chmod 755 "$HOME_DIR"

sudo chown -R "$USER":www-data "$INSTALL_DIR/htdocs"
sudo chmod -R 775 "$INSTALL_DIR/htdocs"
sudo chown -R "$USER":www-data "$SETTINGS_DIR"
sudo chmod -R 775 "$SETTINGS_DIR"
sudo chown -R "$USER":www-data "$SHARED_DIR"
sudo chmod -R 775 "$SHARED_DIR"
sudo chown -R "$USER":www-data "$INSTALL_DIR/logs"
sudo chmod -R 777 "$INSTALL_DIR/logs"

# www-data und mpd Benutzer zur Gruppe des aktuellen Users hinzufügen
sudo usermod -a -G "$USER" www-data 2>/dev/null || true
sudo usermod -a -G "$USER" mpd 2>/dev/null || true
sudo usermod -a -G www-data mpd 2>/dev/null || true

log_success "Berechtigungen gesetzt"

# Sudoers-Konfiguration für www-data (WICHTIG für Web-Interface!)
log_info "Konfiguriere sudo-Berechtigungen für www-data..."
sudo tee /etc/sudoers.d/www-data > /dev/null << 'EOF'
# Phoniebox - www-data darf Scripts ohne Passwort ausführen
www-data ALL=(ALL) NOPASSWD: ALL
EOF
sudo chmod 440 /etc/sudoers.d/www-data
log_success "Sudo-Berechtigungen konfiguriert"

# Systemd-Services einrichten
log_info "Richte Systemd-Services ein..."

# RFID Reader Service
sudo tee /etc/systemd/system/phoniebox-rfid-reader.service > /dev/null << EOF
[Unit]
Description=Phoniebox RFID Reader
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR/scripts
Environment="PATH=$HOME_DIR/.venv/phoniebox/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=$HOME_DIR/.venv/phoniebox/bin/python3 $INSTALL_DIR/scripts/daemon_rfid_reader.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# GPIO Control Service
sudo tee /etc/systemd/system/phoniebox-gpio-control.service > /dev/null << EOF
[Unit]
Description=Phoniebox GPIO Control
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR/components/gpio_control
Environment="PATH=$HOME_DIR/.venv/phoniebox/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=$HOME_DIR/.venv/phoniebox/bin/python3 $INSTALL_DIR/components/gpio_control/gpio_control.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Idle Watchdog Service
sudo tee /etc/systemd/system/phoniebox-idle-watchdog.service > /dev/null << EOF
[Unit]
Description=Phoniebox Idle Watchdog
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR/scripts
ExecStart=$INSTALL_DIR/scripts/idle-watchdog.sh
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable phoniebox-rfid-reader.service
sudo systemctl enable phoniebox-idle-watchdog.service

log_success "Systemd-Services eingerichtet"

# Samba konfigurieren
log_info "Konfiguriere Samba..."

# Prüfe ob Phoniebox-Share bereits existiert
if ! grep -q "\[phoniebox\]" /etc/samba/smb.conf 2>/dev/null; then
    sudo tee -a /etc/samba/smb.conf > /dev/null << EOF

[phoniebox]
   comment = Phoniebox
   path = $SHARED_DIR
   browseable = yes
   read only = no
   guest ok = yes
   create mask = 0775
   directory mask = 0775
   force user = $USER
   force group = www-data
EOF
fi

sudo systemctl restart smbd 2>/dev/null || sudo systemctl restart smb 2>/dev/null || log_warn "Samba konnte nicht gestartet werden"
log_success "Samba konfiguriert"

# Standard-Konfigurationsdateien erstellen
log_info "Erstelle Konfigurationsdateien..."

# Settings-Verzeichnis sicherstellen
mkdir -p "$SETTINGS_DIR"

# Settings initialisieren
echo "FALSE" > "$SETTINGS_DIR/Second_Swipe_Pause"
echo "OFF" > "$SETTINGS_DIR/Second_Swipe_Pause_Controls"
echo "SWIPENOTPLACE" > "$SETTINGS_DIR/Swipe_or_Place"
echo "100" > "$SETTINGS_DIR/Max_Volume_Limit"
echo "30" > "$SETTINGS_DIR/Startup_Volume"
echo "0" > "$SETTINGS_DIR/Volume_Boot"
echo "3" > "$SETTINGS_DIR/Audio_Volume_Change_Step"
echo "0" > "$SETTINGS_DIR/Idle_Time_Before_Shutdown"
echo "$SHARED_DIR/audiofolders" > "$SETTINGS_DIR/Audio_Folders_Path"
echo "/var/lib/mpd/playlists" > "$SETTINGS_DIR/Playlists_Folders_Path"

# Wichtige Dateien die oft fehlen
echo "classic" > "$SETTINGS_DIR/edition"
echo "2.9.0" > "$SETTINGS_DIR/version"
echo "" > "$SETTINGS_DIR/Latest_Folder_Played"
echo "OFF" > "$SETTINGS_DIR/ShowCover"
echo "de-DE" > "$SETTINGS_DIR/Lang"
echo "RESTART" > "$SETTINGS_DIR/Second_Swipe"
echo "PCM" > "$SETTINGS_DIR/Audio_iFace_Name"
echo "0" > "$SETTINGS_DIR/Audio_iFace_Active"
echo "mpd" > "$SETTINGS_DIR/Audio_Volume_Manager"
echo "OFF" > "$SETTINGS_DIR/Rfidreader_RC522_ReadMode_UID"
echo "OFF" > "$SETTINGS_DIR/WlanIpReadYN"
echo "OFF" > "$SETTINGS_DIR/MailWlanIpYN"
echo "" > "$SETTINGS_DIR/WlanIpMailAddr"

# Debug-Logging Konfiguration
cat > "$SETTINGS_DIR/debugLogging.conf" << 'DEBUGEOF'
DEBUG_WebApp="FALSE"
DEBUG_WebApp_API="FALSE"
DEBUG_playout_controls_sh="FALSE"
DEBUG_rfid_trigger_play_sh="FALSE"
DEBUG_inc_readNFCchip_sh="FALSE"
DEBUG_daemon_rfid_reader_py="FALSE"
DEBUG_gpio_buttons_py="FALSE"
DEBUG_inc_writeGlobalConfig_sh="FALSE"
DEBUGEOF

# RFID Trigger Play Konfiguration (falls nicht vorhanden)
if [ ! -f "$SETTINGS_DIR/rfid_trigger_play.conf" ]; then
    cat > "$SETTINGS_DIR/rfid_trigger_play.conf" << 'RFIDEOF'
# RFID Trigger Play Configuration
AUDIOFOLDERSPATH="ACTIVE_AUDIOFOLDERSPATH"
PLAYERSTOP="ACTIVE_PLAYERSTOP"
PLAYSINGLE="ACTIVE_PLAYSINGLE"
PLAYLISTADD="ACTIVE_PLAYLISTADD"
PLAYLISTADDPLAY="ACTIVE_PLAYLISTADDPLAY"
VOLUME="ACTIVE_VOLUME"
RFIDEOF
fi

# Berechtigungen für Settings setzen
sudo chown -R "$USER":www-data "$SETTINGS_DIR"
sudo chmod -R 775 "$SETTINGS_DIR"
chmod 777 "$SETTINGS_DIR/Latest_Folder_Played"

# Global config generieren
cd "$INSTALL_DIR/scripts"
if [ -f "./inc.writeGlobalConfig.sh" ]; then
    chmod +x ./inc.writeGlobalConfig.sh
    ./inc.writeGlobalConfig.sh 2>/dev/null || log_warn "Global config konnte nicht erstellt werden"
fi
log_success "Konfigurationsdateien erstellt"

# Startup-Skript einrichten (optional)
log_info "Richte Autostart ein..."
if [ -f /etc/rc.local ]; then
    # Prüfe ob bereits eingetragen
    if ! grep -q "startup-scripts.sh" /etc/rc.local 2>/dev/null; then
        sudo sed -i "/^exit 0/i $INSTALL_DIR/scripts/startup-scripts.sh &" /etc/rc.local 2>/dev/null || true
    fi
else
    sudo tee /etc/rc.local > /dev/null << EOF
#!/bin/sh -e
# Phoniebox Startup
$INSTALL_DIR/scripts/startup-scripts.sh &
exit 0
EOF
    sudo chmod +x /etc/rc.local
fi
log_success "Autostart eingerichtet"

# Services starten
log_info "Starte Services..."
sudo systemctl start phoniebox-rfid-reader.service 2>/dev/null || log_warn "RFID-Service konnte nicht gestartet werden (evtl. kein Reader angeschlossen)"
sudo systemctl start phoniebox-idle-watchdog.service 2>/dev/null || log_warn "Idle-Watchdog konnte nicht gestartet werden"
log_success "Services gestartet"

# IP-Adresse ermitteln
IP_ADDR=$(hostname -I | awk '{print $1}')

# Abschluss
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║     ✅  INSTALLATION ABGESCHLOSSEN!                          ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "📍 Web-Interface erreichbar unter:"
echo "   http://$(hostname).local"
echo "   http://$IP_ADDR"
echo ""
echo "📁 Audio-Dateien ablegen in:"
echo "   $SHARED_DIR/audiofolders"
echo "   Oder über Samba: \\\\$(hostname)\\phoniebox"
echo ""
echo "📖 Anleitung: $INSTALL_DIR/INSTALL-Pi3B.md"
echo ""
echo "🔧 Bei Problemen:"
echo "   sudo systemctl status lighttpd"
echo "   sudo systemctl status php${PHP_VERSION}-fpm"
echo "   sudo journalctl -xeu lighttpd.service"
echo ""
echo "⚠️  Ein Neustart wird empfohlen:"
echo "   sudo reboot"
echo ""
