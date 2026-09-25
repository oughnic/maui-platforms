using Microsoft.Maui.Hosting;
using Microsoft.Maui.Platforms.Linux.Gtk4.Platform;

namespace MauiPlatforms;

/// <summary>
/// GTK4 entry point. <see cref="GtkMauiApplication"/> owns the Gtk.Application and hosts the MAUI app.
/// </summary>
public class Program : GtkMauiApplication
{
	protected override MauiApp CreateMauiApp() => MauiProgram.CreateMauiApp();

	public static void Main(string[] args)
	{
		var app = new Program();
		app.Run(args);
	}
}
