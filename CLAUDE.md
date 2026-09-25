# maui-platforms — agent notes

Demonstrator (not production) for running the **default .NET MAUI app** on the three experimental
[dotnet/maui-labs](https://github.com/dotnet/maui-labs) desktop backends: **WPF**, **GTK4** and **macOS AppKit**.
Goal: understand the current state of the art, so document breakage rather than hide it.

## Ground rules

- Always the latest **.NET 11 / MAUI 11** (RC now, GA when released) — `global.json` pins the SDK; bump it, never downgrade.
- `src/MauiPlatforms` is the output of `dotnet new maui -f net11.0` **plus only the DevFlow agent registration**.
  Do not add app code there that the template would not have generated; put backend-specific code in the heads.
- All labs package versions live in `Directory.Build.props` (`MauiLabsVersion`); MAUI's own version comes from the
  workload (`$(MauiVersion)`), except the GTK4 head which pins `MauiControlsVersion` because it has no workload.
- Target matrix: WPF = win-arm64 + win-x64, GTK4 = linux-arm64 + linux-x64, AppKit = osx-arm64 only.

## Layout

| Path | What |
| --- | --- |
| `src/MauiPlatforms/` | Default MAUI app (android, ios, maccatalyst, windows/WinUI). Shared XAML + code for the heads. |
| `src/MauiPlatforms.Wpf/` | WPF head: `net11.0-windows`, `UseWPF` + `UseMaui`, `Microsoft.Maui.Platforms.Windows.WPF`. |
| `src/MauiPlatforms.Gtk4/` | GTK4 head: plain `net11.0` exe, `Microsoft.Maui.Platforms.Linux.Gtk4`. Runs on Linux (WSL2 Ubuntu 24.04 works). |
| `src/MauiPlatforms.MacOS/` | AppKit head: `net11.0-macos`, `Microsoft.Maui.Platforms.MacOS`. Builds only on a Mac. |
| `eng/` | `setup-windows.ps1`, `setup-linux.sh` machine setup scripts. |
| `docs/` | Status matrix and findings. |
| `.claude/skills/` | DevFlow skills installed by `maui devflow init` (refresh with `maui devflow skills update`). |

The heads **link** the shared app's `*.cs`, `*.xaml` and `Resources/**` with wildcards (see each head's csproj), the
same pattern as `samples/DevFlow.Sample.*` in maui-labs. Each head has its own `MauiProgram.cs` whose only difference
from the shared one is the hosting call (`UseMauiAppWPF`, `UseMauiAppLinuxGtk4`, `UseMauiAppMacOS`) and the
backend-specific DevFlow agent package.

## Building and running

```bash
dotnet build src/MauiPlatforms.Wpf                     # Windows (arm64 host); add -r win-x64 for x64
dotnet run   --project src/MauiPlatforms.Wpf
dotnet build src/MauiPlatforms -f net11.0-windows10.0.19041.0 -p:TargetFrameworks=net11.0-windows10.0.19041.0
dotnet run   --project src/MauiPlatforms.Gtk4 -r linux-arm64   # on Linux / WSL2 (see eng/setup-linux.sh)
dotnet build src/MauiPlatforms.MacOS                   # on macOS only (Xcode + `macos` workload)
```

`dotnet build MauiPlatforms.slnx` never fully succeeds on one OS — each head needs its own OS; build per project.
The `-p:TargetFrameworks=...` override lets the default app build with only the `maui-windows` workload installed.

## Tools in play

- **maui CLI** (`dotnet tool update -g Microsoft.Maui.Cli --prerelease`): `maui doctor`, `maui devflow ...`.
- **DevFlow**: every project registers `AddMauiDevFlowAgent()` under `#if DEBUG`. Start `maui devflow broker start`,
  run an app, then `maui devflow list`, `maui devflow ui tree --depth 2`, `maui devflow ui screenshot --output x.png`.
  `maui devflow mcp` exposes the same as an MCP server.
- **Skills**: `.claude/settings.json` registers the maui-labs plugin marketplace (`dotnet-maui`, `dotnet-maui-tooling`);
  the three `maui-devflow-*` skills also exist as project skills from `maui devflow init` (same content, CLI-versioned).
- **Templates**: `maui-wpf`, `maui-linux-gtk4` (`dotnet new install Microsoft.Maui.Platforms.<x>.Templates::<MauiLabsVersion>`).
  No macOS template package is published; the macOS head was hand-built from `platforms/MacOS/templates` in maui-labs.

## When something breaks

Record it in `docs/status.md` with the package versions involved. The labs backends are compiled against MAUI 10.0.41;
running them on MAUI 11 RC is the experiment, so `MissingMethodException`-style failures are findings, not bugs to hide.
