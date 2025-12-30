# Flatpak Packaging

## Build Locally

```bash
./flatpak/build-flatpak.sh
```

This creates `com.github.andresgarcia0313.ThermalMonitor.flatpak`.

## Install Locally

```bash
flatpak install --user com.github.andresgarcia0313.ThermalMonitor.flatpak
```

## Run

```bash
flatpak run com.github.andresgarcia0313.ThermalMonitor
```

## Publish to Flathub

### Option 1: GitHub Actions (Automatic)

The repository includes a GitHub Actions workflow (`.github/workflows/flatpak.yml`) that:
- Builds the Flatpak on every push to main
- Creates releases with `.flatpak` bundle when you create a tag

To trigger a release:
```bash
git tag v1.3.0
git push origin v1.3.0
```

### Option 2: Submit to Flathub Repository

1. Fork https://github.com/flathub/flathub
2. Copy `flatpak/flathub/com.github.andresgarcia0313.ThermalMonitor.yml`
3. Update the `commit:` field with the actual commit SHA
4. Create PR to flathub/flathub

### Option 3: New App Submission Portal

1. Go to https://flathub.org/apps/new
2. Follow the guided submission process
3. Provide the GitHub repository URL

## Update cargo-sources.json

When dependencies change:

```bash
python3 /tmp/generate_cargo_sources.py Cargo.lock > flatpak/cargo-sources.json
```

## Files

- `com.github.andresgarcia0313.ThermalMonitor.yml` - Flatpak manifest
- `com.github.andresgarcia0313.ThermalMonitor.desktop` - Desktop entry
- `com.github.andresgarcia0313.ThermalMonitor.metainfo.xml` - AppStream metadata
- `com.github.andresgarcia0313.ThermalMonitor.svg` - Application icon
- `cargo-sources.json` - Vendored Cargo dependencies
- `build-flatpak.sh` - Local build script
