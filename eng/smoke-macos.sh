#!/usr/bin/env bash
# Build the AppKit head, launch it, and drive it through DevFlow (list, tree, tap, screenshot). Run on the Mac as the
# user who is logged in at the console (a remote SSH session of that user works).
#
#   bash eng/smoke-macos.sh                       # expects Xcode 26.6 (what the .NET 11 RC1 macOS workload asks for)
#   VALIDATE_XCODE=false bash eng/smoke-macos.sh  # skip the Xcode version check (e.g. Xcode 26.5), see docs/status.md F13
set -uo pipefail
export DOTNET_ROOT=${DOTNET_ROOT:-$HOME/.dotnet}
export PATH=$DOTNET_ROOT:$HOME/.dotnet/tools:$PATH
export DOTNET_CLI_TELEMETRY_OPTOUT=1
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
EXTRA=()
[[ "${VALIDATE_XCODE:-true}" == "false" ]] && EXTRA+=(-p:ValidateXcodeVersion=false)

echo "==> dotnet $(dotnet --version), $(xcodebuild -version | head -1), macOS $(sw_vers -productVersion)"
echo "==> build"
dotnet build src/MauiPlatforms.MacOS/MauiPlatforms.MacOS.csproj -c Debug --nologo -v minimal "${EXTRA[@]}" 2>&1 | grep -vE '^\s*$|NETSDK1057' | tail -8
APP=$(ls -d src/MauiPlatforms.MacOS/bin/Debug/net11.0-macos/osx-arm64/*.app 2>/dev/null | head -1)
[ -n "$APP" ] || { echo "no app bundle produced"; exit 1; }

echo "==> launch $APP"
maui devflow broker start >/dev/null 2>&1 || true
pkill -f 'MacOS/MauiPlatforms.MacOS' 2>/dev/null || true
nohup "$APP/Contents/MacOS/MauiPlatforms.MacOS" > /tmp/mauiplatforms-macos.log 2>&1 &
sleep 12
echo "==> app log"; tail -5 /tmp/mauiplatforms-macos.log

echo "==> DevFlow"
maui devflow list | grep -E '"(platform|appName|port)"'
maui devflow ui tree --depth 8 | grep -E '"type"' | sed -E 's/^\s+//' | sort | uniq -c | sort -rn | head -12
maui devflow ui tap --text "Click me" --and-screenshot /tmp/mauiplatforms-macos.png
maui devflow ui query --type Button | grep -E '"text"' | head -1
echo "==> screenshot: /tmp/mauiplatforms-macos.png (app left running; 'pkill -f MauiPlatforms.MacOS' to stop)"
