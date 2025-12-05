#!/bin/bash
#
# Phoniebox - Benutzer-Setup-Skript
# Passt alle Pfade von /home/pi auf den aktuellen Benutzer an
#
# Verwendung: ./setup-user.sh
#

set -e

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Aktueller Benutzer
CURRENT_USER=$(whoami)
CURRENT_HOME="$HOME"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║     Phoniebox - Benutzer-Anpassung                           ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Aktueller Benutzer: $CURRENT_USER"
echo "Home-Verzeichnis:   $CURRENT_HOME"
echo ""

read -p "Alle Pfade von /home/pi auf $CURRENT_HOME anpassen? (j/N): " confirm
if [[ ! "$confirm" =~ ^[jJyY]$ ]]; then
    echo "Abgebrochen."
    exit 0
fi

# Basis-Verzeichnis
INSTALL_DIR="$CURRENT_HOME/RPi-Jukebox-RFID"

if [ ! -d "$INSTALL_DIR" ]; then
    log_warn "Verzeichnis $INSTALL_DIR nicht gefunden!"
    exit 1
fi

cd "$INSTALL_DIR"

log_info "Ersetze /home/pi durch $CURRENT_HOME in allen Dateien..."

# Liste der Dateien, die angepasst werden sollen
FILES_TO_UPDATE=(
    "scripts/inc.writeGlobalConfig.sh"
    "scripts/playout_controls.sh"
    "scripts/rfid_trigger_play.sh"
    "scripts/startup-scripts.sh"
    "scripts/inc.writeFolderConfig.sh"
    "scripts/helperscripts/DeleteAllConfig.sh"
    "scripts/helperscripts/organizeFiles.py"
    "scripts/helperscripts/cli-player.py"
    "htdocs/config.php.sample"
    "components/gpio_control/gpio_control.py"
    "components/gpio_control/install.sh"
    "components/smart-home-automation/MQTT-protocol/daemon_mqtt_client.py"
)

for file in "${FILES_TO_UPDATE[@]}"; do
    if [ -f "$file" ]; then
        sed -i "s|/home/pi|$CURRENT_HOME|g" "$file"
        log_success "Angepasst: $file"
    fi
done

# Auch in den Sample-Configs
log_info "Passe Sample-Konfigurationen an..."
find misc/sampleconfigs -name "*.sample" -exec sed -i "s|/home/pi|$CURRENT_HOME|g" {} \; 2>/dev/null || true
find components -name "*.sample" -exec sed -i "s|/home/pi|$CURRENT_HOME|g" {} \; 2>/dev/null || true

# Ersetze auch "pi:www-data" durch "$USER:www-data" in Skripten
log_info "Passe Benutzer-Berechtigungen an..."
sed -i "s|chown.*pi:www-data|chown $CURRENT_USER:www-data|g" scripts/inc.writeGlobalConfig.sh 2>/dev/null || true
sed -i "s|chown.*pi:www-data|chown $CURRENT_USER:www-data|g" scripts/playout_controls.sh 2>/dev/null || true

# Settings-Dateien anpassen
log_info "Passe Settings an..."
if [ -f "settings/Audio_Folders_Path" ]; then
    sed -i "s|/home/pi|$CURRENT_HOME|g" settings/Audio_Folders_Path
fi

# config.php erstellen falls nicht vorhanden
if [ ! -f "htdocs/config.php" ] && [ -f "htdocs/config.php.sample" ]; then
    cp htdocs/config.php.sample htdocs/config.php
    sed -i "s|/home/pi|$CURRENT_HOME|g" htdocs/config.php
    log_success "htdocs/config.php erstellt"
fi

# Systemd Services anpassen (falls schon installiert)
log_info "Passe Systemd-Services an..."
for service in /etc/systemd/system/phoniebox-*.service; do
    if [ -f "$service" ]; then
        sudo sed -i "s|/home/pi|$CURRENT_HOME|g" "$service"
        sudo sed -i "s|User=pi|User=$CURRENT_USER|g" "$service"
        log_success "Angepasst: $service"
    fi
done

sudo systemctl daemon-reload 2>/dev/null || true

echo ""
log_success "Alle Pfade wurden angepasst!"
echo ""
echo "Nächste Schritte:"
echo "  1. Global Config neu erstellen:"
echo "     cd ~/RPi-Jukebox-RFID/scripts && ./inc.writeGlobalConfig.sh"
echo ""
echo "  2. Services neu starten:"
echo "     sudo systemctl restart phoniebox-rfid-reader"
echo "     sudo systemctl restart lighttpd"
echo ""

