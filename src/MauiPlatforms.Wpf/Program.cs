using Microsoft.Maui.Platforms.Windows.WPF;

namespace MauiPlatforms.Wpf;

/// <summary>
/// The WPF <c>System.Windows.Application</c> that hosts the MAUI app, provided by the labs WPF backend.
/// Named WpfApplication rather than App to avoid clashing with the shared <see cref="MauiPlatforms.App"/>.
/// </summary>
public sealed class WpfApplication : MauiWPFApplication
{
	protected override MauiApp CreateMauiApp() => MauiProgram.CreateMauiApp();
}

public static class Program
{
	[STAThread]
	public static void Main()
	{
		var app = new WpfApplication();
		app.Run();
	}
}
