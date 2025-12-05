# Phoniebox v2.x - Aktualisierungs- und Optimierungsliste

> **Hinweis:** Version 3 ist bereits in Entwicklung (Branch `future3/main`) und wird bald zum Standard. Diese Liste bezieht sich auf Version 2.x (aktuell: 2.9.0-alpha).

---

## 📋 Inhaltsverzeichnis

1. [Kritische Updates](#1-kritische-updates)
2. [Frontend-Modernisierung](#2-frontend-modernisierung)
3. [PHP-Code Optimierung](#3-php-code-optimierung)
4. [Python-Code Optimierung](#4-python-code-optimierung)
5. [Shell-Skripte Verbesserungen](#5-shell-skripte-verbesserungen)
6. [Abhängigkeiten & Pakete](#6-abhängigkeiten--pakete)
7. [Sicherheitsverbesserungen](#7-sicherheitsverbesserungen)
8. [Performance-Optimierungen](#8-performance-optimierungen)
9. [Code-Qualität & Testing](#9-code-qualität--testing)
10. [Dokumentation](#10-dokumentation)
11. [Migration zu Version 3](#11-migration-zu-version-3)

---

## 1. Kritische Updates

### 🔴 Hohe Priorität

| Was | Aktuell | Empfohlen | Aufwand |
|-----|---------|-----------|---------|
| jQuery | 1.12.4 | 3.7.x | Mittel |
| Bootstrap | 3.x | 5.3.x | Hoch |
| PHP-Version | Beliebig | >= 8.1 | Niedrig |
| Python | 3.x | >= 3.9 | Niedrig |

### Schritte:

```bash
# 1. jQuery aktualisieren
# In htdocs/_assets/js/ jQuery 3.7.1 hinzufügen
wget https://code.jquery.com/jquery-3.7.1.min.js -O htdocs/_assets/js/jquery-3.7.1.min.js

# 2. func.php anpassen - jQuery-Pfad ändern
# Zeile 33 in htdocs/func.php:
# Alt: jquery.1.12.4.min.js
# Neu: jquery-3.7.1.min.js
```

---

## 2. Frontend-Modernisierung

### 2.1 Bootstrap Migration (3 → 5)

**Betroffene Dateien:**
- `htdocs/func.php` (Header-Template)
- Alle `htdocs/*.php` Dateien mit Bootstrap-Klassen

**Änderungen:**

| Bootstrap 3 | Bootstrap 5 |
|-------------|-------------|
| `col-lg-12` | `col-lg-12` (unverändert) |
| `btn btn-default` | `btn btn-secondary` |
| `panel` | `card` |
| `panel-heading` | `card-header` |
| `panel-body` | `card-body` |
| `data-toggle` | `data-bs-toggle` |
| `data-dismiss` | `data-bs-dismiss` |

**Vorgehensweise:**
1. Bootstrap 5 CSS/JS herunterladen
2. Darkly-Theme für Bootstrap 5 beschaffen (Bootswatch)
3. Schrittweise Komponenten migrieren
4. jQuery Plugins auf Vanilla JS umstellen (Bootstrap 5 braucht kein jQuery)

### 2.2 jQuery File Upload modernisieren

```bash
# Aktuelle Version: 9.22.0 (2018)
# Empfehlung: Ersetzen durch moderne Alternative

# Option A: Dropzone.js (leichtgewichtig)
# Option B: FilePond (modern, reaktiv)
# Option C: Native HTML5 File API verwenden
```

### 2.3 Material Design Icons

- Aktuelle Version prüfen und ggf. aktualisieren
- Font-Loading optimieren (Subset erstellen für benötigte Icons)

---

## 3. PHP-Code Optimierung

### 3.1 Code-Struktur verbessern

**Aktueller Zustand:**
- Keine Namespaces
- Kein Autoloading (außer für Tests via Composer)
- Gemischte Logik (HTML + PHP)
- Direkte Shell-Aufrufe mit `exec()`

**Empfohlene Verbesserungen:**

```php
// Vorher (htdocs/func.php)
function tailShell($filepath, $lines = 1) {
    ob_start();
    passthru('tail -' . $lines . ' ' . escapeshellarg($filepath));
    return trim(ob_get_clean());
}

// Nachher - mit Type Hints und besserer Fehlerbehandlung
function tailShell(string $filepath, int $lines = 1): string 
{
    if (!file_exists($filepath)) {
        throw new InvalidArgumentException("File not found: $filepath");
    }
    
    $output = [];
    $returnCode = 0;
    exec('tail -' . $lines . ' ' . escapeshellarg($filepath), $output, $returnCode);
    
    if ($returnCode !== 0) {
        throw new RuntimeException("Failed to read file tail");
    }
    
    return implode("\n", $output);
}
```

### 3.2 API-Layer einführen

Die bestehenden `api/*.php` Dateien in eine einheitliche REST-API umwandeln:

```php
// api/v1/player.php - Beispiel
header('Content-Type: application/json');

$action = $_GET['action'] ?? '';
$response = ['success' => false, 'error' => null, 'data' => null];

try {
    switch ($action) {
        case 'play':
            // Logik
            break;
        case 'pause':
            // Logik
            break;
        default:
            throw new InvalidArgumentException('Unknown action');
    }
    $response['success'] = true;
} catch (Exception $e) {
    $response['error'] = $e->getMessage();
    http_response_code(400);
}

echo json_encode($response);
```

### 3.3 Template-System einführen

**Option A: Einfaches PHP-Templating**

```php
// templates/base.php
<!DOCTYPE html>
<html lang="<?= $lang ?>">
<head>
    <title><?= htmlspecialchars($title) ?></title>
    <!-- ... -->
</head>
<body>
    <?= $content ?>
</body>
</html>
```

**Option B: Twig Template Engine**

```bash
composer require twig/twig
```

---

## 4. Python-Code Optimierung

### 4.1 Type Hints hinzufügen

```python
# Vorher (scripts/daemon_rfid_reader.py)
def handler(signum, frame):
    logger.info('No RFID Signal detected.')

# Nachher
from typing import Any
import signal

def handler(signum: int, frame: Any) -> None:
    """Handle SIGALRM when no RFID signal is detected."""
    logger.info('No RFID Signal detected.')
```

### 4.2 Configuration Management

```python
# config.py - Zentralisierte Konfiguration
from dataclasses import dataclass
from pathlib import Path
import configparser

@dataclass
class Config:
    same_id_delay: float
    swipe_or_place: str
    base_path: Path
    
    @classmethod
    def load(cls, settings_path: Path) -> 'Config':
        # Lade Konfiguration aus Dateien
        pass
```

### 4.3 Async/Await für I/O-Operationen

```python
# Für Reader.py - asynchrone Kartenlesung
import asyncio

async def read_card_async() -> str | None:
    """Asynchrone Kartenlesung für bessere Performance."""
    # Implementation
    pass
```

### 4.4 requirements.txt mit Versionen fixieren

```txt
# requirements.txt - Mit festen Versionen
evdev==1.6.1
yt-dlp>=2024.1.0
pyserial==3.5
rpi-lgpio==0.4
pytest==8.0.0
pytest-cov==4.1.0
coverage==7.4.0
```

---

## 5. Shell-Skripte Verbesserungen

### 5.1 Code-Duplikation reduzieren

**Problem:** Viel redundanter Code in `playout_controls.sh` (1154 Zeilen)

**Lösung:** Gemeinsame Funktionen extrahieren

```bash
# scripts/lib/volume.sh
#!/bin/bash

# Gemeinsame Volume-Funktionen
get_volume() {
    if [ "${VOLUMEMANAGER}" == "amixer" ]; then
        amixer sget \'$AUDIOIFACENAME\' | grep -Po -m 1 '(?<=\[)[^]]*(?=%])'
    else
        echo -e status\\nclose | nc -w 1 localhost 6600 | grep -o -P '(?<=volume: ).*'
    fi
}

set_volume() {
    local value=$1
    if [ "${VOLUMEMANAGER}" == "amixer" ]; then
        amixer sset \'$AUDIOIFACENAME\' ${value}%
    else
        echo -e setvol ${value}\\nclose | nc -w 1 localhost 6600
    fi
}
```

### 5.2 ShellCheck verwenden

```bash
# Installation
apt-get install shellcheck

# Ausführen
shellcheck scripts/*.sh

# Häufige Probleme:
# - Unquoted variables: $VAR -> "$VAR"
# - Backticks: `command` -> $(command)
# - [ ] vs [[ ]]: Moderne Syntax verwenden
```

### 5.3 Set-Optionen für bessere Fehlerbehandlung

```bash
#!/bin/bash
set -euo pipefail  # Am Anfang jedes Skripts

# -e: Exit bei Fehler
# -u: Fehler bei undefinierter Variable
# -o pipefail: Pipeline-Fehler propagieren
```

---

## 6. Abhängigkeiten & Pakete

### 6.1 System-Pakete aktualisieren

**packages.txt - Überprüfung:**

| Paket | Status | Hinweis |
|-------|--------|---------|
| lighttpd | ✅ | Stabil |
| php | ⚠️ | PHP 8.1+ empfohlen |
| mpd | ✅ | Stabil |
| mpg123 | ✅ | Stabil |
| ffmpeg | ✅ | Stabil |
| resolvconf | ⚠️ | Auf neueren Systemen durch systemd-resolved ersetzt |

### 6.2 Python-Pakete

```bash
# Aktuelle vs. empfohlene Versionen
pip list --outdated

# Sicherheits-Audit
pip-audit
```

### 6.3 Composer-Abhängigkeiten

```bash
# Aktualisieren
composer update

# Sicherheits-Check
composer audit
```

---

## 7. Sicherheitsverbesserungen

### 7.1 Shell-Command Injection verhindern

```php
// Vorher (unsicher)
exec("tail -" . $lines . " " . $filepath);

// Nachher (sicher)
exec("tail -" . escapeshellarg($lines) . " " . escapeshellarg($filepath));

// Oder besser: PHP native Funktionen verwenden
$content = file($filepath);
$lastLines = array_slice($content, -$lines);
```

### 7.2 Input-Validierung

```php
// htdocs/api/*.php - Validierung hinzufügen
function validateCardId(string $cardId): bool {
    return preg_match('/^[a-zA-Z0-9_-]+$/', $cardId) === 1;
}

$cardId = $_GET['cardid'] ?? '';
if (!validateCardId($cardId)) {
    http_response_code(400);
    die(json_encode(['error' => 'Invalid card ID']));
}
```

### 7.3 CSRF-Schutz

```php
// inc.header.php - Token generieren
session_start();
if (empty($_SESSION['csrf_token'])) {
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
}

// In Formularen
<input type="hidden" name="csrf_token" value="<?= $_SESSION['csrf_token'] ?>">

// Validierung
if ($_POST['csrf_token'] !== $_SESSION['csrf_token']) {
    die('CSRF token mismatch');
}
```

### 7.4 Berechtigungen

```bash
# Dateiberechtigungen überprüfen
find htdocs -type f -name "*.php" -exec chmod 644 {} \;
find scripts -type f -name "*.sh" -exec chmod 755 {} \;
find settings -type f -exec chmod 640 {} \;
```

---

## 8. Performance-Optimierungen

### 8.1 Frontend

```bash
# CSS/JS minifizieren
npm install -g terser cssnano

# JavaScript
terser htdocs/js/jukebox.js -o htdocs/js/jukebox.min.js

# CSS
npx cssnano htdocs/_assets/css/*.css htdocs/_assets/css/bundle.min.css
```

### 8.2 PHP OPcache aktivieren

```ini
; /etc/php/8.1/cgi/conf.d/10-opcache.ini
opcache.enable=1
opcache.memory_consumption=64
opcache.max_accelerated_files=4000
opcache.revalidate_freq=60
```

### 8.3 MPD-Kommunikation optimieren

```php
// Persistente Verbindung statt einzelner netcat-Aufrufe
class MPDClient {
    private $socket;
    
    public function __construct(string $host = 'localhost', int $port = 6600) {
        $this->socket = fsockopen($host, $port);
    }
    
    public function command(string $cmd): array {
        fwrite($this->socket, "$cmd\n");
        // Response lesen...
    }
    
    public function __destruct() {
        if ($this->socket) {
            fwrite($this->socket, "close\n");
            fclose($this->socket);
        }
    }
}
```

### 8.4 Caching

```php
// Einfaches File-Caching für MPD-Status
function getCachedMpdStatus(): array {
    $cacheFile = '/tmp/mpd_status.json';
    $cacheTime = 1; // Sekunden
    
    if (file_exists($cacheFile) && (time() - filemtime($cacheFile)) < $cacheTime) {
        return json_decode(file_get_contents($cacheFile), true);
    }
    
    $status = getMpdStatus(); // Echte Abfrage
    file_put_contents($cacheFile, json_encode($status));
    return $status;
}
```

---

## 9. Code-Qualität & Testing

### 9.1 PHP-Tests erweitern

```bash
# Tests ausführen
composer test

# Coverage-Report
composer test -- --coverage-html coverage/
```

### 9.2 Python-Tests erweitern

```bash
# Tests mit Coverage
pytest --cov=scripts --cov-report=html

# Spezifische Tests
pytest tests/ -v
```

### 9.3 Linting einrichten

```bash
# PHP - PHP_CodeSniffer
composer require --dev squizlabs/php_codesniffer
./vendor/bin/phpcs --standard=PSR12 htdocs/

# Python - Ruff (schneller als flake8)
pip install ruff
ruff check scripts/

# Shell - ShellCheck
shellcheck scripts/*.sh
```

### 9.4 Pre-commit Hooks

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.1.9
    hooks:
      - id: ruff
        
  - repo: https://github.com/shellcheck-py/shellcheck-py
    rev: v0.9.0.6
    hooks:
      - id: shellcheck
```

---

## 10. Dokumentation

### 10.1 Code-Dokumentation

```php
/**
 * Spielt eine Playlist ab.
 *
 * @param string $playlist Relativer Pfad zur Playlist
 * @param bool $recursive Auch Unterordner einbeziehen
 * @return bool Erfolg
 * @throws RuntimeException Bei MPD-Fehlern
 */
function playPlaylist(string $playlist, bool $recursive = false): bool {
    // Implementation
}
```

### 10.2 API-Dokumentation

```yaml
# docs/api.yaml (OpenAPI 3.0)
openapi: 3.0.0
info:
  title: Phoniebox API
  version: 2.9.0
paths:
  /api/player.php:
    get:
      summary: Player-Status abrufen
      responses:
        '200':
          description: Erfolg
```

### 10.3 Changelog pflegen

```markdown
# CHANGELOG.md

## [2.9.0] - YYYY-MM-DD
### Added
- Feature X
### Changed
- Dependency Y aktualisiert
### Fixed
- Bug Z
### Security
- CVE-XXXX behoben
```

---

## 11. Migration zu Version 3

### Warum Version 3?

- **Einheitliche Sprache:** Python als Hauptsprache
- **Modernes Web-Interface:** React-basiert
- **Plugin-System:** Erweiterbar
- **Bessere Architektur:** Saubere Trennung

### Migrationspfad

1. **Backup erstellen:**
   ```bash
   cp -r ~/RPi-Jukebox-RFID ~/RPi-Jukebox-RFID.backup
   ```

2. **Daten exportieren:**
   - Audio-Ordner (`shared/audiofolders/`)
   - Shortcuts (`shared/shortcuts/`)
   - Einstellungen (`settings/`)

3. **Version 3 installieren:**
   ```bash
   # Siehe: https://github.com/MiczFlor/RPi-Jukebox-RFID/blob/future3/main/documentation/builders/installation.md
   ```

4. **Daten importieren:**
   - Audio-Dateien übertragen
   - RFID-Karten neu zuweisen

### Empfehlung

> **Für neue Installationen:** Direkt Version 3 verwenden
> 
> **Für bestehende Installationen:** Bei Version 2 bleiben, bis Version 3 stabil ist, oder parallel testen

---

## ✅ Checkliste für sofortige Verbesserungen

- [ ] jQuery auf 3.7.x aktualisieren
- [ ] PHP 8.1+ sicherstellen
- [ ] `requirements.txt` mit festen Versionen
- [ ] ShellCheck auf alle Shell-Skripte anwenden
- [ ] Input-Validierung in API-Endpoints
- [ ] CSRF-Tokens für Formulare
- [ ] OPcache aktivieren
- [ ] Pre-commit Hooks einrichten

---

## 📚 Ressourcen

- [Phoniebox Wiki](https://github.com/MiczFlor/RPi-Jukebox-RFID/wiki)
- [Version 3 Dokumentation](https://github.com/MiczFlor/RPi-Jukebox-RFID/blob/future3/main/documentation/README.md)
- [Bootstrap 5 Migration Guide](https://getbootstrap.com/docs/5.3/migration/)
- [PHP 8 Migration Guide](https://www.php.net/manual/en/migration80.php)
- [Python Type Hints](https://docs.python.org/3/library/typing.html)

---

*Erstellt am: 2024-12-05*
*Phoniebox Version: 2.9.0-alpha*

