#!/bin/bash
# Build Flatpak for Thermal Monitor
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

APP_ID="io.github.andresgarcia0313.ThermalMonitor"

echo "=== Building Flatpak for $APP_ID ==="

# Check if flatpak-builder is installed
if ! command -v flatpak-builder &> /dev/null; then
    echo "Error: flatpak-builder not installed"
    echo "Install with: sudo apt install flatpak-builder"
    exit 1
fi

# Install required SDK and runtime
echo "[1/5] Installing Flatpak SDK..."
flatpak install -y flathub org.freedesktop.Platform//23.08 2>/dev/null || true
flatpak install -y flathub org.freedesktop.Sdk//23.08 2>/dev/null || true
flatpak install -y flathub org.freedesktop.Sdk.Extension.rust-stable//23.08 2>/dev/null || true

# Clean previous builds
echo "[2/5] Cleaning previous builds..."
rm -rf .flatpak-builder build-dir repo

# Build the Flatpak
echo "[3/5] Building Flatpak (this may take a while)..."
flatpak-builder --force-clean --user --install-deps-from=flathub \
    build-dir flatpak/${APP_ID}.yml

# Create repo and bundle
echo "[4/5] Creating bundle..."
flatpak-builder --repo=repo --force-clean build-dir flatpak/${APP_ID}.yml
flatpak build-bundle repo ${APP_ID}.flatpak $APP_ID

echo "[5/5] Done!"
echo ""
echo "=== Build Complete ==="
ls -lh ${APP_ID}.flatpak

echo ""
echo "To install locally:"
echo "  flatpak install --user ${APP_ID}.flatpak"
echo ""
echo "To run:"
echo "  flatpak run $APP_ID"
echo ""
echo "To uninstall:"
echo "  flatpak uninstall $APP_ID"
