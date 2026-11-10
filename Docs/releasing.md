# Publishing a release

The GitHub **Release** workflow is started manually and builds only a pushed tag whose name matches the app version.

For version `0.0.1`:

1. Commit and push the changes, including `Sources/Novaloria/AppVersion.swift` and `Docs/releases/0.0.1.md`, to the default branch.
2. Create and push a tag on that exact commit:

   ```bash
   git tag -a v0.0.1 -m "Novaloria 0.0.1"
   git push origin v0.0.1
   ```

3. On GitHub, select **Actions → Release → Run workflow** and enter `v0.0.1` as `release_tag`.

The workflow validates the tag, version and release notes, runs `swift test`, builds a release app bundle, and publishes the DMG together with the notes as a GitHub Release. The self-hosted macOS ARM64 runner must be online.

For the German version, see [releasing_DE.md](releasing_DE.md).
