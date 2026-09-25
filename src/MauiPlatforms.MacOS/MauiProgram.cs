using Microsoft.Extensions.Logging;
using Microsoft.Maui.Platforms.MacOS.Hosting;
using Microsoft.Maui.Platforms.MacOS.Essentials;
#if DEBUG
using Microsoft.Maui.DevFlow.Agent;
#endif

namespace MauiPlatforms;

/// <summary>
/// macOS AppKit flavour of the shared app's MauiProgram. Identical to src/MauiPlatforms/MauiProgram.cs except for
/// the hosting call (<c>UseMauiAppMacOS</c> + <c>AddMacOSEssentials</c>) and the DevFlow agent.
/// </summary>
public static class MauiProgram
{
	public static MauiApp CreateMauiApp()
	{
		var builder = MauiApp.CreateBuilder();
		builder
			.UseMauiAppMacOS<App>()
			.AddMacOSEssentials()
			.ConfigureFonts(fonts =>
			{
				fonts.AddFont("OpenSans-Regular.ttf", "OpenSansRegular");
				fonts.AddFont("OpenSans-Semibold.ttf", "OpenSansSemibold");
			});

#if DEBUG
		builder.Logging.AddDebug();
		builder.AddMauiDevFlowAgent();
#endif

		return builder.Build();
	}
}
