# Playbook: adding the maui-labs desktop backends (WPF, GTK4, macOS AppKit) to an existing .NET MAUI app

Everything learnt from building this demonstrator, written so that the next project can be extended in an afternoon
rather than a week. Follow the steps in order; every pitfall listed here was hit for real and each fix was verified.

State of play when this was written (2026-09-28): .NET SDK 11.0.100-rc.1, MAUI 11.0.0-rc.1.26451.6,
dotnet/maui-labs packages 0.1.0-preview.12.26421.1, `maui` CLI 0.1.0-preview.12. Section 13 lists what to re-check
when any of those move. The full incident log with evidence is in [status.md](status.md) (findings F1–F15).

## 1. What you get, in one table

| Backend | Package | Builds | Runs | DevFlow | Notes |
| --- | --- | :-: | :-: | :-: | --- |
| Windows WPF | `Microsoft.Maui.Platforms.Windows.WPF` (+ `.Essentials`) | ✅ win-arm64, win-x64 | ✅ | partial | Agent connects, screenshots work; page content not in the tree, so no DevFlow taps ([#522](https://github.com/dotnet/maui-labs/issues/522)) |
| Linux GTK4 | `Microsoft.Maui.Platforms.Linux.Gtk4` (+ `.Essentials`) | ✅ linux-arm64, linux-x64 | ✅ (Ubuntu 24.04, WSL2/WSLg) | ❌ released / ✅ fixed | Released agent targets the old backend package and never starts ([#521](https://github.com/dotnet/maui-labs/issues/521)); the fix in [#535](https://github.com/dotnet/maui-labs/pull/535) is verified with its CI packages (agent starts, full tree, taps) and awaits a release |
| macOS AppKit | `Microsoft.Maui.Platforms.MacOS` (+ `.Essentials`) | ✅ osx-arm64 | ✅ | ✅ full | Best DevFlow support: whole tree, `ui tap --text` works; smoke-tested locally and in CI |

All three backends are compiled against MAUI 10.0.41 and run unchanged on MAUI 11 RC1 with the default app. The
labs project templates (`maui-wpf`, `maui-linux-gtk4`) are broken as shipped ([#518](https://github.com/dotnet/maui-labs/issues/518),
[#519](https://github.com/dotnet/maui-labs/issues/519)) and there is no published macOS template package yet, so do
not start from the templates: start from the head projects in section 6–8, which are copy-paste ready.

## 2. The shape that works: thin head projects that link the shared app

Keep the existing MAUI app project exactly as it is (its android/ios/maccatalyst/windows-WinUI targets keep working)
and add one **head project per backend** next to it:

```
MyApp/                 existing single-project MAUI app (unchanged)
MyApp.Wpf/             net11.0-windows  + UseWPF + UseMaui        -> Microsoft.Maui.Platforms.Windows.WPF
MyApp.Gtk4/            net11.0 (plain, no MAUI workload needed)  -> Microsoft.Maui.Platforms.Linux.Gtk4
MyApp.MacOS/           net11.0-macos + UseMaui + SingleProject   -> Microsoft.Maui.Platforms.MacOS
```

Each head:

- **links** the shared app's `*.cs`, `*.xaml` and `Resources/**` with wildcards (no code duplication, no ProjectReference);
- excludes the shared `Platforms/**` folder and the shared `MauiProgram.cs`;
- has its own `MauiProgram.cs` (hosting call + backend Essentials + DevFlow agent) and its own entry point;
- uses the shared `App`, `AppShell` and pages unchanged (same `RootNamespace`, so the XAML `x:Class` names line up).

This is the same pattern as `samples/DevFlow.Sample.*` in dotnet/maui-labs. It was chosen over the alternatives because:

- a `ProjectReference` to the app would need a plain `net11.0` TFM added to the app (and an `OutputType` dance), and
  would compile the shared XAML against one MAUI version for all heads; linking lets each head compile the XAML with
  its own package set and TFM, which is what made the GTK4 head (no workload) and the macOS head (BundleResource) work;
- the labs templates produce standalone C#-markup apps, i.e. a second copy of the UI.

## 3. Prerequisites per operating system

### Windows (WPF head, and the app's WinUI target)

- .NET SDK pinned in `global.json` (`11.0.100-rc.1.26425.128`, `allowPrerelease: true`), installed machine-wide with
  the official installer for the machine's architecture. A user-local install from `dotnet-install.ps1` builds fine
  but launched `.exe`s show "You must install .NET" unless `DOTNET_ROOT` points at it; use `dotnet run` or install
  machine-wide. On Windows on Arm, Git Bash reports `x86_64`; ask PowerShell for the real architecture.
- Workloads: `dotnet workload install maui-windows` is enough for the WPF head and the app's Windows target; `maui`
  for everything. Workloads are per SDK install (user-local SDKs need their own).
- `dotnet tool update -g Microsoft.Maui.Cli --prerelease` (gives `maui doctor`, `maui devflow …`).
- Visual Studio 2026 release channel is not documented as supporting .NET 11 RC1 (Insiders is); use the CLI / VS Code.
- `eng/setup-windows.ps1` in this repo does all of it from an elevated prompt.

### Linux / WSL2 (GTK4 head)

- GTK **4.12+**: Ubuntu 24.04 (GTK 4.14) or newer; Ubuntu 22.04 (4.6) and 20.04 (none) are too old. In WSL:
  `wsl --install -d Ubuntu-24.04`.
- Packages: `libgtk-4-dev libwebkitgtk-6.0-dev gobject-introspection libgirepository1.0-dev gir1.2-gtk-4.0 gir1.2-webkit-6.0 pkg-config`
  (WebKitGTK only matters for Blazor). No MAUI workload is needed for the GTK4 head.
- SDK into `~/.dotnet` with `dotnet-install.sh --version <global.json version>`; `eng/setup-linux.sh` does it and adds
  `DOTNET_ROOT`/`PATH` to `~/.bashrc` (non-interactive shells do not read `.bashrc`: export them in scripts).
- Build from a Linux-filesystem clone, not `/mnt/c/...`, or `bin/`/`obj/` collide with the Windows builds.
- Driving WSL from Git Bash mangles `/mnt/c` arguments and `wsl -- …` re-parses the command through the login shell;
  use PowerShell with `wsl -d <distro> -u <user> -e bash <script>`.
- Under WSLg without a usable GPU the app prints `libEGL … MESA: error: ZINK` warnings and falls back to software
  rendering: harmless, `GSK_RENDERER=cairo` silences it.

### macOS (AppKit head)

- Apple Silicon (the backend is osx-arm64 only), macOS 14+, Xcode command line tools.
- The .NET 11 RC1 macOS workload (`Microsoft.macOS.Sdk.net11.0_26.5` 26.5.12194) **requires Xcode 26.6**; with
  Xcode 26.5 build with `-p:ValidateXcodeVersion=false` (F13). GitHub's `macos-26` runner has 26.6.
- Workloads: `dotnet workload install macos maui-tizen`. `macos` gives the TFM; a `UseMaui` project on it also needs
  the MAUI SDK packs, which the SDK resolves to the smallest workload carrying them, `maui-tizen`
  (`NETSDK1147: … workloads must be installed: maui-tizen` otherwise). `maui` works too but is several times larger.
- macOS's `/bin/bash` is 3.2: in scripts, `"${arr[@]}"` on an empty array under `set -u` aborts; use plain strings.
- `eng/setup-macos.sh` does the SDK, workloads and `maui` CLI (no sudo).

## 4. Prepare the existing app (do this before adding heads)

1. **Note the `RootNamespace`** of the app; every head must use the same value or the linked XAML code-behind will not
   match its `x:Class`.
2. **Factor `MauiProgram`** so a head can reuse everything except the hosting call. The default template needs
   nothing, but a real app should move fonts, handlers, DI and services into an extension method in a shared file, e.g.
   `MauiProgramExtensions.ConfigureShared(this MauiAppBuilder builder)`, and keep `MauiProgram.cs` as the WinUI/mobile
   entry only. Heads then do `builder.UseMauiAppWPF<App>().UseWPFEssentials().ConfigureShared()`.
3. **Audit `#if` conditionals in shared files.** The heads compile with these symbols (verified from the csc command lines):

   | Head | Symbols | Consequence |
   | --- | --- | --- |
   | WPF (`net11.0-windows`) | `WINDOWS`, `WINDOWS7_0` | Inline `#if WINDOWS` code written for WinUI (`Microsoft.UI.Xaml`, `WinRT`) **is compiled into the WPF head** and will not build. Define `WPF` in the head (`<DefineConstants>$(DefineConstants);WPF</DefineConstants>`) and guard WinUI code with `#if WINDOWS && !WPF`, or keep it under `Platforms/Windows/`, which the heads exclude. |
   | GTK4 (`net11.0`) | `LINUX`, `LINUX_GTK` (from the labs props) | Nothing platform-specific from the app is compiled; `#if ANDROID`/`IOS`/… code is simply absent. |
   | AppKit (`net11.0-macos`) | `MACOS`, `MACOS26_5`, `__MACOS__`, `__UNIFIED__` | `#if MACCATALYST` / `IOS` UIKit code is **not** compiled (good); anything you want AppKit-only goes under `#if MACOS`. |

   Anything in the app's `Platforms/<Name>/` folders is excluded from all heads by the wildcard `Exclude`, so
   partial-class platform files (`Foo.windows.cs` inside `Platforms/Windows`) are safe; `Foo.cs` with inline `#if` is not.
4. **Check Essentials usage.** Each backend ships partial Essentials implementations (GTK4 README: 21 of 36 services,
   13 stubs; WPF README: 14 APIs; macOS: AppInfo, Battery, Clipboard, Geolocation, Preferences, SecureStorage,
   Sensors…). Static calls such as `SemanticScreenReader.Announce`, `Preferences.Default`, `Clipboard.Default` only
   work if the head **registers the backend's Essentials** (section 6–8); without that the portable stub throws
   `NotImplementedInReferenceAssemblyException` (F15). Phone/sensor APIs are stubs everywhere.
5. **Resources**: keep them in the app's `Resources/Images|Fonts|Raw|AppIcon|Splash` folders; the heads link them.
   Fonts are referenced by file name in `ConfigureFonts` exactly as today.
6. **Shell**: works on all three, but GTK4 draws no navigation bar/flyout button for a single-item Shell and
   left-aligns multi-line labels inside a centred block; macOS puts the flyout button and title in the window toolbar.
   Don't rely on the WinUI look.
7. **Fonts on GTK4** currently ignore `FontSize`/`FontFamily`/`TextColor` set on labels and buttons (backend bug,
   F16): expect theme-default text until it is fixed upstream.

## 5. Central versions

`Directory.Build.props` at the repo root:

```xml
<Project>
  <PropertyGroup>
    <MauiLabsVersion>0.1.0-preview.12.26421.1</MauiLabsVersion>   <!-- backends, Essentials and DevFlow agents: one version -->
    <MauiControlsVersion>11.0.0-rc.1.26451.6</MauiControlsVersion> <!-- only for heads without a MAUI workload (GTK4) -->
  </PropertyGroup>
</Project>
```

Two override knobs (defaulting to `MauiLabsVersion`) let you try a labs PR's CI-built packages without touching
project files: `MauiLabsDevFlowVersion` (all DevFlow agent packages) and `MauiLabsGtk4Version` (the GTK4 backend), e.g.
`dotnet build … -p:MauiLabsDevFlowVersion=0.1.0-ci.1240.1 -p:MauiLabsGtk4Version=0.1.0-ci.1240.1 -p:RestoreAdditionalProjectSources=/path/to/nupkgs`.

Heads with `UseMaui=true` (WPF, macOS) use `$(MauiVersion)` from the workload for `Microsoft.Maui.Controls`; the GTK4
head has no workload and must pin `Microsoft.Maui.Controls` explicitly, otherwise it gets the backend's minimum
(10.0.41). Always reference `Microsoft.Maui.Controls` explicitly in every head: the labs packages only declare
`>= 10.0.41`, and an SDK-bundled 10.0.20 causes `NU1605` downgrade errors (F2).

`global.json` pins the SDK with `"rollForward": "latestFeature", "allowPrerelease": true`.

## 6. WPF head

`MyApp.Wpf/MyApp.Wpf.csproj`:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net11.0-windows</TargetFramework>
    <OutputType>WinExe</OutputType>
    <UseWPF>true</UseWPF>
    <UseMaui>true</UseMaui>
    <RootNamespace>MyApp</RootNamespace>              <!-- same as the app -->
    <AssemblyName>MyApp.Wpf</AssemblyName>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <RuntimeIdentifiers>win-arm64;win-x64</RuntimeIdentifiers>
    <DefineConstants>$(DefineConstants);WPF</DefineConstants> <!-- see section 4 -->

    <ApplicationTitle>MyApp</ApplicationTitle>
    <ApplicationId>com.example.myapp</ApplicationId>

    <EnableDefaultApplicationDefinition>false</EnableDefaultApplicationDefinition> <!-- no App.xaml: Program.cs creates the WPF Application -->
    <EnableDefaultPageItems>false</EnableDefaultPageItems>       <!-- stop the WPF SDK treating MAUI .xaml as WPF pages -->
    <EnableDefaultMauiItems>false</EnableDefaultMauiItems>       <!-- we list MauiXaml items ourselves -->
    <StartupObject>MyApp.Wpf.Program</StartupObject>
    <SkipValidateMauiImplicitPackageReferences>true</SkipValidateMauiImplicitPackageReferences> <!-- MA002 -->
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.Maui.Controls" Version="$(MauiVersion)" />
    <PackageReference Include="Microsoft.Maui.Platforms.Windows.WPF" Version="$(MauiLabsVersion)" />
    <PackageReference Include="Microsoft.Maui.Platforms.Windows.WPF.Essentials" Version="$(MauiLabsVersion)" />
    <PackageReference Include="Microsoft.Maui.DevFlow.Agent.WPF" Version="$(MauiLabsVersion)" />
    <PackageReference Include="Microsoft.Extensions.Logging.Debug" Version="11.0.0-*" />
  </ItemGroup>

  <ItemGroup>
    <Compile Include="..\MyApp\**\*.cs" Exclude="..\MyApp\Platforms\**;..\MyApp\MauiProgram.cs;..\MyApp\obj\**;..\MyApp\bin\**"
             Link="%(RecursiveDir)%(Filename)%(Extension)" />
    <MauiXaml Include="..\MyApp\**\*.xaml" Exclude="..\MyApp\Platforms\**;..\MyApp\obj\**;..\MyApp\bin\**"
              Link="%(RecursiveDir)%(Filename)%(Extension)" />
  </ItemGroup>

  <ItemGroup>  <!-- the WPF package's build targets copy these into the output folder -->
    <MauiIcon Include="..\MyApp\Resources\AppIcon\appicon.svg" ForegroundFile="..\MyApp\Resources\AppIcon\appiconfg.svg" Color="#512BD4" />
    <MauiImage Include="..\MyApp\Resources\Images\*" Link="Resources\Images\%(Filename)%(Extension)" />
    <MauiFont Include="..\MyApp\Resources\Fonts\*" Link="Resources\Fonts\%(Filename)%(Extension)" />
    <MauiAsset Include="..\MyApp\Resources\Raw\**" Link="Resources\Raw\%(RecursiveDir)%(Filename)%(Extension)" LogicalName="%(RecursiveDir)%(Filename)%(Extension)" />
  </ItemGroup>

  <ItemGroup>  <!-- lets `maui devflow` identify the head -->
    <AssemblyMetadata Include="Microsoft.Maui.DevFlowProject" Value="MyApp.Wpf" />
    <AssemblyMetadata Include="Microsoft.Maui.DevFlowTfm" Value="$(TargetFramework)" />
  </ItemGroup>
</Project>
```

`Program.cs` (namespace `MyApp.Wpf` so the host class does not collide with the shared `MyApp.App`):

```csharp
using Microsoft.Maui.Platforms.Windows.WPF;

namespace MyApp.Wpf;

public sealed class WpfApplication : MauiWPFApplication
{
	protected override MauiApp CreateMauiApp() => MauiProgram.CreateMauiApp();
}

public static class Program
{
	[STAThread]
	public static void Main() => new WpfApplication().Run();
}
```

`MauiProgram.cs` (namespace `MyApp`):

```csharp
using Microsoft.Maui.Controls.Hosting.WPF;
using Microsoft.Maui.Platforms.Windows.WPF.Essentials;
#if DEBUG
using Microsoft.Maui.DevFlow.Agent.WPF;
#endif

public static class MauiProgram
{
	public static MauiApp CreateMauiApp()
	{
		var builder = MauiApp.CreateBuilder();
		builder.UseMauiAppWPF<App>().UseWPFEssentials().ConfigureFonts(/* as in the app */);
#if DEBUG
		builder.Logging.AddDebug();
		builder.AddMauiDevFlowAgent();
#endif
		return builder.Build();
	}
}
```

Do **not** copy the labs `maui-wpf` template's `Program.cs` (`using System.Windows;` + `new Application()` is
ambiguous with MAUI's `Application`, CS0104) or its floating `Version="0.1.0-preview"` (resolves to the oldest preview).

Build/run: `dotnet build MyApp.Wpf -r win-arm64` (or `-r win-x64`, cross-builds fine on either host), `dotnet run --project MyApp.Wpf`.
The app follows the Windows dark/light theme.

## 7. GTK4 head

`MyApp.Gtk4/MyApp.Gtk4.csproj` — a plain console project, no `UseMaui`, no workload:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net11.0</TargetFramework>
    <OutputType>Exe</OutputType>
    <RootNamespace>MyApp</RootNamespace>
    <AssemblyName>MyApp.Gtk4</AssemblyName>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <RuntimeIdentifiers>linux-arm64;linux-x64</RuntimeIdentifiers>
    <ApplicationTitle>MyApp</ApplicationTitle>
    <ApplicationId>com.example.myapp</ApplicationId>

    <!-- DevFlow is opt-in: Microsoft.Maui.DevFlow.Agent.Gtk (preview.12) depends on the superseded
         Platform.Maui.Linux.Gtk4 0.6.0, ships a second backend, and never starts against this one (maui-labs#521). -->
    <MauiGtk4DevFlow Condition="'$(MauiGtk4DevFlow)' == ''">false</MauiGtk4DevFlow>
    <DefineConstants Condition="'$(MauiGtk4DevFlow)' == 'true'">$(DefineConstants);MAUIDEVFLOW</DefineConstants>
    <!-- DevFlow's targets add the XAML files as untyped AdditionalFiles on plain TFMs and MAUI's XAML source
         generator then emits nothing (CS0103 InitializeComponent), maui-labs#520. -->
    <DevFlowXamlSourceMapsEnabled>false</DevFlowXamlSourceMapsEnabled>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.Maui.Controls" Version="$(MauiControlsVersion)" />   <!-- explicit: no workload here -->
    <PackageReference Include="Microsoft.Maui.Platforms.Linux.Gtk4" Version="$(MauiLabsVersion)" />
    <PackageReference Include="Microsoft.Maui.Platforms.Linux.Gtk4.Essentials" Version="$(MauiLabsVersion)" />
    <PackageReference Include="Microsoft.Maui.DevFlow.Agent.Gtk" Version="$(MauiLabsVersion)" Condition="'$(MauiGtk4DevFlow)' == 'true'" />
    <PackageReference Include="Microsoft.Extensions.Logging.Debug" Version="11.0.0-*" />
  </ItemGroup>

  <ItemGroup>  <!-- identical linking block to the WPF head -->
    <Compile Include="..\MyApp\**\*.cs" Exclude="..\MyApp\Platforms\**;..\MyApp\MauiProgram.cs;..\MyApp\obj\**;..\MyApp\bin\**" Link="%(RecursiveDir)%(Filename)%(Extension)" />
    <MauiXaml Include="..\MyApp\**\*.xaml" Exclude="..\MyApp\Platforms\**;..\MyApp\obj\**;..\MyApp\bin\**" Link="%(RecursiveDir)%(Filename)%(Extension)" />
  </ItemGroup>

  <ItemGroup>  <!-- the GTK4 package's targets copy these to the output folder (icon into hicolor/) -->
    <MauiIcon Include="..\MyApp\Resources\AppIcon\appicon.svg" ForegroundFile="..\MyApp\Resources\AppIcon\appiconfg.svg" Color="#512BD4" />
    <MauiImage Include="..\MyApp\Resources\Images\*" Link="Resources\Images\%(Filename)%(Extension)" />
    <MauiFont Include="..\MyApp\Resources\Fonts\*" Link="Resources\Fonts\%(Filename)%(Extension)" />
    <MauiAsset Include="..\MyApp\Resources\Raw\**" Link="Resources\Raw\%(RecursiveDir)%(Filename)%(Extension)" LogicalName="%(RecursiveDir)%(Filename)%(Extension)" />
  </ItemGroup>
</Project>
```

The XAML pipeline and MAUI's implicit usings come from the `Microsoft.Maui.Controls.Build.Tasks` package (a
dependency of `Microsoft.Maui.Controls`), which is why no workload is needed. Add `AssemblyInfo.cs` with
`[assembly: SupportedOSPlatform("linux")]` to keep CA1416 quiet when you compile the head on Windows/macOS as a check
(it compiles anywhere; it only runs on Linux).

`Program.cs`:

```csharp
using Microsoft.Maui.Hosting;
using Microsoft.Maui.Platforms.Linux.Gtk4.Platform;

namespace MyApp;

public class Program : GtkMauiApplication
{
	protected override MauiApp CreateMauiApp() => MauiProgram.CreateMauiApp();
	public static void Main(string[] args) => new Program().Run(args);
}
```

`MauiProgram.cs`:

```csharp
using Microsoft.Maui.Controls.Hosting;
using Microsoft.Maui.Hosting;
using Microsoft.Maui.Platforms.Linux.Gtk4.Essentials.Hosting;
using Microsoft.Maui.Platforms.Linux.Gtk4.Hosting;
#if DEBUG && MAUIDEVFLOW
using Microsoft.Maui.DevFlow.Agent.Gtk;
#endif

public static class MauiProgram
{
	public static MauiApp CreateMauiApp()
	{
		var builder = MauiApp.CreateBuilder();
		builder
			.UseMauiAppLinuxGtk4<App>()
			.AddLinuxGtk4Essentials()      // REQUIRED: without it the first Essentials call throws (F15)
			.ConfigureFonts(/* as in the app */);
#if DEBUG
		builder.Logging.AddDebug();
#endif
#if DEBUG && MAUIDEVFLOW
		builder.AddMauiDevFlowAgent();
#endif
		return builder.Build();
	}
}
```

Build/run on Linux: `dotnet run --project MyApp.Gtk4 -r linux-arm64` (or `linux-x64`). The GTK4 package also ships
AppImage/Deb/Flatpak packaging targets (`dotnet publish -r linux-x64 -p:CreateAppImage=true` etc.), not yet tried here.
The app uses GTK's default light theme.

## 8. macOS AppKit head

`MyApp.MacOS/MyApp.MacOS.csproj`:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net11.0-macos</TargetFramework>
    <OutputType>Exe</OutputType>
    <RootNamespace>MyApp</RootNamespace>
    <AssemblyName>MyApp.MacOS</AssemblyName>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <UseMaui>true</UseMaui>
    <SingleProject>true</SingleProject>
    <SupportedOSPlatformVersion>14.0</SupportedOSPlatformVersion>
    <RuntimeIdentifier>osx-arm64</RuntimeIdentifier>
    <DevFlowXamlSourceMapsEnabled>false</DevFlowXamlSourceMapsEnabled>  <!-- `macos` is missing from DevFlow's TFM list too (#520); Debug builds lose InitializeComponent otherwise -->

    <ApplicationTitle>MyApp</ApplicationTitle>
    <ApplicationId>com.example.myapp</ApplicationId>
    <ApplicationDisplayVersion>1.0</ApplicationDisplayVersion>
    <ApplicationVersion>1</ApplicationVersion>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.Maui.Controls" Version="$(MauiVersion)" />
    <PackageReference Include="Microsoft.Maui.Platforms.MacOS" Version="$(MauiLabsVersion)" />
    <PackageReference Include="Microsoft.Maui.Platforms.MacOS.Essentials" Version="$(MauiLabsVersion)" />
    <PackageReference Include="Microsoft.Maui.DevFlow.Agent" Version="$(MauiLabsVersion)" />   <!-- the standard agent works on AppKit -->
    <PackageReference Include="Microsoft.Extensions.Logging.Debug" Version="11.0.0-*" />
  </ItemGroup>

  <ItemGroup>  <!-- identical linking block -->
    <Compile Include="..\MyApp\**\*.cs" Exclude="..\MyApp\Platforms\**;..\MyApp\MauiProgram.cs;..\MyApp\obj\**;..\MyApp\bin\**" Link="%(RecursiveDir)%(Filename)%(Extension)" />
    <MauiXaml Include="..\MyApp\**\*.xaml" Exclude="..\MyApp\Platforms\**;..\MyApp\obj\**;..\MyApp\bin\**" Link="%(RecursiveDir)%(Filename)%(Extension)" />
  </ItemGroup>

  <!-- Only MauiIcon is processed by the labs targets (SVG -> .icns). Resizetizer does not run for the macos TFM, so
       MauiImage/MauiFont/MauiAsset from the shared project never reach the bundle (F14). The backend loads images from
       Contents/Resources/Images and fonts from Contents/Resources/Fonts; BundleResource strips the leading "Resources\". -->
  <ItemGroup>
    <MauiIcon Include="..\MyApp\Resources\AppIcon\appicon.svg" ForegroundFile="..\MyApp\Resources\AppIcon\appiconfg.svg" Color="#512BD4" />
    <BundleResource Include="..\MyApp\Resources\Images\*" Link="Resources\Images\%(Filename)%(Extension)" />
    <BundleResource Include="..\MyApp\Resources\Fonts\*" Link="Resources\Fonts\%(Filename)%(Extension)" />
    <BundleResource Include="..\MyApp\Resources\Raw\**" Link="Resources\Raw\%(RecursiveDir)%(Filename)%(Extension)" />
  </ItemGroup>
</Project>
```

Entry point files (namespace `MyApp`):

```csharp
// Main.cs
using AppKit;
public static class MainClass
{
	static void Main(string[] args)
	{
		NSApplication.Init();
		NSApplication.SharedApplication.Delegate = new MauiMacOSAppDelegate();
		NSApplication.Main(args);
	}
}

// MauiMacOSAppDelegate.cs
using Foundation;
using Microsoft.Maui.Platforms.MacOS.Platform;
[Register("MauiMacOSAppDelegate")]
public class MauiMacOSAppDelegate : MacOSMauiApplication
{
	protected override MauiApp CreateMauiApp() => MauiProgram.CreateMauiApp();
}

// MauiProgram.cs
using Microsoft.Maui.Platforms.MacOS.Hosting;
using Microsoft.Maui.Platforms.MacOS.Essentials;
#if DEBUG
using Microsoft.Maui.DevFlow.Agent;
#endif
public static class MauiProgram
{
	public static MauiApp CreateMauiApp()
	{
		var builder = MauiApp.CreateBuilder();
		builder.UseMauiAppMacOS<App>().AddMacOSEssentials().ConfigureFonts(/* as in the app */);
#if DEBUG
		builder.Logging.AddDebug();
		builder.AddMauiDevFlowAgent();
#endif
		return builder.Build();
	}
}
```

Build/run: `dotnet build MyApp.MacOS` (add `-p:ValidateXcodeVersion=false` on Xcode 26.5), `dotnet run --project MyApp.MacOS`.
The bundle is `bin/Debug/net11.0-macos/osx-arm64/MyApp.app`. Launch it with `open` (LaunchServices) when the user
is not sitting at the machine: a bare `./MyApp.app/Contents/MacOS/MyApp` never becomes active on a CI runner and the
DevFlow agent (which starts on activation) stays silent.

## 9. Solution and IDE

Put all four projects in one `.slnx` for the IDE, but never expect `dotnet build MyApp.slnx` to succeed on one OS:
each head only builds on its own OS. Build per project locally and in CI. The app's own Windows target can be built
with only `maui-windows` installed via `dotnet build MyApp -f net11.0-windows10.0.19041.0 -p:TargetFrameworks=net11.0-windows10.0.19041.0`
(restore otherwise demands the android/ios/maccatalyst workloads).

## 10. DevFlow: what to expect on each backend

Register the agent in every head (`#if DEBUG`), start `maui devflow broker start`, run the app, then `maui devflow list`.

| | WPF | GTK4 | AppKit |
| --- | --- | --- | --- |
| Agent package | `Microsoft.Maui.DevFlow.Agent.WPF` | `Microsoft.Maui.DevFlow.Agent.Gtk` (opt-in) | `Microsoft.Maui.DevFlow.Agent` |
| Registers with broker | ✅ (`platform: "WPF"`) | ❌ never starts (#521) | ✅ (`platform: "macOS"`) |
| `ui tree` | Shell chrome only, page missing (#522) | — | full tree down to the layouts |
| `ui tap --text` | ❌ (`hit-test` finds text via UIA, tap is a no-op) | — | ✅ |
| `ui screenshot` | ✅ | — | ✅ |
| Real input for tests | UI Automation `InvokePattern` or a real click | `xdotool` with `GDK_BACKEND=x11` under WSLg | DevFlow |

`maui devflow mcp` exposes the same to AI agents. `maui devflow init` installs the DevFlow skills into `.claude/skills`.

### Smoke-test pattern (the one that runs in CI for AppKit)

Build Debug → launch (via `open` on macOS) → poll `maui devflow list` for the platform (≤ 60 s) → poll `ui tree` for the
page type (≤ 45 s; the agent registers before Shell has created the page) → `ui tap --text "…"` and check
`"success": true` → `ui query --type Button` and assert the text → `ui screenshot`. See `eng/smoke-macos.sh`; it is
written for bash 3.2 and exits non-zero on the first failed step.

## 11. CI recipe (GitHub Actions)

- Runners: `windows-11-arm` (win-arm64), `windows-latest` (win-x64), `ubuntu-24.04-arm` (linux-arm64), `ubuntu-24.04`
  (linux-x64), `macos-26` (osx-arm64, Xcode 26.6). arm64 runners are free for public repos, billed for private ones.
- `actions/setup-dotnet@v5` with `global-json-file: global.json` installs the RC SDK.
- Workloads: Windows `maui-windows`; Linux none; macOS `macos maui-tizen`.
- GTK4 needs no system packages to *compile*; running it needs the GTK4 libraries and a display (`xvfb-run`, untested).
- Build heads with `-c Release`; smoke-test with a Debug build (the agent is `#if DEBUG`), and install the CLI with
  `dotnet tool install -g Microsoft.Maui.Cli --prerelease`. Upload `SMOKE_OUT` as an artifact with `if: always()`.
- See `.github/workflows/build.yml` for the working matrix.

## 12. Troubleshooting index

| Symptom | Cause | Fix |
| --- | --- | --- |
| `NU1605 … Microsoft.Maui.Controls from 10.0.41 to 10.0.20` | No explicit Controls reference; SDK-bundled MAUI below the labs minimum | Reference `Microsoft.Maui.Controls` explicitly (`$(MauiVersion)` or `$(MauiControlsVersion)`) |
| `NU1102 Unable to find package Microsoft.Maui.Platforms.Linux.Gtk4 with version (>= 0.6.0-0)` | labs `maui-linux-gtk4` template uses the old package's version | Pin `0.1.0-preview.12.26421.1` |
| `CS0104 'Application' is ambiguous` in a WPF Program.cs | labs `maui-wpf` template's `using System.Windows` | Use the `MauiWPFApplication` subclass pattern above |
| `CS0103 The name 'InitializeComponent' does not exist` in a GTK4 or macOS **Debug** build | `Microsoft.Maui.DevFlow.Agent.Core.targets` adds XAML as untyped AdditionalFiles on TFMs outside android/ios/maccatalyst/windows (#520) | `<DevFlowXamlSourceMapsEnabled>false</DevFlowXamlSourceMapsEnabled>` |
| Two GTK backends in the output (`Platform.Maui.Linux.Gtk4.dll` + `Microsoft.Maui.Platforms.Linux.Gtk4.dll`), DevFlow silent | `Microsoft.Maui.DevFlow.Agent.Gtk` ≤ preview.12 depends on the superseded package (#521) | Use a labs release that includes #535 (the agent then starts automatically); until then leave the GTK agent out |
| Trying a labs PR's CI packages: `NU1605` between `0.1.0-ci.*` and released `0.1.0-preview.*` packages | Prerelease ordering: `ci` sorts below `preview`, so released companions (e.g. `…Gtk4.Essentials`) demand a "higher" backend | `-p:NoWarn=NU1605` for the test, plus `-p:RestoreAdditionalProjectSources=<folder of nupkgs>` and the `MauiLabsGtk4Version` / `MauiLabsDevFlowVersion` knobs |
| `NotImplementedInReferenceAssemblyException` from `SemanticScreenReader.Announce` (or any Essentials call) on click | Backend Essentials not registered; the head resolves the portable `lib/net11.0` Essentials | `AddLinuxGtk4Essentials()` / `UseWPFEssentials()` / `AddMacOSEssentials()` |
| macOS: `This version of .NET for macOS … requires Xcode 26.6` | Workload/Xcode mismatch | Install Xcode 26.6 or `-p:ValidateXcodeVersion=false` |
| macOS: `NETSDK1147 … workloads must be installed: maui-tizen` | `UseMaui` on `net11.0-macos` needs the MAUI SDK packs | `dotnet workload install macos maui-tizen` |
| macOS: images/fonts missing, system font used | `MauiImage`/`MauiFont` not bundled for the macos TFM (F14) | `BundleResource` items with `Link="Resources\Images\…"` / `Resources\Fonts\…` |
| macOS CI: agent registers but `ui tree` is `[]`, no "Agent started" line | App launched from the bare binary never activated | Launch with `open -n --stdout … --stderr … App.app`; nudge with `osascript … activate` |
| macOS script dies instantly under `set -u` | bash 3.2 and an empty array expansion | Plain string variables |
| Windows: launched `.exe` shows "You must install .NET" | SDK/runtime installed user-locally only | `DOTNET_ROOT=%USERPROFILE%\.dotnet`, `dotnet run`, or install machine-wide |
| WSL: script "runs" instantly with exit 0 but does nothing | Git Bash rewrote `/mnt/c/...`; or `wsl -- cmd` re-parsed the command | Use PowerShell + `wsl -e bash <script>` |
| WSL: `libEGL warning … ZINK: failed to choose pdev` | No usable GPU for GTK's GL renderer | Harmless; `GSK_RENDERER=cairo` to silence |
| WSL: GTK4 packages missing / too old | Ubuntu < 24.04 | Install `Ubuntu-24.04` |
| `maui doctor`: "Windows SDK not found" with VS 2026 installed | Doctor's check, not the build | Ignore; WinUI builds get the SDK from NuGet |
| WPF: `ui tap --text` finds nothing, `query --type Label` empty | WPF agent stops at `ShellContainerView` (#522) | Drive WPF with UI Automation or real clicks; screenshots still work |
| GTK4: every Label/Button renders at the theme default size and font although `FontSize`/`FontFamily` are set | `GtkViewHandler.ApplyCss` keeps only the last property's CSS provider (CharacterSpacing's `letter-spacing: 0px` overwrites the font); sizes are also emitted in `pt` instead of `px` (status.md F16) | Upstream fix needed; a head-side `LabelHandler.Mapper.AppendToMapping(nameof(ILabel.CharacterSpacing), MapFont)` restores size/family but loses TextColor |

## 13. When versions move: what to re-check

- **New labs release** (bump `MauiLabsVersion`): re-check #518/#519 (templates), #520 (DevFlow XAML targets: try
  removing `DevFlowXamlSourceMapsEnabled=false`), #521 (GTK agent: once the release contains #535, turn
  `MauiGtk4DevFlow` on by default and add a GTK4 smoke test; the GTK agent still ships no build targets, so keep the
  `Microsoft.Maui.DevFlowProject`/`DevFlowTfm` `AssemblyMetadata` items in the head or `maui devflow list` shows
  `"tfm": "unknown"`), #522 (WPF tree),
  and whether `Microsoft.Maui.Platforms.MacOS.Templates` is published (PR #466 merged 2026-09-02) and `maui ai init`
  shipped (PR #98/#513 merged 2026-09-22). Also whether the GTK4/WPF Essentials still need explicit registration.
- **New .NET/MAUI drop** (bump `global.json` and `MauiControlsVersion`): re-check the macOS workload's Xcode
  requirement (F13), the `maui-tizen` trick (F12), and that the labs packages still unify upwards without runtime
  `MissingMethodException`s (F1).
- **Workload list** for the new band: `dotnet workload search` on each OS; `maui-tizen` may disappear if the MAUI
  workloads are restructured.

## 14. Not yet explored

Blazor Hybrid on the backends (packages exist: `Microsoft.Maui.Platforms.Linux.Gtk4.BlazorWebView`,
`Microsoft.Maui.Platforms.MacOS.BlazorWebView`, WPF via WebView2), Linux packaging (AppImage/Deb/Flatpak targets in
the GTK4 package), running the x64 builds on x64 hardware, Release/trimmed builds, the app's android/ios targets on
these SDKs, and Visual Studio 2026 Insiders as an IDE for the heads.

## 15. Where things live in this repo

| Path | Purpose |
| --- | --- |
| `src/MauiPlatforms/` | The unmodified default app (plus the DevFlow agent) that the heads link |
| `src/MauiPlatforms.Wpf/`, `src/MauiPlatforms.Gtk4/`, `src/MauiPlatforms.MacOS/` | The three heads, exactly as described in sections 6–8 |
| `Directory.Build.props`, `global.json` | Versions |
| `eng/setup-windows.ps1`, `eng/setup-linux.sh`, `eng/setup-macos.sh` | Machine setup |
| `eng/smoke-macos.sh` | DevFlow smoke test (local + CI) |
| `.github/workflows/build.yml` | Build matrix + smoke job |
| `docs/status.md` | Findings F1–F15 with evidence, issue links, environment changes |
| `.claude/settings.json`, `.claude/skills/` | maui-labs plugin marketplace registration and the DevFlow skills |
