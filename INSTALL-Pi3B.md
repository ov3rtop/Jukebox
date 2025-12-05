# Phoniebox Installation auf Raspberry Pi 3B

Diese Anleitung beschreibt die Installation der optimierten Phoniebox v2.9.x auf einem Raspberry Pi 3 Model B.

## 📋 Voraussetzungen

### Hardware
- Raspberry Pi 3 Model B (oder B+)
- MicroSD-Karte (mind. 16GB, Class 10 empfohlen)
- Netzteil (5V, 2.5A)
- USB RFID-Reader (z.B. Neuftech 125kHz)
- RFID-Karten/Chips (passend zum Reader)
- Lautsprecher (USB oder 3.5mm Klinke)
- Optional: GPIO-Buttons, Rotary Encoder

### Software
- Raspberry Pi OS Lite (Bookworm, 64-bit empfohlen) oder Legacy (Bullseye)
- SSH-Zugang oder Monitor/Tastatur

---

## 🚀 Schnellinstallation

### 1. Raspberry Pi OS installieren

1. **Raspberry Pi Imager** herunterladen: https://www.raspberrypi.com/software/
2. **Raspberry Pi OS Lite (64-bit)** wählen
3. **Einstellungen** (Zahnrad-Symbol):
   - Hostname: `phoniebox`
   - SSH aktivieren
   - Benutzername: `pi`
   - Passwort setzen
   - WLAN konfigurieren (SSID + Passwort)
   - Locale: `de_DE.UTF-8`
   - Zeitzone: `Europe/Berlin`
4. Auf SD-Karte schreiben

### 2. Erster Start und SSH-Verbindung

```bash
# IP-Adresse finden (im Router oder mit nmap)
nmap -sn 192.168.1.0/24 | grep phoniebox

# Verbinden
ssh pi@phoniebox.local
# oder
ssh pi@<IP-ADRESSE>
```

### 3. System aktualisieren

```bash
sudo apt update && sudo apt upgrade -y
sudo reboot
```

### 4. Phoniebox installieren

```bash
# Nach Reboot erneut verbinden
ssh pi@phoniebox.local

# Installationsskript herunterladen und ausführen
cd ~
wget https://raw.githubusercontent.com/MiczFlor/RPi-Jukebox-RFID/master/scripts/installscripts/install-jukebox.sh
chmod +x install-jukebox.sh
./install-jukebox.sh
```

**Während der Installation:**
- `Classic` Edition wählen (oder `Spotify` wenn gewünscht)
- RFID-Reader auswählen (meist USB)
- Audio-Ausgabe wählen (USB/Headphone)

### 5. Nach der Installation

```bash
# Neustart
sudo reboot

# Nach dem Neustart: Web-Interface öffnen
# Im Browser: http://phoniebox.local oder http://<IP-ADRESSE>
```

---

## 🔧 Manuelle Installation (mit Optimierungen)

Falls du die optimierte Version aus diesem Repository installieren möchtest:

### 1. Repository klonen

```bash
cd ~
git clone https://github.com/MiczFlor/RPi-Jukebox-RFID.git
cd RPi-Jukebox-RFID
```

### 2. System-Pakete installieren

```bash
# Pakete aus packages.txt installieren
sudo apt update
sed 's/#.*//g' packages.txt | xargs sudo apt install -y

# Raspberry Pi spezifische Pakete
sed 's/#.*//g' packages-raspberrypi.txt | xargs sudo apt install -y
```

### 3. Python-Abhängigkeiten installieren

```bash
# Virtual Environment erstellen (empfohlen)
python3 -m venv ~/.venv/phoniebox
source ~/.venv/phoniebox/bin/activate

# Abhängigkeiten installieren
pip install --upgrade pip
pip install -r requirements.txt

# Für GPIO-Steuerung
pip install -r requirements-GPIO.txt
```

### 4. Web-Server konfigurieren

```bash
# Lighttpd PHP-Modul aktivieren
sudo lighttpd-enable-mod fastcgi
sudo lighttpd-enable-mod fastcgi-php

# Konfiguration kopieren
sudo cp ~/RPi-Jukebox-RFID/misc/sampleconfigs/lighttpd.conf.stretch-default.sample /etc/lighttpd/lighttpd.conf

# Neustart
sudo systemctl restart lighttpd
```

### 5. MPD konfigurieren

```bash
# Konfiguration kopieren
sudo cp ~/RPi-Jukebox-RFID/misc/sampleconfigs/mpd.conf.sample /etc/mpd.conf

# Audio-Ordner erstellen
mkdir -p ~/RPi-Jukebox-RFID/shared/audiofolders
mkdir -p ~/RPi-Jukebox-RFID/shared/shortcuts

# MPD Musik-Verzeichnis verlinken
sudo ln -s ~/RPi-Jukebox-RFID/shared/audiofolders /var/lib/mpd/music

# MPD neu starten und Datenbank aktualisieren
sudo systemctl restart mpd
mpc update
```

### 6. Dienste einrichten

```bash
# RFID-Reader Service
sudo cp ~/RPi-Jukebox-RFID/misc/sampleconfigs/phoniebox-rfid-reader.service.stretch-default.sample \
    /etc/systemd/system/phoniebox-rfid-reader.service
sudo systemctl enable phoniebox-rfid-reader.service

# GPIO-Control Service (optional)
sudo cp ~/RPi-Jukebox-RFID/misc/sampleconfigs/phoniebox-gpio-control.service.sample \
    /etc/systemd/system/phoniebox-gpio-control.service
sudo systemctl enable phoniebox-gpio-control.service

# Idle-Watchdog Service
sudo cp ~/RPi-Jukebox-RFID/misc/sampleconfigs/phoniebox-idle-watchdog.service.sample \
    /etc/systemd/system/phoniebox-idle-watchdog.service
sudo systemctl enable phoniebox-idle-watchdog.service

# Services starten
sudo systemctl daemon-reload
sudo systemctl start phoniebox-rfid-reader.service
```

### 7. Berechtigungen setzen

```bash
# Skripte ausführbar machen
chmod +x ~/RPi-Jukebox-RFID/scripts/*.sh
chmod +x ~/RPi-Jukebox-RFID/scripts/*.py

# Web-Ordner Berechtigungen
sudo chown -R pi:www-data ~/RPi-Jukebox-RFID/htdocs
sudo chmod -R 775 ~/RPi-Jukebox-RFID/htdocs
sudo chown -R pi:www-data ~/RPi-Jukebox-RFID/settings
sudo chmod -R 775 ~/RPi-Jukebox-RFID/settings
sudo chown -R pi:www-data ~/RPi-Jukebox-RFID/shared
sudo chmod -R 775 ~/RPi-Jukebox-RFID/shared
```

---

## 🔊 Audio-Konfiguration

### USB-Lautsprecher

```bash
# USB-Audio als Standard setzen
# In /etc/asound.conf:
sudo nano /etc/asound.conf
```

```
pcm.!default {
    type hw
    card 1
}

ctl.!default {
    type hw
    card 1
}
```

### 3.5mm Klinke

```bash
# Audio-Ausgabe auf Klinke setzen
sudo raspi-config
# -> System Options -> Audio -> Headphones
```

### HiFiBerry / DAC

Siehe: https://github.com/MiczFlor/RPi-Jukebox-RFID/wiki/HiFiBerry-Soundcard-Details

---

## 🎯 RFID-Reader einrichten

### USB RFID-Reader testen

```bash
# Reader anschließen und testen
cd ~/RPi-Jukebox-RFID/scripts
python3 RegisterDevice.py

# Eine Karte auflegen - ID wird angezeigt
```

### RC522 (SPI)

```bash
# SPI aktivieren
sudo raspi-config
# -> Interface Options -> SPI -> Enable

# Reader.py für RC522 konfigurieren
cd ~/RPi-Jukebox-RFID/scripts
cp Reader.py.experimental Reader.py
```

---

## 🎮 GPIO-Buttons einrichten

### Konfiguration bearbeiten

```bash
nano ~/RPi-Jukebox-RFID/settings/gpio_settings.ini
```

### Beispiel-Konfiguration

```ini
[DEFAULT]
enabled = True

[VolumeUp]
Type = Button
Pin = 17
functionCall = functionCallVolU

[VolumeDown]
Type = Button
Pin = 27
functionCall = functionCallVolD

[PlayPause]
Type = Button
Pin = 22
functionCall = functionCallPlayerPause

[NextTrack]
Type = Button
Pin = 23
functionCall = functionCallPlayerNext

[PrevTrack]
Type = Button
Pin = 24
functionCall = functionCallPlayerPrev

[Shutdown]
Type = ShutdownButton
Pin = 3
hold_time = 3.0
```

### GPIO-Service starten

```bash
sudo systemctl restart phoniebox-gpio-control.service
```

---

## 🌐 Netzwerk-Konfiguration

### Statische IP (optional)

```bash
sudo nano /etc/dhcpcd.conf
```

```
interface wlan0
static ip_address=192.168.1.100/24
static routers=192.168.1.1
static domain_name_servers=192.168.1.1
```

### Hotspot-Modus

Die Phoniebox kann als eigenen Hotspot fungieren, wenn kein bekanntes WLAN gefunden wird:

```bash
# Während der Installation aktivieren oder nachträglich:
cd ~/RPi-Jukebox-RFID/scripts/helperscripts
sudo ./setup_autohotspot.sh
```

**Hotspot-Zugangsdaten:**
- SSID: `phoniebox`
- Passwort: `PlayItLoud`
- IP: `10.0.0.5`

---

## ✅ Installation überprüfen

### 1. Services prüfen

```bash
# Alle Phoniebox-Services
systemctl status phoniebox-*

# MPD
systemctl status mpd

# Webserver
systemctl status lighttpd
```

### 2. Web-Interface testen

Browser öffnen: `http://phoniebox.local` oder `http://<IP-ADRESSE>`

### 3. Audio testen

```bash
# Testton abspielen
speaker-test -t wav -c 2

# Oder MP3
mpg123 ~/RPi-Jukebox-RFID/misc/silence-0.5sec.mp3
```

### 4. RFID testen

```bash
# Log beobachten
sudo journalctl -fu phoniebox-rfid-reader.service

# Eine Karte auflegen - sollte im Log erscheinen
```

---

## 🐛 Fehlerbehebung

### Kein Audio

```bash
# Audio-Geräte auflisten
aplay -l

# ALSA-Mixer öffnen
alsamixer

# Lautstärke prüfen (nicht stumm?)
```

### RFID-Reader wird nicht erkannt

```bash
# USB-Geräte auflisten
lsusb

# Input-Geräte prüfen
ls /dev/input/

# evtest installieren und testen
sudo apt install evtest
sudo evtest
```

### Web-Interface nicht erreichbar

```bash
# Lighttpd Status
sudo systemctl status lighttpd

# Logs prüfen
sudo tail -f /var/log/lighttpd/error.log

# PHP testen
php -v
```

### MPD-Probleme

```bash
# Status prüfen
mpc status

# Musik-Datenbank neu aufbauen
mpc update --wait

# MPD-Log
sudo journalctl -fu mpd
```

---

## 📚 Weitere Ressourcen

- [Phoniebox Wiki](https://github.com/MiczFlor/RPi-Jukebox-RFID/wiki)
- [GPIO-Steuerung](https://github.com/MiczFlor/RPi-Jukebox-RFID/blob/master/components/gpio_control/README.md)
- [Troubleshooting FAQ](https://github.com/MiczFlor/RPi-Jukebox-RFID/wiki/Troubleshooting-FAQ)
- [Matrix Community](https://matrix.to/#/#phoniebox_community:matrix.org)

---

## 🔄 Updates

```bash
cd ~/RPi-Jukebox-RFID
git pull

# Python-Abhängigkeiten aktualisieren
source ~/.venv/phoniebox/bin/activate
pip install -r requirements.txt --upgrade

# Services neu starten
sudo systemctl restart phoniebox-rfid-reader.service
sudo systemctl restart phoniebox-gpio-control.service
```

---

*Erstellt: 2024-12-05*
*Phoniebox Version: 2.9.x*

