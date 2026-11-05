# FreeCol Java Server – Startanleitung mit Logging & Savegame

## Inhaltsverzeichnis

1. [Voraussetzungen](#voraussetzungen)
2. [Server-Startmethoden](#server-startmethoden)
   - [Docker (empfohlen)](#docker-empfohlen)
   - [Lokal (Java)](#lokal-java)
3. [Logging-Konfiguration](#logging-konfiguration)
   - [Log-Levels](#log-levels)
   - [Log-Datei-Location](#log-datei-location)
4. [Savegame-Optionen](#savegame-optionen)
5. [Server am Laufen halten](#server-am-laufen-halten)
6. [Praktische Beispiele](#praktische-beispiele)
7. [Debugging-Tipps](#debugging-tipps)
8. [Verfügbare Server-Optionen](#verfügbare-server-optionen)
9. [Schnellreferenz](#schnellreferenz)

---

## Voraussetzungen

- **FreeCol Java Server** (entweder via Docker oder lokal gebaut)
- **Savegame-Datei** (`.fsg` – z.B. `/fixtures/scenario-e2e.fsg`)
- **Docker** (für Docker-Modus) oder **Java 11+** (für lokalen Modus)

---

## Server-Startmethoden

### Docker (empfohlen)

#### 1. Docker-Image bauen

```bash
cd /Users/marcel/projects/freecol/docker
docker compose -f docker-compose.yml build
```

#### 2. Server mit Savegame und Logging starten

```bash
# Standard-Start (mit Logging)
docker run -d \
  --name freecol-server \
  -p 3541:3541 \
  -v /Pfad/zu/deinen/daten:/data \
  docker-freecol-server:latest \
  --load-savegame /data/dein-savegame.fsg \
  --log-file /data/server.log
```

#### 3. Logs anzeigen

```bash
# Echtzeit-Logs
docker logs -f freecol-server

# Letzte 100 Zeilen
docker logs --tail 100 freecol-server

# Log-Datei im Container
docker exec freecol-server cat /data/server.log
```

### Lokal (Java)

#### 1. Server mit Savegame und Logging starten

```bash
cd /Users/marcel/projects/freecol
java -Djava.awt.headless=true \
     -Xmx2G \
     -jar FreeCol.jar \
     --server \
     --private \
     --server-ip 127.0.0.1 \
     --server-port 3541 \
     --load-savegame /Pfad/zu/dein-savegame.fsg \
     --log-file /tmp/freecol-server.log
```

#### 2. Logs anzeigen

```bash
# Echtzeit-Logs
tail -f /tmp/freecol-server.log

# Letzte 50 Zeilen
tail -n 50 /tmp/freecol-server.log
```

---

## Logging-Konfiguration

### Log-Levels

FreeCol nutzt Java Logging (`java.util.logging`). Verfügbare Levels:

| Level | Beschreibung | Verwendung |
|-------|--------------|------------|
| `SEVERE` | Kritische Fehler | Server-Crashes, fatale Fehler |
| `WARNING` | Warnungen | Potenzielle Probleme, ungewöhnliche Zustände |
| `INFO` | Standard-Informationen | Server-Start, Client-Verbindungen, Spielereignisse |
| `FINE` | Detaillierte Infos | Nachrichten-Protokollierung, Zustandänderungen |
| `FINER` | Sehr detailliert | Alle Nachrichten, interne Abläufe |
| `FINEST` | Maximale Details | Alle Daten, Debug-Informationen |

#### Log-Level setzen

```bash
# Via JVM-Property (empfohlen)
java -Dfreecol.loglevel=FINE -jar FreeCol.jar --server ...

# Via logging.properties (alternativ)
java -Djava.util.logging.config.file=/Pfad/zu/logging.properties -jar FreeCol.jar
```

Beispiel `logging.properties`:
```properties
# Set root logger level
handlers=java.util.logging.ConsoleHandler
.default=FINE

# Console handler
java.util.logging.ConsoleHandler.level=FINE
java.util.logging.ConsoleHandler.formatter=java.util.logging.SimpleFormatter

# FreeCol logger
net.sf.freecol.level=FINER
```

### Log-Datei-Location

| Modus | Location | Standard |
|-------|----------|----------|
| **Docker** | Im Container | `/data/server.log` (wenn `--log-file` angegeben) |
| **Docker** | Console | `docker logs <container>` |
| **Lokal** | Datei | Gemäß `--log-file` Pfad |
| **Lokal** | Console | Terminal-Ausgabe |

---

## Savegame-Optionen

| Option | Beschreibung | Beispiel |
|--------|--------------|----------|
| `--load-savegame <path>` | Lädt ein Savegame beim Start | `--load-savegame /data/save.fsg` |
| `--savegame-name <name>` | Name für neue Savegames | `--savegame-name test` |
| `--seed <zahl>` | Zufallsseed für neue Spiele | `--seed 12345` |

### Wichtige Hinweise

1. **Savegame-Pfad** muss im Container oder lokal verfügbar sein
2. **Docker-Volumes** nutzen für persistente Savegames
3. **Berechtigungen** prüfen – Server muss Leserechte haben
4. **Savegame-Version** muss mit Server-Version kompatibel sein

### Beispiel: Server mit Savegame aus Fixtures starten

```bash
# Docker-Modus
cd /Users/marcel/projects/FreeColClient
Tools/e2e-java-server.sh

# Oder manuell mit spezifischem Savegame
docker run -d \
  --name freecol-test \
  -p 3541:3541 \
  -v $(pwd)/Tools/fixtures:/fixtures:ro \
  docker-freecol-server:latest \
  --load-savegame /fixtures/scenario-e2e.fsg \
  --log-file /data/server.log
```

---

## Server am Laufen halten

### Docker-Modus

```bash
# Server bleibt nach Beenden laufen
KEEP_SERVER=1 Tools/e2e-java-server.sh

# Manuell stoppen
docker stop freecol-server
```

### Lokaler Modus

```bash
# Server im Hintergrund starten
java -Djava.awt.headless=true -Xmx2G -jar FreeCol.jar \
     --server --load-savegame /Pfad/save.fsg \
     --log-file /tmp/server.log &
SERVER_PID=$!

# Server stoppen
kill $SERVER_PID
```

---

## Praktische Beispiele

### Beispiel 1: Docker mit Savegame und maximalem Logging

```bash
cd /Users/marcel/projects/FreeColClient

# Volume für Daten anlegen
docker volume create freecol-data

# Savegame in Volume kopieren
docker run --rm -v freecol-data:/data -v $(pwd)/Tools/fixtures:/saves alpine \
  sh -c "cp /saves/scenario-e2e.fsg /data/"

# Server starten (bleibt laufen)
docker run -d \
  --name freecol-debug \
  -p 3541:3541 \
  -v freecol-data:/data \
  docker-freecol-server:latest \
  --load-savegame /data/scenario-e2e.fsg \
  --log-file /data/server.log

# Logs in Echtzeit beobachten
docker logs -f freecol-debug
```

### Beispiel 2: Lokal mit maximalem Logging

```bash
cd /Users/marcel/projects/freecol

java -Djava.awt.headless=true \
     -Dfreecol.loglevel=FINEST \
     -Xmx2G \
     -jar FreeCol.jar \
     --server \
     --private \
     --server-port 3541 \
     --load-savegame /Users/marcel/saves/mein-spiel.fsg \
     --log-file /tmp/freecol-debug.log
```

### Beispiel 3: E2E-Test mit spezifischem Savegame

```bash
cd /Users/marcel/projects/FreeColClient

# Nur bestimmte Proben ausführen
ONLY="nativetrade abandon disembark" Tools/e2e-java-server.sh

# Oder mit KEEP_SERVER
KEEP_SERVER=1 ONLY="nativetrade" Tools/e2e-java-server.sh
```

### Beispiel 4: Server für manuelles Testen

```bash
# Docker-Modus
docker run -d \
  --name freecol-manual \
  -p 3541:3541 \
  -v $(pwd)/Tools/fixtures:/fixtures:ro \
  docker-freecol-server:latest \
  --load-savegame /fixtures/scenario-e2e.fsg \
  --log-file /data/debug.log \
  --difficulty Easy

# Client verbinden
# Dann Logs beobachten
docker logs -f freecol-manual
```

---

## Debugging-Tipps

### 1. Log-Level auf FINEST setzen

```bash
# Docker
java -Dfreecol.loglevel=FINEST ...

# Oder in logging.properties
net.sf.freecol.level=FINEST
```

### 2. Port-Konflikte vermeiden

```bash
# Port prüfen
nc -z 127.0.0.1 3541

# Alternativen Port nutzen
--server-port 3542
```

### 3. Server-Status prüfen

```bash
# Docker
curl -v http://localhost:3541/  # (falls HTTP-Interface)

# Oder einfach Verbindung testen
nc -z 127.0.0.1 3541
```

### 4. Savegame-Pfad validieren

```bash
# Docker - Datei im Container prüfen
docker exec freecol-server ls -la /data/

# Lokal - Datei prüfen
ls -la /Pfad/zu/dein-savegame.fsg
```

### 5. Memory-Usage überwachen

```bash
# Docker
 docker stats freecol-server

# Lokal
jconsole $SERVER_PID
```

---

## Verfügbare Server-Optionen

### Server-Konfiguration

| Option | Beschreibung | Standardwert |
|--------|--------------|--------------|
| `--server` | Startet im Server-Modus | – |
| `--private` | Server nicht öffentlich listen | – |
| `--server-ip <ip>` | IP-Adresse binden | `0.0.0.0` |
| `--server-port <port>` | Port | `3541` |

### Spiel-Optionen

| Option | Beschreibung | Standardwert |
|--------|--------------|--------------|
| `--difficulty <level>` | Schwierigkeitsgrad | `Easy` |
| `--seed <zahl>` | Zufallsseed | Zufällig |
| `--europeans <n>` | Anzahl europäischer Spieler | `4` |
| `--natives <n>` | Anzahl indigener Spieler | `2` |

### Client-Optionen

| Option | Beschreibung | Standardwert |
|--------|--------------|--------------|
| `--default-locale <locale>` | Standard-Sprache | `en` |
| `--user-config-directory <path>` | Config-Verzeichnis | – |
| `--user-cache-directory <path>` | Cache-Verzeichnis | – |
| `--user-data-directory <path>` | Daten-Verzeichnis | – |
| `--clientOptions <path>` | Client-Options-Datei | – |

### Logging & Debugging

| Option | Beschreibung | Standardwert |
|--------|--------------|--------------|
| `--log-file <path>` | Log-Datei | Keine (nur Console) |
| `-Dfreecol.loglevel=<level>` | Log-Level | `INFO` |
| `-Djava.awt.headless=true` | Headless-Modus | – |
| `-Xmx<size>` | Maximaler Speicher | `2G` (empfohlen) |

---

## Schnellreferenz

### Einzeiler für häufige Aktionen

| Aktion | Befehl |
|--------|--------|
| **Docker: Server + Savegame + Logging** | `docker run -d -p 3541:3541 -v freecol-data:/data docker-freecol-server --load-savegame /data/save.fsg --log-file /data/log.txt` |
| **Lokal: Server + Savegame + Logging** | `java -Djava.awt.headless=true -Xmx2G -jar FreeCol.jar --server --load-savegame save.fsg --log-file log.txt` |
| **Docker: Server + FINEST Logging** | `docker run -d -p 3541:3541 -e JAVA_OPTS="-Dfreecol.loglevel=FINEST" docker-freecol-server --load-savegame /data/save.fsg` |
| **Logs anzeigen (Docker)** | `docker logs -f freecol-server` |
| **Logs anzeigen (Lokal)** | `tail -f /tmp/freecol-server.log` |
| **Server stoppen (Docker)** | `docker stop freecol-server` |
| **Server stoppen (Lokal)** | `pkill -f FreeCol.jar` |
| **Port prüfen** | `nc -z 127.0.0.1 3541` |

### E2E-Test-Kurzbefehle

| Aktion | Befehl |
|--------|--------|
| **Alle E2E-Tests** | `Tools/e2e-java-server.sh` |
| **Nur Smoke-Test** | `ONLY="smoke" Tools/e2e-java-server.sh` |
| **Nur Deep-Test** | `ONLY="deep" Tools/e2e-java-server.sh` |
| **Server behalten** | `KEEP_SERVER=1 Tools/e2e-java-server.sh` |
| **Spezielles Savegame** | `ONLY="nativetrade" Tools/e2e-java-server.sh` |

---

## Fehlerbehebung

### Häufige Probleme

#### 1. Savegame wird nicht geladen

**Ursache:** Savegame-Pfad ist falsch oder nicht verfügbar

**Lösung:**
```bash
# Docker - Pfad im Container prüfen
docker exec <container> ls -la /Pfad/zum/savegame.fsg

# Lokal - Pfad prüfen
ls -la /Pfad/zum/savegame.fsg
```

#### 2. Server startet nicht

**Ursache:** Fehlende `options.xml` oder Port-Konflikt

**Lösung:**
```bash
# Docker - Volume mit options.xml erstellen
# (wird automatisch in Tools/e2e-java-server.sh gemacht)

# Port prüfen
nc -z 127.0.0.1 3541

# Alternativen Port nutzen
--server-port 3542
```

#### 3. Keine Logs sichtbar

**Ursache:** Falsches Log-Level oder falsche Dateiberechtigungen

**Lösung:**
```bash
# Log-Level erhöhen
java -Dfreecol.loglevel=FINEST ...

# Docker - Log-Datei prüfen
docker exec <container> cat /data/server.log
```

#### 4. Memory-OutOfMemoryError

**Ursache:** Zu wenig Speicher zugewiesen

**Lösung:**
```bash
# Mehr Speicher zuweisen
java -Xmx4G -jar FreeCol.jar ...
```

---

## Zusätzliche Ressourcen

- [FreeCol Dokumentation](http://www.freecol.org/docs/)
- [Phase 62 Dokumentation](Docs/Plans/phase62-java-server-e2e-plan.md)
- [E2E-Testskript](Tools/e2e-java-server.sh)
- [Verfügbare Fixtures](Tools/fixtures/)

---

*Dokumentation erstellt für FreeColClient – Stand: 2024*
