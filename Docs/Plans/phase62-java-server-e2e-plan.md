# Phase 62 — End-to-End-Validierung gegen den Java-Server (Implementiert)

Ziel: Die in den Phasen 54–61 nur gegen den MockServer getestete Anbindung
einmal gegen einen echten Java-FreeCol-Server verifizieren und reproduzierbar
machen.

## Umfang

### 1. Docker-Server betriebsbereit
- Das vorhandene Image `docker-freecol-server:latest` (headless, Port 3541)
  startet erst, wenn `/data/config/freecol/freecol/options.xml` existiert
  (`ClientOptions.getSpecialOptions` wirft sonst).
- `Tools/e2e-java-server.sh` legt ein eigenes Volume an, seedet die
  Optionsdatei, startet den Container, wartet auf den Port und räumt danach
  auf (`KEEP_SERVER=1` zum Behalten).

### 2. Zwei Probes
- **Smoke** (`REAL_SERVER_E2E=1`): connect → `gameState`/`vacantPlayers` →
  Login → `ready`/`requestLaunch` bzw. `endTurn` als Transport-Probe.
- **Deep** (`REAL_SERVER_DEEP_E2E=1`): Login im Pre-Game, `ready` +
  `requestLaunch` (fire-and-forget, wie in der Java-`ServerAPI`), Message-Loop,
  Übergang nach In-Game (`currentPlayerId`), opportunistischer `endTurn`-Ask
  mit 5s-Timeout.

### 3. Gefundene/behobene Punkte
- `ready`/`requestLaunch` sind im Java-Client `send`, nicht `ask`; der Deep-Test
  wartete fälschlich auf ein `<reply>` → auf `send` umgestellt.
- `endTurn` kann serverseitig bis zum eigenen Zug zurückgehalten werden; der
  Probe-Ask darf deshalb nicht fehlschlagen (Timeout toleriert).
- `NovaloriaClient.ask(message:timeout:)` um einen Timeout-Parameter erweitert.
- Die beiden Real-Server-Tests sind auf einer Serverinstanz exklusiv (der
  Launch verbraucht die Pre-Game-Lobby); der Deep-Test läuft daher nur ohne
  gesetztes `REAL_SERVER_E2E`.

## Ergebnis

```
==> Smoke probe  → 131 passed, 0 failed
==> Deep probe   → 131 passed, 0 failed
```

Damit ist bestätigt: echter TCP/XML-Handshake, Login, Lobby und der Übergang
nach In-Game funktionieren gegen den Java-Server 0.120.

## Nutzung

```bash
Tools/e2e-java-server.sh          # beide Probes, frischer Server je Probe
KEEP_SERVER=1 Tools/e2e-java-server.sh
```

Voraussetzung: Docker und ein lokal gebautes `docker-freecol-server`-Image
(`docker compose -f ../freecol/docker/docker-compose.yml build`).
