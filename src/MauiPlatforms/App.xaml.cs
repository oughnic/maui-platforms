using Microsoft.Extensions.DependencyInjection;

namespace MauiPlatforms;

public partial class App : Application
{
	public App()
	{
		InitializeComponent();
	}

	protected override Window CreateWindow(IActivationState? activationState)
	{
		return new Window(Wave3.Wave3.CreateShell() ?? new AppShell());
	}
}