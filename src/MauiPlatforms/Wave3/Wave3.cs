using System.Globalization;

namespace MauiPlatforms.Wave3;

/// <summary>
/// Repro harness for backend checks (branch checks/wave3 only; main keeps the untouched template app).
/// WAVE3 selects the shell: (unset) = template page + D23 button, "d4" = CollectionView page,
/// "d7" = TabBar with two ShellContents, "d7t" = the same with Shell.ItemTemplate set.
/// WAVE3_AUTO=1 runs the page's action by itself two seconds after it loads.
/// Every result is appended to %TEMP%/wave3.log (or $TMPDIR) and written to the console.
/// </summary>
public static class Wave3
{
	public static string Mode => Environment.GetEnvironmentVariable("WAVE3")?.ToLowerInvariant() ?? "";
	public static bool Auto => Environment.GetEnvironmentVariable("WAVE3_AUTO") == "1";
	public static string LogPath => System.IO.Path.Combine(System.IO.Path.GetTempPath(), "wave3.log");

	public static void Log(string line)
	{
		Console.WriteLine(line);
		try { System.IO.File.AppendAllText(LogPath, line + Environment.NewLine); } catch { }
	}

	public static void WhenLoaded(Page page, Action action)
	{
		if (!Auto) return;
		page.Loaded += (_, _) => page.Dispatcher.DispatchDelayed(TimeSpan.FromSeconds(2), action);
	}

	public static Shell? CreateShell()
	{
		switch (Mode)
		{
			case "d4":
				return new Shell { Items = { new ShellContent { Title = "D4", Route = "d4", ContentTemplate = new DataTemplate(typeof(D4Page)) } } };
			case "d7":
			case "d7t":
				var shell = new Shell
				{
					Items =
					{
						new TabBar
						{
							Items =
							{
								new ShellContent { Title = "One", Route = "one", ContentTemplate = new DataTemplate(typeof(PageOne)) },
								new ShellContent { Title = "Two", Route = "two", ContentTemplate = new DataTemplate(typeof(PageTwo)) },
							},
						},
					},
				};
				if (Mode == "d7t")
					shell.ItemTemplate = new DataTemplate(() => new Label { Text = "templated item", Padding = 8 });
				shell.Navigated += (_, e) => Log($"D7 Navigated: {e.Previous?.Location} -> {e.Current.Location} ({e.Source})");
				return shell;
			default:
				return null;
		}
	}

	/// <summary>D23: fill, select 8, clear and refill, select 8 again; report every SelectedIndexChanged.</summary>
	public static void RunD23(Layout host, Label output)
	{
		var seen = new List<int>();
		var picker = new Picker();
		picker.SelectedIndexChanged += (_, _) => { seen.Add(picker.SelectedIndex); Log($"D23 SelectedIndex = {picker.SelectedIndex}"); };
		host.Add(picker); // in the tree first, so the platform handler exists while the items change
		host.Dispatcher.DispatchDelayed(TimeSpan.FromMilliseconds(500), () =>
		{
			foreach (var month in CultureInfo.InvariantCulture.DateTimeFormat.MonthNames[..12]) picker.Items.Add(month);
			picker.SelectedIndex = 8;
			picker.Items.Clear();
			foreach (var month in CultureInfo.InvariantCulture.DateTimeFormat.MonthNames[..12]) picker.Items.Add(month);
			picker.SelectedIndex = 8;
			host.Dispatcher.DispatchDelayed(TimeSpan.FromMilliseconds(500), () =>
			{
				var text = $"D23 sequence: {string.Join(", ", seen)}; final SelectedIndex = {picker.SelectedIndex}, SelectedItem = {picker.SelectedItem}";
				output.Text = text;
				Log(text);
			});
		});
	}
}

public class PageOne : ContentPage
{
	public PageOne()
	{
		Title = "One";
		var label = new Label { Text = "location: (not read yet)", AutomationId = "LocationLabel" };
		var button = new Button { Text = "Show location", AutomationId = "LocationButton" };
		void Show()
		{
			label.Text = $"location: {Shell.Current.CurrentState.Location}";
			Wave3.Log($"D7 button: {label.Text}; CurrentItem.CurrentItem.Route = {Shell.Current.CurrentItem?.CurrentItem?.Route}");
		}
		button.Clicked += (_, _) => Show();
		Content = new VerticalStackLayout { Padding = 30, Spacing = 20, Children = { new Label { Text = "PAGE ONE", FontSize = 32 }, button, label } };
	}
}

public class PageTwo : ContentPage
{
	public PageTwo()
	{
		Title = "Two";
		Content = new VerticalStackLayout { Padding = 30, Children = { new Label { Text = "PAGE TWO", FontSize = 32 } } };
		Loaded += (_, _) => Wave3.Log("D7 PageTwo loaded");
	}
}
