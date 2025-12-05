#!/bin/bash
#
# Phoniebox Optimierte Installation
# Für Raspberry Pi 3B mit Raspberry Pi OS Bookworm/Bullseye
#
# Verwendung:
#   wget -O install.sh https://raw.githubusercontent.com/.../install-optimized.sh
#   chmod +x install.sh
#   ./install.sh
#

set -e

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
    lighttpd php-common php-cgi php \
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
    tar unzip wget

# Raspberry Pi spezifische Pakete
if [ -f /etc/rpi-issue ]; then
    sudo apt install -y raspberrypi-kernel-headers || true
fi

log_success "System-Pakete installiert"

# Repository klonen oder aktualisieren
log_info "Lade Phoniebox-Code..."
if [ -d "$INSTALL_DIR/.git" ]; then
    cd "$INSTALL_DIR"
    git pull
else
    git clone --depth 1 https://github.com/MiczFlor/RPi-Jukebox-RFID.git "$INSTALL_DIR"
fi
cd "$INSTALL_DIR"
log_success "Code geladen"

# Python Virtual Environment
log_info "Richte Python-Umgebung ein..."
python3 -m venv "$HOME_DIR/.venv/phoniebox"
source "$HOME_DIR/.venv/phoniebox/bin/activate"

pip install --upgrade pip
pip install -r requirements.txt
pip install -r requirements-GPIO.txt

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
sudo lighttpd-enable-mod fastcgi 2>/dev/null || true
sudo lighttpd-enable-mod fastcgi-php 2>/dev/null || true

# Lighttpd Konfiguration
sudo tee /etc/lighttpd/conf-available/15-phoniebox.conf > /dev/null << EOF
server.document-root = "$INSTALL_DIR/htdocs"

# PHP FastCGI
fastcgi.server = ( ".php" => ((
    "bin-path" => "/usr/bin/php-cgi",
    "socket" => "/var/run/lighttpd/php.socket",
    "max-procs" => 1,
    "bin-environment" => (
        "PHP_FCGI_CHILDREN" => "4",
        "PHP_FCGI_MAX_REQUESTS" => "10000"
    ),
    "bin-copy-environment" => (
        "PATH", "SHELL", "USER"
    ),
    "broken-scriptfilename" => "enable"
)))
EOF

sudo ln -sf /etc/lighttpd/conf-available/15-phoniebox.conf /etc/lighttpd/conf-enabled/
sudo systemctl restart lighttpd
log_success "Webserver konfiguriert"

# MPD konfigurieren
log_info "Konfiguriere MPD..."
sudo mkdir -p /var/lib/mpd/music
sudo ln -sf "$SHARED_DIR/audiofolders" /var/lib/mpd/music/audiofolders 2>/dev/null || true

# MPD Konfiguration anpassen
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

sudo systemctl restart mpd
mpc update --wait
log_success "MPD konfiguriert"

# Skripte ausführbar machen
log_info "Setze Berechtigungen..."
chmod +x "$INSTALL_DIR/scripts/"*.sh
chmod +x "$INSTALL_DIR/scripts/"*.py

sudo chown -R "$USER":www-data "$INSTALL_DIR/htdocs"
sudo chmod -R 775 "$INSTALL_DIR/htdocs"
sudo chown -R "$USER":www-data "$SETTINGS_DIR"
sudo chmod -R 775 "$SETTINGS_DIR"
sudo chown -R "$USER":www-data "$SHARED_DIR"
sudo chmod -R 775 "$SHARED_DIR"
sudo chown -R "$USER":www-data "$INSTALL_DIR/logs"
sudo chmod -R 777 "$INSTALL_DIR/logs"
log_success "Berechtigungen gesetzt"

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
# GPIO Service nur aktivieren, wenn eine Konfiguration existiert
if [ -f "$SETTINGS_DIR/gpio_settings.ini" ]; then
    sudo systemctl enable phoniebox-gpio-control.service
fi

log_success "Systemd-Services eingerichtet"

# Samba konfigurieren
log_info "Konfiguriere Samba..."
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

sudo systemctl restart smbd
log_success "Samba konfiguriert"

# Standard-Konfigurationsdateien erstellen
log_info "Erstelle Konfigurationsdateien..."

# Settings initialisieren
echo "FALSE" > "$SETTINGS_DIR/Second_Swipe_Pause" 2>/dev/null || true
echo "OFF" > "$SETTINGS_DIR/Second_Swipe_Pause_Controls" 2>/dev/null || true
echo "SWIPENOTPLACE" > "$SETTINGS_DIR/Swipe_or_Place" 2>/dev/null || true
echo "100" > "$SETTINGS_DIR/Max_Volume_Limit" 2>/dev/null || true
echo "30" > "$SETTINGS_DIR/Startup_Volume" 2>/dev/null || true
echo "0" > "$SETTINGS_DIR/Volume_Boot" 2>/dev/null || true
echo "3" > "$SETTINGS_DIR/Audio_Volume_Change_Step" 2>/dev/null || true
echo "0" > "$SETTINGS_DIR/Idle_Time_Before_Shutdown" 2>/dev/null || true
echo "$SHARED_DIR/audiofolders" > "$SETTINGS_DIR/Audio_Folders_Path" 2>/dev/null || true
echo "/var/lib/mpd/playlists" > "$SETTINGS_DIR/Playlists_Folders_Path" 2>/dev/null || true

# Global config generieren
cd "$INSTALL_DIR/scripts"
./inc.writeGlobalConfig.sh
log_success "Konfigurationsdateien erstellt"

# Startup-Skript einrichten
log_info "Richte Autostart ein..."
sudo tee /etc/rc.local > /dev/null << EOF
#!/bin/sh -e
# Phoniebox Startup
$INSTALL_DIR/scripts/startup-scripts.sh &
exit 0
EOF
sudo chmod +x /etc/rc.local
log_success "Autostart eingerichtet"

# Services starten
log_info "Starte Services..."
sudo systemctl start phoniebox-rfid-reader.service
sudo systemctl start phoniebox-idle-watchdog.service
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
echo "   http://phoniebox.local"
echo "   http://$IP_ADDR"
echo ""
echo "📁 Audio-Dateien ablegen in:"
echo "   $SHARED_DIR/audiofolders"
echo "   Oder über Samba: \\\\phoniebox\\phoniebox"
echo ""
echo "📖 Anleitung: $INSTALL_DIR/INSTALL-Pi3B.md"
echo ""
echo "⚠️  Ein Neustart wird empfohlen:"
echo "   sudo reboot"
echo ""

