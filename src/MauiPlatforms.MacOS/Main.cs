using AppKit;

namespace MauiPlatforms;

/// <summary>
/// AppKit entry point: boot NSApplication and hand control to the MAUI-hosting app delegate.
/// </summary>
public static class MainClass
{
	static void Main(string[] args)
	{
		NSApplication.Init();
		NSApplication.SharedApplication.Delegate = new MauiMacOSAppDelegate();
		NSApplication.Main(args);
	}
}
