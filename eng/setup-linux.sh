#!/usr/bin/env bash
# Sets up an Ubuntu 24.04 (or newer) machine / WSL2 distro to build and run the GTK4 head.
#
#   bash eng/setup-linux.sh
#
# What it does:
#   1. Installs the GTK4 + WebKitGTK development packages the labs backend needs (GTK >= 4.12).
#   2. Installs the exact .NET SDK pinned in global.json into ~/.dotnet (no sudo needed for that part).
#   3. Adds ~/.dotnet to PATH for future shells.
#
# Ubuntu 22.04 ships GTK 4.6 and Ubuntu 20.04 has no GTK4 at all, so use 24.04+ (in WSL: `wsl --install -d Ubuntu-24.04`).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK_VERSION="$(grep -oE '"version"\s*:\s*"[^"]+"' "$REPO_ROOT/global.json" | head -1 | sed -E 's/.*"([^"]+)"$/\1/')"

echo "==> Installing GTK4 / WebKitGTK development packages"
sudo apt-get update
sudo apt-get install -y \
  libgtk-4-dev libwebkitgtk-6.0-dev \
  gobject-introspection libgirepository1.0-dev \
  gir1.2-gtk-4.0 gir1.2-webkit-6.0 pkg-config \
  curl ca-certificates

echo "==> GTK4 version: $(pkg-config --modversion gtk4)"

echo "==> Installing .NET SDK $SDK_VERSION into ~/.dotnet"
curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
bash /tmp/dotnet-install.sh --version "$SDK_VERSION" --install-dir "$HOME/.dotnet"

if ! grep -q 'DOTNET_ROOT=\$HOME/.dotnet' "$HOME/.bashrc" 2>/dev/null; then
  {
    echo ''
    echo '# .NET SDK (added by maui-platforms/eng/setup-linux.sh)'
    echo 'export DOTNET_ROOT=$HOME/.dotnet'
    echo 'export PATH=$HOME/.dotnet:$HOME/.dotnet/tools:$PATH'
  } >> "$HOME/.bashrc"
fi
export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$HOME/.dotnet:$HOME/.dotnet/tools:$PATH"

echo "==> dotnet $(dotnet --version)"
echo "==> Installing the maui CLI (DevFlow) as a global tool"
dotnet tool update -g Microsoft.Maui.Cli --prerelease

cat <<EOF

Done. Open a new shell (or 'source ~/.bashrc') and run:

  cd $REPO_ROOT
  dotnet run --project src/MauiPlatforms.Gtk4 -r linux-$(uname -m | sed 's/aarch64/arm64/; s/x86_64/x64/')

Under WSLg without a usable GPU the app starts with harmless libEGL/MESA warnings; 'export GSK_RENDERER=cairo'
makes GTK skip the GL renderer and start silently.

EOF
