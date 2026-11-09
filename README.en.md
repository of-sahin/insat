# Insat v1.0.0

[Türkçe](README.md) | **English**

A small Windows app that lowers your computer's volume around prayer times and
restores it afterward. Prayer-time monitoring works offline.
**No Python, Node.js, or additional package downloads are required.**
Insat uses Windows PowerShell 5.1, .NET Framework, and Windows Forms included
with Windows 10/11. The interface is currently in Turkish; instructions below
include the corresponding button labels.

## Getting started

1. Extract the ZIP into a folder. Do not run the app from inside the ZIP.
2. Double-click **`Kur.cmd`**, then click **Kur** (Install).
   The option to create an Insat desktop shortcut is enabled by default.
3. Open **Insat** using the desktop shortcut.
4. Select your province and prayer-time region. Click **Takibi durdur**
   (Stop monitoring) before changing the location, then **Takibi başlat**
   (Start monitoring). On its first launch, the app starts monitoring İstanbul / İstanbul.

Installation is per user and does not require administrator access. Files are
copied to `%LOCALAPPDATA%\Programs\Insat`, with desktop and Start menu shortcuts.
After installation, you can delete the extracted package folder.
To uninstall, choose **Start → Insat → Insat kaldır**. Personal settings are
preserved. To update or repair the app, run `Kur.cmd` from the new package.

For portable use without installation, open **`Baslat.cmd`** and keep its folder
in a permanent location. The PowerShell entry point is **`insat.ps1`**.
You do not need to keep a console window open.

Monitoring uses local data. Only **Vakitleri güncelle** (Update prayer times)
downloads prayer-time data. If Windows blocks a downloaded ZIP, use **Unblock**
in the ZIP's Properties, then extract it again. Organizational application
execution policies may also apply.

## Selecting a location using Windows

Stop monitoring and cancel any manual test, then click **Konumumu kullan**
(Use my location) next to the location fields. Insat requests a location from
Windows and waits up to 30 seconds. If necessary, use **Windows konum ayarlarını aç**
(Open Windows location settings) to enable location services and desktop app access.

The detected province/district and suggested prayer-time region are shown for
review. Click **Bu konumu kullan** (Use this location) to save the selection,
then **Takibi başlat**. If the district has no separate prayer-time entry,
the app clearly identifies its suggestion to use the provincial center.
Check the suggestion, especially near district boundaries.

If permission is denied, the location is too uncertain, the device is outside
Türkiye, or no match is found, your existing settings are retained.
**Vazgeç** (Cancel) also leaves them unchanged.

Coordinates are not saved or sent to an external geocoding service. Matching
runs locally against bundled boundaries. Only the location you confirm is saved.
Insat requests location when you click the button, not at automatic startup.
Windows' own location provider may require internet access. Manual selection
remains available if detection fails.

Boundary data: **© OpenStreetMap contributors / geoBoundaries**, simplified
from the 2021 dataset. See the [geographic data notes](data/geography/README.md)
for sources and licenses.

## Background operation and controls

**Hakkında** (About), at the top right and in the tray menu, shows the version,
data coverage, saved region, sources, privacy information, and a user-guide link.

Support: **of.sahin@outlook.com**.

- Closing the window with **×** hides it in the system tray. Monitoring continues.
- Opening the **Insat** shortcut or `Baslat.cmd` again shows the existing control
  panel. A second monitoring instance is not started in the same Windows session.
- Double-click the tray icon to reopen the panel. It may be in Windows' hidden icons area.
- **Takibi durdur** stops monitoring and immediately restores the previous volume.
- **Tamamen çık** (Exit completely) restores the volume and exits. These controls
  are also available by right-clicking the tray icon.
- The monitoring preference is saved. If you stopped monitoring before closing
  the app, it remains stopped on the next launch until you click **Takibi başlat**.

## Starting automatically with Windows

Enable **Bilgisayar açıldığında otomatik başlat** (Start automatically with Windows).
The app starts in the tray when the current Windows user signs in. No administrator
access is required. Unchecking the option removes the startup entry.
The last monitoring preference is retained; leave monitoring enabled to resume automatically.

This creates `Insat.lnk` in the Windows Startup folder. Before moving a portable
app folder, uncheck the option. Open the app from its new location and enable it
again. The installed app's uninstaller also removes its startup shortcut.
To remove a portable copy, disable automatic startup, choose **Tamamen çık**,
and delete its folder.

## Volume behavior

- A countdown window appears **15 seconds before volume reduction starts**, even
  when the main window is hidden in the tray. **Bu seferlik iptal et**
  (Skip this occurrence) skips only the upcoming prayer action or scheduled test.
  Later prayer times remain active. The popup closes when the action starts.
- By default, the morning time is **one hour before sunrise from March 13 through
  November 6**, and **imsak from November 7 through March 12**. The remaining four
  prayer times come directly from the CSV.
- Stop monitoring and cancel any test, then open **Sabah ezanı ayarları**
  (Morning prayer settings) to change the season start dates. **Kaydet** (Save)
  applies and persists the change. Start dates are inclusive and repeat every year.
  They must differ; February 29 is not accepted as an annual boundary.
  This is a user-defined monitoring rule. Original CSV imsak and sunrise values are preserved.
- Volume reduction starts **one minute before the effective prayer time**.
  With the default **60-second** fade, volume reaches zero at that time.
  Restoration starts **480 seconds after the prayer time** and takes **30 seconds**
  to return to the previous level.
- The app uses the configured duration to determine when the prayer ends;
  it does not use a microphone.
- Prayer duration and fade duration can be changed in the main window and are
  saved with **Takibi başlat**. The one-minute advance is fixed. A fade longer
  than 60 seconds finishes after the prayer time.
- A manual test starts at the time entered; it is not moved one minute earlier.
- The audio device is selected when each volume-control cycle begins and kept
  for that cycle. Normal stopping/exiting restores the previous volume. Forced
  termination through Task Manager or power loss cannot guarantee restoration.
- Keep the computer's local clock in the Türkiye time zone. Missed prayer times
  are not replayed after shutdown or sleep. If the device resumes during an active
  cycle, volume is adjusted according to elapsed time.

## Testing with a manually entered time

During a prayer action or test, the status card shows three live stages:
**1/3 Lowering volume → 2/3 Waiting through the prayer duration → 3/3 Restoring volume**.
The stage countdown, total remaining time, and percentage progress update
automatically. The indicator disappears after stopping or cancellation.

Open **Elle test saati…** (Manual test time) next to the daily schedule.
Enter a time in `HH:mm:ss` format and click **Testi planla** (Schedule test).
The test runs once using the main window's durations and restores volume over
30 seconds. For a quick check, stop monitoring, set prayer duration to **10** seconds
and fade duration to **2** seconds, and schedule a test a minute ahead.

If the time has already passed, the test is scheduled for tomorrow; the full
date and time are displayed. Tests also work while normal monitoring is stopped.
**Testi iptal et** (Cancel test) cancels a pending or active test and restores
the previous volume if it changed. **Takibi durdur** also cancels a test.
Tests do not alter the regular schedule or monitoring preference and are not
retained after restarting the app. A test missed by a minute or more is not replayed.

## Updating prayer-time data

1. Click **Takibi durdur** and cancel any test.
2. Select the province and prayer-time region to update.
3. Open **Vakitleri güncelle** at the top right, or the equivalent tray-menu option.
4. Check the year and click **Güncelle** (Update). The default is the computer's current year.
5. Once finished, click **Takibi başlat** to resume monitoring.

The selected region's annual table is downloaded directly from
**namazvakitleri.diyanet.gov.tr**. The reference is the
[official Diyanet İstanbul page](https://namazvakitleri.diyanet.gov.tr/tr-TR/9541/istanbul-namaz-vakitleri);
other regions use their own location IDs on the same official site.
Updates do not use GitHub or an intermediary prayer-data service.

If Diyanet has not published the requested year, all 365/366 days cannot be
validated, or the page format changes, the update is rejected and the existing
CSV remains unchanged. Internet access is required; Python, an API account,
and additional packages are not. Close the update window to cancel.

Only the selected region/year records are replaced; other records are preserved.
The updated file is saved to
`%LOCALAPPDATA%\Insat\data\diyanet_namaz_vakitleri_turkiye.csv`.
The previous file is kept with a `.backup` extension. The app prefers the updated
file on later launches. Reinstallation and uninstallation preserve this personal
data file, and the bundled CSV is unchanged. If you switch regions, update that
region's year too. One update does not download all of Türkiye. Updates are manual,
not automatic on launch, location changes, or the start of a new year.

## Data coverage

The bundled `data/diyanet_namaz_vakitleri_turkiye.csv` initially covers **2026**.
Use **Vakitleri güncelle** for a new year. The daily schedule is read locally.
If today's entry is missing, yesterday's times are not reused. The app reports
the issue and retries reading the file every 60 seconds.

Some central districts are grouped under the provincial center/prayer-time region.
Select the corresponding CSV entry. The location-ID catalog is rebuilt directly
from Diyanet's official selection lists using `tools/Update-DiyanetLocations.ps1`.
It does not require GitHub. Insat is not an official Diyanet application.

CSV columns: `il,ilce,tarih,imsak,gunes,ogle,ikindi,aksam,yatsi`.
Dates use `yyyy-MM-dd`, times use `HH:mm`, and encoding is UTF-8.

## Settings and troubleshooting

Per-user settings are stored in `%LOCALAPPDATA%\Insat\settings.json`.
The previous settings are kept as `settings.backup.json`; startup errors
are written to `error.log` in the same folder. To reset damaged settings,
exit the app and rename `settings.json` before opening it again.

## Project layout

```text
Kur.cmd                     Optional per-user installer
Baslat.cmd                  Double-click launcher
VERSION                     Product version
CHANGELOG.md                Release notes (Turkish)
README.md                   Turkish user guide
README.en.md                English user guide
insat.ps1                   PowerShell entry point
app/
  App.ps1                   Windows Forms, tray, single-instance control
  Core.ps1                  Monitoring, seasonal rules, settings, startup
  Data.cs                   CSV reader and location index
  Audio.cs                  Windows Core Audio access
  Setup.ps1                 Installation/uninstallation window
  Install.ps1               File installation and shortcuts
  Location.ps1              Prayer-time region matching
  Location.cs               Windows location and local boundary lookup
  Update.cs                 Official annual table validation and download
  Update.ps1                Data path selection and safe file replacement
  Update-Data.ps1            Command-line annual CSV update
assets/                     Application icon and image
data/
  diyanet_namaz_vakitleri_turkiye.csv
  diyanet_locations.json     Official Diyanet location IDs
  geography/                Local boundaries, sources, and licenses
tests/                      Behavior, installation, location, and data tests
tools/
  Build-Release.ps1          Build the portable ZIP and SHA-256 checksum
  Convert-Icon.ps1           Build Windows icon sizes
  Update-DiyanetLocations.ps1  Rebuild the official location catalog
  diyanet_csv_guncelle.py    Optional wrapper for the native updater
release/                    Distribution ZIP and checksum (Git-ignored)
```

Developer tools are not required to run the app and are excluded from the package.
The redundant old `.xlsx` copy has been removed. V1 is a portable Windows release
with optional per-user installation. Microsoft Store publication and code signing
are not included in this version.

## Development and verification

```powershell
# Open the interface
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\insat.ps1

# Show today's schedule without changing volume
.\insat.ps1 -Sehir Istanbul -Ilce Kucukcekmece -CheckSchedule

# Behavior and isolated installation/data tests
.\tests\insat.tests.ps1
.\tests\morning.tests.ps1
.\tests\install.tests.ps1
.\tests\location.tests.ps1
.\tests\update.tests.ps1

# UI smoke test without changing real volume or the real startup entry
.\insat.ps1 -SmokeTest -DataDirectory "$PWD\tests\.runtime\ui"

# Build the distribution package
.\tools\Build-Release.ps1
```

The optional Python helper invokes the same built-in Windows updater and
requires no third-party packages:

```powershell
python .\tools\diyanet_csv_guncelle.py --city Istanbul --district Istanbul
python .\tools\diyanet_csv_guncelle.py --year 2027 --city Ankara --district Polatli --output .\vakitler.csv
```

Without a year argument, the current year is used. The requested year must have
been published on Diyanet's page. Python is not required to run the app.
Single-instance communication is scoped to the Windows session. C# is compiled
in memory on startup using Windows' built-in compiler; no compiler download is needed.
