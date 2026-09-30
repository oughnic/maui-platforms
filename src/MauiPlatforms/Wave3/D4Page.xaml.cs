namespace MauiPlatforms.Wave3;

public partial class D4Page : ContentPage
{
	public D4Page()
	{
		InitializeComponent();
		Wave3.WhenLoaded(this, Show);
	}

	void OnShow(object? sender, EventArgs e) => Show();

	void Show()
	{
		// WAVE3_D4=tall uses multi-line items (roughly 70-105 DIP each); WAVE3_D4=after sets ItemsSource after showing.
		var variant = Environment.GetEnvironmentVariable("WAVE3_D4") ?? "";
		string[] items = variant.Contains("tall")
			? ["One\nsecond line", "Two\nsecond line\nthird line", "Three\nsecond line", "Four\nsecond line\nthird line", "Five\nsecond line"]
			: ["One", "Two", "Three", "Four", "Five"];
		if (variant.Contains("after"))
		{
			Host.IsVisible = true;
			List.ItemsSource = items;
		}
		else
		{
			List.ItemsSource = items;
			Host.IsVisible = true;
		}
		Status.Text = $"shown ({(variant.Length == 0 ? "as drafted" : variant)})";
		Wave3.Log($"D4 shown, variant '{variant}', page {Width:0}x{Height:0}");
		Dispatcher.DispatchDelayed(TimeSpan.FromSeconds(1), () => Wave3.Log($"D4 list bounds {List.Width:0}x{List.Height:0}"));
	}
}
