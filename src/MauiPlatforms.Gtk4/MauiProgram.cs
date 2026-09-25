using Microsoft.Extensions.Logging;
using Microsoft.Maui.Controls.Hosting;
using Microsoft.Maui.Hosting;
using Microsoft.Maui.Platforms.Linux.Gtk4.Hosting;
#if DEBUG && MAUIDEVFLOW
using Microsoft.Maui.DevFlow.Agent.Gtk;
#endif

namespace MauiPlatforms;

/// <summary>
/// GTK4 flavour of the shared app's MauiProgram. Identical to src/MauiPlatforms/MauiProgram.cs except for
/// the hosting call (<c>UseMauiAppLinuxGtk4</c> instead of <c>UseMauiApp</c>) and the GTK DevFlow agent.
/// </summary>
public static class MauiProgram
{
	public static MauiApp CreateMauiApp()
	{
		var builder = MauiApp.CreateBuilder();
		builder
			.UseMauiAppLinuxGtk4<App>()
			.ConfigureFonts(fonts =>
			{
				fonts.AddFont("OpenSans-Regular.ttf", "OpenSansRegular");
				fonts.AddFont("OpenSans-Semibold.ttf", "OpenSansSemibold");
			});

#if DEBUG
		builder.Logging.AddDebug();
#endif
#if DEBUG && MAUIDEVFLOW
		// Opt in with: dotnet build -p:MauiGtk4DevFlow=true (see csproj for why this is off by default)
		builder.AddMauiDevFlowAgent();
#endif

		return builder.Build();
	}
}
