using Microsoft.Extensions.Logging;
using Microsoft.Maui.Controls.Hosting.WPF;
using Microsoft.Maui.Platforms.Windows.WPF.Essentials;
#if DEBUG
using Microsoft.Maui.DevFlow.Agent.WPF;
#endif

namespace MauiPlatforms;

/// <summary>
/// WPF flavour of the shared app's MauiProgram. Identical to src/MauiPlatforms/MauiProgram.cs except for
/// the hosting call (<c>UseMauiAppWPF</c> + <c>UseWPFEssentials</c>) and the WPF DevFlow agent.
/// </summary>
public static class MauiProgram
{
	public static MauiApp CreateMauiApp()
	{
		var builder = MauiApp.CreateBuilder();
		builder
			.UseMauiAppWPF<App>()
			.UseWPFEssentials()
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
