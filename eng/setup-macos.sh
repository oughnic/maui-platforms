#!/usr/bin/env bash
# Sets up an Apple Silicon Mac to build and run the AppKit head (and, with -m/--mobile, the default app's iOS/Mac Catalyst targets).
#
#   bash eng/setup-macos.sh            # macos + maui-tizen workloads (enough for src/MauiPlatforms.MacOS)
#   bash eng/setup-macos.sh --mobile   # also the full 'maui' workload (android, ios, maccatalyst)
#
# What it does (no sudo needed):
#   1. Checks Xcode + command line tools are present (`xcode-select -p`); the net11.0-macos workload needs Xcode 26.
#   2. Installs the exact .NET SDK pinned in global.json into ~/.dotnet.
#   3. Installs the workloads: `macos` gives the net11.0-macos TFM, `maui-tizen` is the smallest workload that carries the
#      MAUI SDK packs a UseMaui project on that TFM needs (the SDK asks for it with NETSDK1147 otherwise).
#   4. Installs/updates the maui CLI (DevFlow) and adds ~/.dotnet to PATH for future shells (zsh and bash).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK_VERSION="$(grep -oE '"version"\s*:\s*"[^"]+"' "$REPO_ROOT/global.json" | head -1 | sed -E 's/.*"([^"]+)"$/\1/')"
WORKLOADS="macos maui-tizen"
[[ "${1:-}" == "--mobile" || "${1:-}" == "-m" ]] && WORKLOADS="macos maui"

if [[ "$(uname -m)" != "arm64" ]]; then echo "This repo targets osx-arm64 only; this Mac reports $(uname -m)." >&2; exit 1; fi
echo "==> macOS $(sw_vers -productVersion) on $(uname -m)"
if ! xcode-select -p >/dev/null 2>&1; then echo "Xcode command line tools are missing: run 'xcode-select --install' (and install Xcode 26 from the App Store) first." >&2; exit 1; fi
echo "==> Xcode: $(xcodebuild -version 2>/dev/null | tr '\n' ' ' || echo 'xcodebuild not available')"

echo "==> Installing .NET SDK $SDK_VERSION into ~/.dotnet"
curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
bash /tmp/dotnet-install.sh --version "$SDK_VERSION" --install-dir "$HOME/.dotnet"

for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  if ! grep -q 'DOTNET_ROOT=\$HOME/.dotnet' "$rc" 2>/dev/null; then
    {
      echo ''
      echo '# .NET SDK (added by maui-platforms/eng/setup-macos.sh)'
      echo 'export DOTNET_ROOT=$HOME/.dotnet'
      echo 'export PATH=$HOME/.dotnet:$HOME/.dotnet/tools:$PATH'
    } >> "$rc"
  fi
done
export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$HOME/.dotnet:$HOME/.dotnet/tools:$PATH"

echo "==> dotnet $(dotnet --version)"
echo "==> Installing workloads: $WORKLOADS"
dotnet workload install $WORKLOADS

echo "==> Installing/updating the maui CLI (DevFlow)"
dotnet tool update -g Microsoft.Maui.Cli --prerelease

cat <<EOF

Done. Open a new shell (or 'source ~/.zshrc') and run:

  cd $REPO_ROOT
  dotnet build src/MauiPlatforms.MacOS
  dotnet run --project src/MauiPlatforms.MacOS

  maui doctor            # environment check
  maui apple xcode list  # installed Xcode versions

EOF
