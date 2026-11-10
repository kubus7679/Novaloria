# Release-Veröffentlichung (Deutsch)

English version: [releasing.md](releasing.md).

Der GitHub-Workflow **Release** wird manuell gestartet und baut ausschließlich
einen bereits gepushten Tag, dessen Name zur App-Version passt.

Für Version `0.0.1`:

1. Änderungen einschließlich `Sources/Novaloria/AppVersion.swift` und
   `Docs/releases/0.0.1.md` committen und auf den Standard-Branch pushen.
2. Den Tag auf genau diesem Commit anlegen und pushen:

   ```bash
   git tag -a v0.0.1 -m "Novaloria 0.0.1"
   git push origin v0.0.1
   ```

3. Auf GitHub **Actions → Release → Run workflow** wählen und als `release_tag`
   `v0.0.1` angeben.

Der Workflow prüft Tag, Version und Release-Notiz, führt `swift test` aus, baut
ein Release-App-Bundle und veröffentlicht das DMG zusammen mit der Notiz als
GitHub Release. Dafür muss der selbst gehostete macOS-ARM64-Runner online sein.
