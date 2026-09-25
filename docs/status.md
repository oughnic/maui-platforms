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
| macOS AppKit | osx-arm64 | not attempted (no Mac) | — | — |
| Default app (WinUI) | win-arm64 | ✅ Windows TFM only (`-p:TargetFrameworks=net11.0-windows10.0.19041.0`) | not run | agent added |

### GTK4 run

Built inside WSL2 Ubuntu 24.04.5 (aarch64, GTK 4.14.5, .NET SDK 11.0.100-rc.1 installed by `eng/setup-linux.sh`) from
a Linux-filesystem copy of the repo, then launched from `bin/Debug/net11.0/linux-arm64/`. The window appears on the
Windows desktop through WSLg (title `MauiPlatforms (Ubuntu-24.04)`), see `docs/screenshots/gtk4-linux-arm64.png`.

- The page renders: image, both labels and the button, Open Sans font loaded from the linked `MauiFont` items.
- Differences from WPF/WinUI: **no Shell navigation bar or flyout button** is drawn for the single-item `AppShell`
  (WPF draws the "Home" bar with ☰), and the two-line "Welcome to / .NET Multi-platform App UI" label is left-aligned
  inside its centred block instead of centred. GTK's default light theme is used (WPF followed the Windows dark theme).
- `libEGL warning … MESA: error: ZINK: failed to choose pdev` on startup is WSLg without GPU passthrough falling back
  to software rendering; harmless.

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
package is not on nuget.org. `src/MauiPlatforms.MacOS` was hand-built from `platforms/MacOS/templates/maui-macos-app`
and `samples/DevFlow.Sample.MacOS`.

### F5. DevFlow's build targets break XAML code generation in a plain-TFM (GTK4) project

`Microsoft.Maui.DevFlow.Agent.Core.targets` hooks MAUI's XAML AdditionalFiles pipeline
(`_MauiInjectXamlCssAdditionalFiles`) only when the TFM is android/ios/maccatalyst/windows. For a plain `net11.0` project
it instead adds `@(MauiXaml)` as untyped AdditionalFiles, and the MAUI XAML source generator then emits no
`InitializeComponent` partials at all (`CS0103: The name 'InitializeComponent' does not exist`). The WPF head is
unaffected because `net11.0-windows` takes the other branch.

Workaround in `src/MauiPlatforms.Gtk4/MauiPlatforms.Gtk4.csproj`: `<DevFlowXamlSourceMapsEnabled>false</DevFlowXamlSourceMapsEnabled>`.

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

- The `maui` CLI README documents `maui ai init`; the published CLI (preview.12) has no `ai` command. The DevFlow skills
  come from `maui devflow init` (`.claude/skills/maui-devflow-*`) and the rest from the plugin marketplace.
- The labs marketplace manifest lives at `.github/plugin/marketplace.json` (Copilot CLI convention). Claude Code expects
  `.claude-plugin/marketplace.json`, so `/plugin marketplace add dotnet/maui-labs` alone does not find it;
  `.claude/settings.json` registers it with an explicit `path`.
- The plugin manifests are `plugins/<name>/plugin.json` rather than `.claude-plugin/plugin.json`; Claude Code should
  fall back to the marketplace entry as the manifest and auto-discover `skills/`.

### F11. WSL distro age matters

The pre-existing WSL Ubuntu 20.04 has no GTK4 packages; Ubuntu 24.04 ships GTK 4.14.5, above the backend's 4.12 minimum.

## Environment changes made on this machine

- `maui` CLI updated to 0.1.0-preview.12; labs templates `maui-wpf` / `maui-linux-gtk4` and `Microsoft.Maui.Templates.net11` installed.
- .NET 11 RC1 arm64 SDK installed **user-locally** in `%USERPROFILE%\.dotnet` with the `maui-windows` workload (removable; superseded by a machine-wide install).
- WSL distro `Ubuntu-24.04` added (root only, no user account yet; the default distro is still `Ubuntu`).
- `.claude/skills/*` written by `maui devflow init`; `~/.maui/devflow/workspaces/*` state created by the CLI.

## Re-testing

Bump `MauiLabsVersion` in `Directory.Build.props` (and `global.json` / `MauiControlsVersion` for new .NET/MAUI drops),
then rebuild each head and re-check F2–F7. The `maui-wpf` / `maui-linux-gtk4` templates can be re-checked with
`dotnet new <template> -o /tmp/x && dotnet build /tmp/x`.
