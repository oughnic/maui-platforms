namespace MauiPlatforms;

public partial class MainPage : ContentPage
{
	int count = 0;

	public MainPage()
	{
		InitializeComponent();
		Wave3.Wave3.WhenLoaded(this, () => Wave3.Wave3.RunD23(D23Host, D23Out));
	}

	private void OnD23Clicked(object? sender, EventArgs e) => Wave3.Wave3.RunD23(D23Host, D23Out);

	private void OnCounterClicked(object? sender, EventArgs e)
	{
		count++;

		if (count == 1)
			CounterBtn.Text = $"Clicked {count} time";
		else
			CounterBtn.Text = $"Clicked {count} times";

		SemanticScreenReader.Announce(CounterBtn.Text);
	}
}
