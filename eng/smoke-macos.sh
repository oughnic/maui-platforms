#!/usr/bin/env bash
# Smoke test for the AppKit head. Builds it (Debug, so the DevFlow agent is compiled in), launches it, drives it through
# DevFlow (waits for the agent, checks the page is in the tree, taps the counter button, asserts the button text),
# takes a screenshot, then shuts everything down. The exit code is the test result. Runs locally on a Mac (as the user
# logged in at the console; an SSH session of that user is fine) and in the GitHub Actions `smoke-macos` job.
#
#   bash eng/smoke-macos.sh                       # expects Xcode 26.6 (what the .NET 11 RC1 macOS workload asks for)
#   VALIDATE_XCODE=false bash eng/smoke-macos.sh  # skip the Xcode version check (e.g. Xcode 26.5), see docs/status.md F13
#   SMOKE_OUT=/some/dir bash eng/smoke-macos.sh   # where the screenshot and logs go (default /tmp/maui-smoke)
set -uo pipefail
export DOTNET_ROOT=${DOTNET_ROOT:-$HOME/.dotnet}
export PATH=$DOTNET_ROOT:$HOME/.dotnet/tools:$PATH
export DOTNET_CLI_TELEMETRY_OPTOUT=1
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT=${SMOKE_OUT:-/tmp/maui-smoke}
mkdir -p "$OUT"; rm -f "$OUT"/*.log "$OUT"/tree.json   # no stale output from a previous run
cd "$REPO_ROOT"

# Plain string, not an array: macOS's /bin/bash is 3.2, where expanding an empty array under `set -u` aborts the script.
EXTRA=""
[[ "${VALIDATE_XCODE:-true}" == "false" ]] && EXTRA="-p:ValidateXcodeVersion=false"

cleanup() {
  pkill -f 'MacOS/MauiPlatforms.MacOS' 2>/dev/null
  maui devflow broker stop >/dev/null 2>&1 || true
}
fail() {
  echo "SMOKE FAIL: $*"
  if [ -f "$OUT/app.log" ]; then echo "--- app log (tail) ---"; tail -n 40 "$OUT/app.log"; fi
  exit 1
}
trap cleanup EXIT

echo "==> dotnet $(dotnet --version), $(xcodebuild -version 2>/dev/null | sed -n 1p), macOS $(sw_vers -productVersion), maui CLI $(maui --version 2>/dev/null | cut -d+ -f1), bash $BASH_VERSION"

echo "==> build src/MauiPlatforms.MacOS (Debug${EXTRA:+, $EXTRA})"
# shellcheck disable=SC2086  # $EXTRA is deliberately unquoted (empty or a single flag)
if ! dotnet build src/MauiPlatforms.MacOS/MauiPlatforms.MacOS.csproj -c Debug --nologo -v minimal $EXTRA > "$OUT/build.log" 2>&1; then
  grep -E 'error' "$OUT/build.log" | head -n 10
  fail "build failed (see $OUT/build.log)"
fi
APP=$(ls -d src/MauiPlatforms.MacOS/bin/Debug/net11.0-macos/osx-arm64/*.app 2>/dev/null | head -1)
[ -n "$APP" ] || fail "no app bundle produced"

echo "==> start broker and launch $APP"
maui devflow broker start >/dev/null 2>&1 || true
pkill -f 'MacOS/MauiPlatforms.MacOS' 2>/dev/null || true
# Launch through LaunchServices so the app lands in the GUI session and becomes active (the DevFlow agent starts on
# activation); a bare ./MauiPlatforms.MacOS worked on a Mac with a logged-in user but never activated on a CI runner.
open -n --stdout "$OUT/app.log" --stderr "$OUT/app.log" "$APP" || fail "open failed for $APP"
BUNDLE_ID=$(defaults read "$PWD/$APP/Contents/Info" CFBundleIdentifier 2>/dev/null || echo com.companyname.mauiplatforms)

echo "==> wait for the DevFlow agent (up to 60 s)"
for i in $(seq 1 60); do
  if maui devflow list 2>/dev/null | grep -q '"platform": *"macOS"'; then break; fi
  [ "$i" -gt 5 ] && ! pgrep -f 'MacOS/MauiPlatforms.MacOS' >/dev/null && fail "app exited before the agent registered"
  sleep 1
done
maui devflow list 2>/dev/null | grep -q '"platform": *"macOS"' || fail "DevFlow agent did not register with the broker"
maui devflow list | grep -E '"(platform|appName|port|tfm)"' | sed -E 's/^\s+//'

echo "==> wait for MainPage to appear in the visual tree (up to 45 s)"
# The agent registers before Shell has created and laid out the page, so poll rather than check once.
for i in $(seq 1 45); do
  maui devflow ui tree --depth 8 > "$OUT/tree.json" 2>&1
  grep -q '"type": *"MainPage"' "$OUT/tree.json" && break
  # nudge: bring the app to the front in case it is running but was never activated
  if [ "$i" = 5 ] || [ "$i" = 20 ]; then osascript -e "tell application id \"$BUNDLE_ID\" to activate" >/dev/null 2>&1 || true; fi
  sleep 1
done
if ! grep -q '"type": *"MainPage"' "$OUT/tree.json"; then
  echo "--- element types in the tree ---"; grep -o '"type": *"[^"]*"' "$OUT/tree.json" | sort | uniq -c | sort -rn | head -n 15
  fail "MainPage not found in the DevFlow tree after 45 s (see $OUT/tree.json)"
fi

echo "==> tap the counter button"
TAP=$(maui devflow ui tap --text "Click me" 2>&1)
echo "$TAP" | grep -q '"success": *true' || fail "tap did not succeed: $TAP"
sleep 1
TEXT=$(maui devflow ui query --type Button 2>/dev/null | grep -o '"text": *"[^"]*"' | head -1 | sed -E 's/.*: *"(.*)"/\1/')
[ "$TEXT" = "Clicked 1 time" ] || fail "expected the button to read 'Clicked 1 time', got '${TEXT:-<none>}'"

echo "==> screenshot"
maui devflow ui screenshot --output "$OUT/macos-after-tap.png" --overwrite >/dev/null 2>&1 || fail "screenshot failed"

echo "SMOKE PASS: AppKit head launched, DevFlow tapped the button, text is '$TEXT'; screenshot at $OUT/macos-after-tap.png"
