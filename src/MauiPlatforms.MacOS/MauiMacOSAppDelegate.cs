using Foundation;
using Microsoft.Maui.Platforms.MacOS.Platform;

namespace MauiPlatforms;

/// <summary>
/// NSApplicationDelegate provided by the labs AppKit backend; it creates and hosts the MAUI app.
/// </summary>
[Register("MauiMacOSAppDelegate")]
public class MauiMacOSAppDelegate : MacOSMauiApplication
{
	protected override MauiApp CreateMauiApp() => MauiProgram.CreateMauiApp();
}
