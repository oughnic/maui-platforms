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
		// WAVE3_D4 is a comma list of variants:
		//   tall   multi-line items (explicit line breaks)
		//   after  set ItemsSource after showing the host Grid instead of before
		//   select SelectionMode = Single
		//   obs    bind an empty ObservableCollection first, then add the items one by one
		//   twice  after one second hide the host, clear ItemsSource, then assign a populated ObservableCollection and show again
		//   card   card-like template: a narrow bold label that word-wraps long names, plus a button, so heights vary
		var variant = Environment.GetEnvironmentVariable("WAVE3_D4") ?? "";
		string[] items = variant.Contains("tall")
			? ["One\nsecond line", "Two\nsecond line\nthird line", "Three\nsecond line", "Four\nsecond line\nthird line", "Five\nsecond line"]
			: variant.Contains("card")
			? ["Penardun ferch Bran of Siluria or Julia (Victoria) verch PRASUTAGUS of the ICENI", "Victoria Mary Louisa", "Victoria Hanover Queen of England", "Boadicea (Queen) of ICENIANS", "Decurion of Colchester Coel Godhebog Old King Cole King of the Britons"]
			: ["One", "Two", "Three", "Four", "Five"];
		if (variant.Contains("select"))
			List.SelectionMode = SelectionMode.Single;
		if (variant.Contains("card"))
			List.ItemTemplate = new DataTemplate(() =>
			{
				var name = new Label { FontAttributes = FontAttributes.Bold, FontSize = 16, WidthRequest = 200, HorizontalOptions = LayoutOptions.Start, LineBreakMode = LineBreakMode.WordWrap };
				name.SetBinding(Label.TextProperty, ".");
				return new Border
				{
					Padding = 24,
					Margin = new Thickness(0, 4),
					Content = new VerticalStackLayout { Spacing = 4, Children = { name, new Label { Text = "1786-1861" }, new Button { Text = "0 +", HorizontalOptions = LayoutOptions.Start } } },
				};
			});
		if (variant.Contains("obs"))
		{
			var source = new System.Collections.ObjectModel.ObservableCollection<string>();
			List.ItemsSource = source;
			Host.IsVisible = true;
			foreach (var item in items) source.Add(item);
		}
		else if (variant.Contains("after"))
		{
			Host.IsVisible = true;
			List.ItemsSource = items;
		}
		else
		{
			List.ItemsSource = items;
			Host.IsVisible = true;
		}
		if (variant.Contains("twice"))
			Dispatcher.DispatchDelayed(TimeSpan.FromSeconds(1), () =>
			{
				Host.IsVisible = false;
				List.ItemsSource = null;
				List.ItemsSource = new System.Collections.ObjectModel.ObservableCollection<string>(items);
				Host.IsVisible = true;
			});
		Status.Text = $"shown ({(variant.Length == 0 ? "as drafted" : variant)})";
		Wave3.Log($"D4 shown, variant '{variant}', page {Width:0}x{Height:0}");
		Dispatcher.DispatchDelayed(TimeSpan.FromSeconds(1), () => Wave3.Log($"D4 list bounds {List.Width:0}x{List.Height:0}"));
	}
}
