using System.Runtime.Versioning;

// The GTK4 head only runs on Linux. Declaring that here keeps the platform-compatibility analyzer (CA1416)
// quiet when the project is compiled on Windows/macOS as a sanity check.
[assembly: SupportedOSPlatform("linux")]
