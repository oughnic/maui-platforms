# Status and findings

Last updated: 2026-09-25. Machine: Surface Pro 9 (Microsoft SQ3, Windows 11 ARM64), WSL2 Ubuntu 24.04 (aarch64).

Versions: .NET SDK 11.0.100-rc.1.26425.128, MAUI 11.0.0-rc.1.26451.6, maui-labs 0.1.0-preview.12.26421.1
(backends, DevFlow, `maui` CLI), labs repo `main` @ `1002267` (2026-09-24).

## Result matrix

| Head | RID | Restore/build | Run | DevFlow |
| --- | --- | --- | --- | --- |
| WPF | win-arm64 | ✅ 0 warnings | ✅ default app renders (Shell flyout, image, labels, button) | ✅ agent registers with broker, `ui tree` / `ui screenshot` work; see F7 |
| WPF | win-x64 | ✅ cross-built on arm64 | not run (no x64 hardware here) | — |
| GTK4 | linux-arm64 | ✅ compiled on Windows and on Ubuntu 24.04 | ✅ default app renders under WSLg (see "GTK4 run") | ❌ agent does not start with the new backend (F5/F6) |
| GTK4 | linux-x64 | ✅ cross-compiled | not run | — |
| macOS AppKit | osx-arm64 | ✅ CI (`macos-26`, Xcode 26.6) and Stepney (Xcode 26.5 with `-p:ValidateXcodeVersion=false`) | ✅ default app renders (see "macOS AppKit run") | ✅ agent registers, full page in `ui tree`, `ui tap --text "Click me"` works |
| Default app (WinUI) | win-arm64 | ✅ Windows TFM only (`-p:TargetFrameworks=net11.0-windows10.0.19041.0`) | not run | agent added |

### GTK4 run

Built inside WSL2 Ubuntu 24.04.5 (aarch64, GTK 4.14.5, .NET SDK 11.0.100-rc.1 installed by `eng/setup-linux.sh`) from
a Linux-filesystem copy of the repo, then launched from `bin/Debug/net11.0/linux-arm64/`. The window appears on the
Windows desktop through WSLg (title `MauiPlatforms (Ubuntu-24.04)`), see `docs/screenshots/gtk4-linux-arm64.png`.

- The page renders: image, both labels and the button, Open Sans font loaded from the linked `MauiFont` items.
- Differences from WPF/WinUI: **no Shell navigation bar or flyout button** is drawn for the single-item `AppShell`
  (WPF draws the "Home" bar with ☰), and the two-line "Welcome to / .NET Multi-platform App UI" label is left-aligned
  inside its centred block instead of centred. GTK's default light theme is used (WPF followed the Windows dark theme).
- `libEGL warning … MESA: error: ZINK: failed to choose pdev` on startup is GTK's GL renderer failing to open a GPU
  through WSLg (`/dev/dxg` and the D3D12 libraries are present, but Mesa 25.2 cannot use them on this Arm64 box) and
  falling back to software rendering. Harmless, and `GSK_RENDERER=cairo ./MauiPlatforms.Gtk4` skips the GL attempt for
  a silent start (verified: zero log lines, app runs).
- The first button click originally crashed the handler (F15); fixed by registering the labs Essentials.

### macOS AppKit run

Built and run on Stepney (Mac, Apple Silicon, macOS 26.6.2, Xcode 26.5, .NET SDK 11.0.100-rc.1 in `~/.dotnet` via
`eng/setup-macos.sh`) over SSH with `-p:ValidateXcodeVersion=false` (F13) and the DevFlow XAML workaround (F5). The
app bundle `bin/Debug/net11.0-macos/osx-arm64/MauiPlatforms.app` launches from the console user's session; see
`docs/screenshots/macos-osx-arm64.png`.

- Renders as a native AppKit window: Shell flyout button (☰) and "MauiPlatforms" title in the toolbar, then the page
  (image, both labels, button) in a scroll view.
- DevFlow is the best of the three backends here: the agent registers with the broker (`platform: "macOS"`), `ui tree`
  shows the full hierarchy down to `MainPage → MacOSContainerView → ScrollView → VerticalStackLayout`, and
  `ui tap --text "Click me"` succeeds twice, after which `ui query --type Button` reports `"Clicked 2 times"`.
- The app log shows the backend's own diagnostics (`[WindowHandler.MapContent] page=AppShell, handler=ShellHandler`)
  and the agent start (`Agent started on port 10223`).
- The first run had no `dotnet_bot.png` and used the system font: shared `MauiImage`/`MauiFont` items are not bundled
  on this TFM (F14). With explicit `BundleResource` items the image and Open Sans render, as in the screenshot.
- Two labs-side prerequisites for a local build: `-p:ValidateXcodeVersion=false` on Xcode 26.5 (F13) and
  `DevFlowXamlSourceMapsEnabled=false` for Debug builds (F5). `eng/smoke-macos.sh` wraps the whole loop.

### Smoke tests

`eng/smoke-macos.sh` is a real test: it builds the AppKit head (Debug, so the DevFlow agent is compiled in), launches
it, waits for the agent to register with the broker, checks `MainPage` is in the DevFlow tree, taps "Click me" by
text, asserts the button now reads "Clicked 1 time", takes a screenshot and shuts everything down, exiting non-zero
on any failure. It passes on Stepney and runs in CI as the `smoke-macos` job on `macos-26` (screenshot and logs are
uploaded as the `smoke-macos` artifact).

Only the AppKit head has a smoke test for now: DevFlow cannot tap the WPF head's page (F7, maui-labs#522) and the GTK4
agent does not start (F6, maui-labs#521). Both heads were exercised by hand instead (real mouse click on WPF, xdotool
on GTK4 under X11) and count clicks correctly.

## Findings

Numbered so they can be referenced from the code and from issues filed against dotnet/maui-labs.

### F1. The labs backends are MAUI 10 packages, but they work on MAUI 11 RC1 (so far)

`Microsoft.Maui.Platforms.Windows.WPF`, `.Linux.Gtk4` and `.MacOS` 0.1.0-preview.12 target `net10.0-windows7.0`,
`net10.0` and `net10.0-macos26.0` respectively and depend on `Microsoft.Maui.Controls >= 10.0.41`. Referencing them from
`net11.0*` projects with `Microsoft.Maui.Controls 11.0.0-rc.1` simply unifies upwards; the WPF head builds with zero
warnings and runs the default app without any runtime binding failures. Nothing in MAUI 11 RC1's public surface that the
default app touches has broken the backends.

### F2. The `maui-wpf` template (preview.12) does not build as generated

- `<PackageReference Include="Microsoft.Maui.Platforms.Windows.WPF" Version="0.1.0-preview" />` is a floating
  minimum that resolves to the oldest matching prerelease (preview.8), not the latest.
- On the .NET 10 SDK 10.0.401 the bundled MAUI is 10.0.20, below the backend's 10.0.41 minimum → `NU1605` package
  downgrade error unless `Microsoft.Maui.Controls` is referenced explicitly.
- Its `Program.cs` has `using System.Windows;` next to MAUI's implicit usings → `CS0104: 'Application' is ambiguous`.

The pattern used by the labs' own samples (`MauiWPFApplication` subclass + `[STAThread] Main`, `UseMauiAppWPF<App>()`,
`UseWPFEssentials()`) works and is what `src/MauiPlatforms.Wpf` uses.

### F3. The `maui-linux-gtk4` template references a package version that does not exist

It emits `Version="0.6.0-*"` for `Microsoft.Maui.Platforms.Linux.Gtk4` (+ Essentials). Those IDs only exist as
`0.1.0-preview.*` on nuget.org; `0.6.0` is the last version of the *previous* package ID `Platform.Maui.Linux.Gtk4`.
Restore fails out of the box. The head pins `$(MauiLabsVersion)` instead.

### F4. No macOS template package is published

Docs and the labs README describe `dotnet new install Microsoft.Maui.Platforms.MacOS.Templates --prerelease`, but the
package is not on nuget.org. The template packaging was merged in
[dotnet/maui-labs#466](https://github.com/dotnet/maui-labs/pull/466) on 2026-09-02, after the preview.12 build
(2026-08-21), so it should appear with the next labs release; no issue filed. `src/MauiPlatforms.MacOS` was hand-built
from `platforms/MacOS/templates/maui-macos-app` and `samples/DevFlow.Sample.MacOS`.

### F5. DevFlow's build targets break XAML code generation in a plain-TFM (GTK4) project

`Microsoft.Maui.DevFlow.Agent.Core.targets` hooks MAUI's XAML AdditionalFiles pipeline
(`_MauiInjectXamlCssAdditionalFiles`) only when the TFM is android/ios/maccatalyst/windows. For a plain `net11.0` project
it instead adds `@(MauiXaml)` as untyped AdditionalFiles, and the MAUI XAML source generator then emits no
`InitializeComponent` partials at all (`CS0103: The name 'InitializeComponent' does not exist`). The WPF head is
unaffected because `net11.0-windows` takes the other branch.

Workaround in `src/MauiPlatforms.Gtk4/MauiPlatforms.Gtk4.csproj`: `<DevFlowXamlSourceMapsEnabled>false</DevFlowXamlSourceMapsEnabled>`.

**Also hits `net11.0-macos`** (the AppKit head): `macos` is missing from the same TFM list, so a Debug build on the Mac
produced the identical six CS0103 errors. Release builds are unaffected because the source maps are Debug-only
(`Microsoft.Maui.DevFlow.Agent.Core.props`), which is why the `-c Release` CI job passed. Same workaround applied to
`src/MauiPlatforms.MacOS/MauiPlatforms.MacOS.csproj`; noted on dotnet/maui-labs#520.

### F6. `Microsoft.Maui.DevFlow.Agent.Gtk` depends on the superseded backend package

`Microsoft.Maui.DevFlow.Agent.Gtk` 0.1.0-preview.12 depends on `Platform.Maui.Linux.Gtk4 0.6.0` (the labs repo's
`Microsoft.Maui.DevFlow.Agent.Gtk.csproj` still uses that package ID). Adding the agent to a
`Microsoft.Maui.Platforms.Linux.Gtk4` app therefore ships two GTK backends (`Platform.Maui.Linux.Gtk4.dll` and
`Microsoft.Maui.Platforms.Linux.Gtk4.dll`) plus two sets of MSBuild targets.

Tested on Ubuntu 24.04 (arm64) with `-p:MauiGtk4DevFlow=true`: the app builds and runs, but **the agent never starts**:
no `[Microsoft.Maui.DevFlow]` lines in the app output (the WPF agent prints `HTTP server started on port …`), nothing
listening (`ss -ltnp`), and `maui devflow --agent-port 9223 agent status` from Windows cannot connect. The agent
assembly references the old `Platform.Maui.Linux.Gtk` namespace and exposes `StartDevFlowAgent()` as a hook on the old
backend's application type, which `Microsoft.Maui.Platforms.Linux.Gtk4.Platform.GtkMauiApplication` does not derive
from. So DevFlow for GTK is not usable with the new backend package until `Microsoft.Maui.DevFlow.Agent.Gtk` is rebuilt
against `Microsoft.Maui.Platforms.Linux.Gtk4`.

The GTK4 head therefore makes DevFlow opt-in: `dotnet build src/MauiPlatforms.Gtk4 -p:MauiGtk4DevFlow=true`.

### F7. DevFlow WPF agent sees the Shell chrome, not the page

With the WPF head running, `maui devflow ui tree` returns Window → AppShell → ShellItem/ShellSection/ShellContent and
the flyout/nav-bar buttons, but none of `MainPage`'s elements (Image, Labels, Button). `ui query --type Button` only
finds native WPF buttons; `ui query --type Label` returns nothing. `ui hit-test 533 461` does find the button's text
through UI Automation (`native:uia-runtime:…`), but tapping that element returns `success: false`. Screenshots and the
agent/broker plumbing work.

### F8. Apps built with a user-local SDK show the ".NET must be installed" dialog

The .NET 11 SDK was installed with `dotnet-install.ps1` into `%USERPROFILE%\.dotnet` (no admin rights in the session).
Building works, but launching the produced `.exe` directly fails because the apphost looks in `C:\Program Files\dotnet`.
Set `DOTNET_ROOT=%USERPROFILE%\.dotnet` (or use `dotnet run`), or install the SDK machine-wide with `eng/setup-windows.ps1`.

### F9. `maui doctor` reports the Windows SDK as missing although VS 2026 is installed

`E2301 Windows SDK not found`. The WinUI build of the default app succeeded regardless (the Windows SDK projections come
from NuGet). Everything else (JDK 21, Android SDK, emulator, licences) is green.

### F10. Skills / marketplace plumbing differs from the README

- The labs README documents `maui ai init`; the published CLI (preview.12) has no `ai` command. The command group was
  added on `main` ([dotnet/maui-labs#98](https://github.com/dotnet/maui-labs/pull/98), docs in
  [#513](https://github.com/dotnet/maui-labs/pull/513), merged 2026-09-22) and is simply not released yet. Until then
  the DevFlow skills come from `maui devflow init` (`.claude/skills/maui-devflow-*`) and the rest from the plugin
  marketplace.
- The labs marketplace manifest lives at `.github/plugin/marketplace.json` (Copilot CLI convention). Claude Code expects
  `.claude-plugin/marketplace.json`, so `/plugin marketplace add dotnet/maui-labs` alone does not find it;
  `.claude/settings.json` registers it with an explicit `path`.
- The plugin manifests are `plugins/<name>/plugin.json` rather than `.claude-plugin/plugin.json`; Claude Code should
  fall back to the marketplace entry as the manifest and auto-discover `skills/`.

### F12. A `UseMaui` project on `net11.0-macos` needs the `maui-tizen` workload (or `maui`)

The first CI run of the AppKit head failed with `NETSDK1147: To build this project, the following workloads must be
installed: maui-tizen`. The `macos` workload only provides the TFM; the MAUI SDK packs come from the abstract `maui-core`
workload, and the smallest concrete workload that carries them without extra platform packs is `maui-tizen`. Installing
`macos maui-tizen` fixed it (`maui` would too, at a much larger download). `eng/setup-macos.sh` does the same.

### F13. The .NET 11 RC1 macOS workload demands Xcode 26.6; Xcode 26.5 works with the check disabled

`Microsoft.macOS.Sdk.net11.0_26.5` 26.5.12194-net11-rc.1 fails the build with
`error : This version of .NET for macOS (26.5.12194-net11-rc.1) requires Xcode 26.6. The current version of Xcode is 26.5`
(target `_ValidateXcodeVersion` in `Xamarin.Shared.Sdk.targets`). The GitHub `macos-26` runner has 26.6 so CI passes;
Stepney has 26.5 and 26.2. Building with `-p:ValidateXcodeVersion=false` skips the check and the app builds, runs and
passes DevFlow interaction on Xcode 26.5. Installing Xcode 26.6 (Xcodes.app is on the Mac) removes the need for the switch.

### F14. On the AppKit head, `MauiImage` / `MauiFont` / `MauiAsset` never reach the app bundle

The first macOS run rendered the labels and button but no `dotnet_bot.png`, and text fell back to the system font.
`Contents/Resources` held only `AppIcon.icns`: the labs macOS targets (`Microsoft.Maui.Platforms.MacOS.targets`) only
process `MauiIcon` (SVG → `.icns` via `sips`/`iconutil`), and MAUI's Resizetizer does not run for the `macos` TFM, so
`MauiImage`/`MauiFont`/`MauiAsset` items are silently ignored. The backend looks for images in
`<bundle>/Contents/Resources/Images` (`ImageHandler`) and pre-registers `*.ttf` from `.../Fonts` (`MacOSFontRegistrar`).

The labs samples get away with it because their `Resources/` folder is physically inside the head project, where the
macOS SDK's default `BundleResource` globbing picks it up (and `DevFlow.Sample.MacOS` adds an explicit `BundleResource`
for the one file it shares). For a head that links a shared project, add `BundleResource` items with
`Link="Resources\Images\…"` / `Link="Resources\Fonts\…"` (the SDK strips the leading `Resources\`), as
`src/MauiPlatforms.MacOS/MauiPlatforms.MacOS.csproj` now does; after that the bundle contains `Images/dotnet_bot.png`,
`Fonts/OpenSans-*.ttf`, `Raw/AboutAssets.txt` and both image and font render. Worth a docs note or targets support in
the backend; not filed as an issue yet.

### F15. GTK4 head crashed on the first button click until the labs Essentials were registered

Clicking "Click me" on the GTK4 head (WSL2 Ubuntu 24.04) logged:

```
UnhandledException - unhandled exception: Microsoft.Maui.ApplicationModel.NotImplementedInReferenceAssemblyException:
This functionality is not implemented in the portable version of this assembly. ...
   at Microsoft.Maui.Accessibility.SemanticScreenReaderImplementation.Announce(String text)
   at MauiPlatforms.MainPage.OnCounterClicked(...) in src/MauiPlatforms/MainPage.xaml.cs:line 21
```

The default template's click handler calls `SemanticScreenReader.Announce`. Both the GTK4 and WPF heads resolve the
plain `lib/net11.0` (portable) build of `Microsoft.Maui.Essentials`, whose implementations throw unless a backend
supplies its own. The GTK4 head (like the labs `maui-linux-gtk4` template) referenced
`Microsoft.Maui.Platforms.Linux.Gtk4.Essentials` but never called `AddLinuxGtk4Essentials()`; the WPF head calls
`UseWPFEssentials()` and the macOS head `AddMacOSEssentials()`, and neither crashes (verified with real clicks: WPF
and GTK4 both count clicks afterwards). With `.AddLinuxGtk4Essentials()` added to `src/MauiPlatforms.Gtk4/MauiProgram.cs`
the GTK4 head counts clicks too; on Linux the screen reader implementation shells out to `spd-say`, so nothing is
spoken unless speech-dispatcher is installed. Template omission noted on dotnet/maui-labs#519.

### F11. WSL distro age matters

The pre-existing WSL Ubuntu 20.04 has no GTK4 packages; Ubuntu 24.04 ships GTK 4.14.5, above the backend's 4.12 minimum.

## Issues filed against dotnet/maui-labs (2026-09-25)

| Finding | Issue |
| --- | --- |
| F2 `maui-wpf` template does not restore/build | [dotnet/maui-labs#518](https://github.com/dotnet/maui-labs/issues/518) |
| F3 `maui-linux-gtk4` template references non-existent `0.6.0-*` | [dotnet/maui-labs#519](https://github.com/dotnet/maui-labs/issues/519) |
| F5 DevFlow targets break XAML source generation on plain TFMs | [dotnet/maui-labs#520](https://github.com/dotnet/maui-labs/issues/520) |
| F6 DevFlow GTK agent depends on the superseded backend package | [dotnet/maui-labs#521](https://github.com/dotnet/maui-labs/issues/521) |
| F7 DevFlow WPF agent omits page content under Shell | [dotnet/maui-labs#522](https://github.com/dotnet/maui-labs/issues/522) |

No existing issues covered these (searched open and closed issues first). F4 and F10 are already fixed on `main` and
await a release, so nothing was filed for them.

## Environment changes made on this machine

- `maui` CLI updated to 0.1.0-preview.12; labs templates `maui-wpf` / `maui-linux-gtk4` and `Microsoft.Maui.Templates.net11` installed.
- .NET 11 RC1 arm64 SDK first installed **user-locally** in `%USERPROFILE%\.dotnet` with the `maui-windows` workload
  (now redundant and removable), then machine-wide with the full `maui` workload via `eng/setup-windows.ps1`.
- WSL distro `Ubuntu-24.04` added and made the default; user `nicholas` created (passwordless sudo, default user via
  `/etc/wsl.conf`), `eng/setup-linux.sh` run for that user, repo cloned to `~/maui-platforms`. The GTK4 head builds there.
- `.claude/skills/*` written by `maui devflow init`; `~/.maui/devflow/workspaces/*` state created by the CLI.
- SSH key `%USERPROFILE%\.ssh\id_ed25519` generated for reaching the Mac (Stepney, 10.0.0.23).

## Re-testing

Bump `MauiLabsVersion` in `Directory.Build.props` (and `global.json` / `MauiControlsVersion` for new .NET/MAUI drops),
then rebuild each head and re-check F2–F7. The `maui-wpf` / `maui-linux-gtk4` templates can be re-checked with
`dotnet new <template> -o /tmp/x && dotnet build /tmp/x`.
