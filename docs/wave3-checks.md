# Backend checks run on this branch (2026-09-30)

Branch `checks/wave3` only. `main` keeps `src/MauiPlatforms` as the untouched template app; this branch adds a small
repro harness in `src/MauiPlatforms/Wave3/` plus one button on `MainPage`.

**Environment:** Surface Pro 9 (Windows 11 ARM64), .NET SDK 11.0.100-rc.1.26425.128, MAUI 11.0.0-rc.1.26451.6,
labs backends 0.1.0-preview.12.26421.1 (released). GTK4: WSL2 Ubuntu 24.04 arm64, GTK 4.14.5,
`GSK_RENDERER=cairo GDK_BACKEND=x11`. WPF driven with UI Automation (`SelectionItemPattern`, `InvokePattern`),
screenshots through DevFlow.

## How to run

| Environment variable | Effect |
| --- | --- |
| `WAVE3` unset | template page plus a "Run D23 picker check" button |
| `WAVE3=d4` | `CollectionView` page (`Wave3/D4Page.xaml`); `WAVE3_D4` = comma list of `tall`, `after`, `select`, `card`, `obs`, `twice` |
| `WAVE3=d7` | Shell with a `TabBar` of two `ShellContent`s; `WAVE3=d7t` also sets `Shell.ItemTemplate` |
| `WAVE3_AUTO=1` | runs the page's action two seconds after `Loaded` (works on GTK4; `Loaded` did not fire on WPF) |

Results are appended to `wave3.log` in the temp folder and written to the console.

## Results

| Check | Result | Evidence |
| --- | --- | --- |
| Picker reports a selection it made itself (GTK4) | **Confirmed** | GTK4 raises `0, 8, -1, 0, 8`; WPF raises `8, -1, 8` for the same code. Two spurious `0`s, one per item refill. |
| Choosing a `TabBar` tab does nothing (WPF) | **Confirmed, both parts** | Without `Shell.ItemTemplate` the tab strip shows; selecting "Two" leaves page one on screen, `Shell.Current.CurrentState.Location` stays `//one`, and `Shell.Navigated` never fires. With `Shell.ItemTemplate` set there is no tab control in the tree at all. |
| Font lookup depends on the working directory (WPF) | **No, but the font never resolves at all** | Screenshots from the output folder, from `C:\`, from `Resources\Fonts`, and with the `.ttf` files renamed away are byte-identical (same SHA-1). The `Headline` style's registered Open Sans is never used; the heading renders in the default UI font in every run. |
| `CollectionView` shows only its first items (WPF) | **Not reproduced here** | Eight variants (as drafted, tall items, `ItemsSource` after showing, single selection, card-like wrapping template, re-assigned source; preview.12 and the #533 CI backend 0.1.0-ci.509.1) all realize every item that fits and scroll to the last one. |
| Window cannot be narrowed below 800 (GTK4) | **Confirmed on the default app** | `xdotool windowsize` 500×700 gives 800×700; 300×400 gives 800×600; 1100×700 is honoured. The floor is 800×600. |

Side findings:

- Binding an empty `ObservableCollection` and adding items afterwards leaves the WPF `CollectionView` on a "No items"
  empty view (`WAVE3_D4=card,obs`).
- `Page.Loaded` was not raised on the WPF head, so `WAVE3_AUTO` has no effect there.
- GTK4 logs `Theme parser error: No property named "text-align"` at start-up.
