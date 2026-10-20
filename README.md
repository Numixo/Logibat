# Logibat — Logitech MX Battery Indicator for macOS

**See your MX keyboard and mouse battery percentages in the Mac menu bar, even over a Logi Bolt USB receiver.**

![Logibat macOS menu bar battery indicator showing a Logitech MX Keys S keyboard at 100% and MX Master 3S mouse at 65% — interface illustration](docs/preview.svg)

Logibat is a **free, open-source Logitech MX battery monitor for Mac**. It shows separate keyboard and mouse icons with battery percentages directly in the macOS menu bar. Readings have been verified with **MX Keys S** and **MX Master 3S** connected through the same **Logi Bolt USB dongle**.

The native Swift app queries your devices directly, so you do not need to open Logi Options+ to check the battery level. No subscription, account, telemetry, or runtime dependencies.

**[Download Logibat for Mac](https://github.com/Numixo/Logibat/releases/latest)** · [Tested devices](#tested-logitech-mx-devices-and-connections) · [Frequently asked questions](#frequently-asked-questions)

<a id="download"></a>

## Download Logibat for Mac

Open **[the latest release](https://github.com/Numixo/Logibat/releases/latest)** and download **Logibat-1.0.1-macOS-AppleSilicon.zip**.

- **Requires:** macOS 13 Ventura or later and an Apple silicon Mac (M-series chip).
- **Download:** under 50 KB compressed; the app is approximately 176 KB. Sizes may change between builds.
- **Memory:** approximately 18 MB in one local idle measurement; usage varies by Mac and system state.
- **Release status:** an initial community release, locally signed and **not notarized by Apple**.

Unzip the download, move **Logibat.app** into **Applications**, then open it. Two status items appear in the menu bar; there is no Dock icon. All app menus, tooltips, and access instructions are in English.

macOS may initially block a downloaded app because its developer cannot be verified. Review the source and decide whether you trust the download. Apple's [guide to opening apps safely](https://support.apple.com/en-us/102445) explains the warning and available options. Logibat does not require disabling Gatekeeper or other system-wide protections.

<a id="what-it-does"></a>

## Logitech keyboard and mouse battery monitoring

- Shows separate keyboard and mouse icons with battery percentages.
- Refreshes every two minutes, with another check after the Mac wakes up.
- Uses custom outline icons matching the project illustration.
- Adds a charging indicator while a device is charging.
- Highlights a low battery in orange at 15% or below.
- Offers a manual refresh and an optional launch-at-login setting.
- Reads battery information directly using IOKit and Logitech HID++ 2.0.
- Does not change button assignments, scrolling, lighting, firmware, or device pairing.
- Does not need Options+ to read the battery. You can keep Options+ for your other Logitech settings.

The banner is an **interface illustration**, not a desktop screenshot. Its example values match the readings observed during the original hardware test.

<a id="tested-hardware"></a>

## Tested Logitech MX devices and connections

Successfully read both devices through the same **Logi Bolt USB receiver** on an Apple silicon Mac running **macOS 15.7.9**:

- **MX Keys S:** 100%.
- **MX Master 3S:** 65%.

These are test readings, not fixed values or battery-life estimates.

The implementation also probes Unifying receiver slots and direct Bluetooth vendor interfaces, and supports Unified Battery (`0x1004`) and older Battery Status (`0x1000`). **Unifying, direct Bluetooth, and other models have not been verified on hardware for this release.** Bluetooth works only if macOS exposes a compatible HID++ vendor interface. Devices reporting only a coarse battery level may not expose a usable exact percentage.

<a id="using-the-menu"></a>

## Check battery percentages in the macOS menu bar

Click either status icon to see the detected devices and last check time.

- **Refresh now** — Read both batteries now.
- **Launch at login** — Start Logibat automatically when you sign in.
- **Configure access…** — Open the access instructions.
- **Quit Logibat** — Stop the app.

If the menu bar shows a dash, no current reading was available. Wake or switch on the device and refresh. Unavailable devices do not keep displaying an old percentage as if it were current. With more than one detected device of a type, the status item shows the lowest reported percentage.

## Permissions

If macOS denies access, select **Configure access…**. Add Logibat under **System Settings → Privacy & Security → Input Monitoring**, enable it, then quit and reopen Logibat. Put the app in its final location before granting permission or enabling launch at login.

Input Monitoring is a broad macOS permission. Logibat's implementation opens only Logitech vendor HID interfaces and registers a vendor-report callback; it does not register keyboard or pointer event listeners. Access requirements depend on the connection and macOS version: the original USB receiver test worked without a new permission grant.

Rebuilding or replacing a locally signed app may require granting access again.

## Frequently asked questions

### How do I check my MX Master 3S battery on a Mac?

Open Logibat with your mouse connected through a Logi Bolt receiver. The mouse icon shows its current battery percentage in the menu bar. Click either Logibat icon and choose **Refresh now** for a new reading. This connection has been tested with an MX Master 3S.

### Can I see my MX Keys S battery percentage without opening Options+?

Yes. Logibat reads the keyboard battery directly and displays its percentage beside the keyboard icon. You can keep Options+ for button assignments and other Logitech features; Logibat handles battery monitoring separately.

### Does this MX battery indicator work with a USB dongle instead of Bluetooth?

Yes: Logibat has been tested with an **MX Keys S keyboard and MX Master 3S mouse connected through a Logi Bolt USB receiver**. The app reads battery information from the receiver rather than relying on a Bluetooth battery display. Unifying receiver support is implemented but has not been verified on hardware.

### Does Logibat support Bluetooth connections?

Direct Bluetooth is unverified for this release. The implementation can query a Bluetooth device only when macOS exposes a compatible HID++ vendor interface. The tested configuration uses the Logi Bolt dongle.

### Is Logibat free, and which Macs can run it?

Logibat is free to download and use under the MIT license, with no subscription or in-app purchases. The published app requires **macOS 13 or later and Apple silicon (an M-series Mac)**. The downloadable release does not support Intel Macs.

### Why does the battery indicator show a dash instead of a percentage?

A dash means the latest check did not produce a battery reading. Wake or turn on the device, check the receiver connection, then choose **Refresh now**. If macOS denies device access, follow the [permissions instructions](#permissions). A sleeping or disconnected device is not shown with an old reading as if it were current.

## Build from source

Install Apple's Xcode Command Line Tools, then run:

```sh
./build.sh
```

This creates `Logibat.app` for the architecture of the Mac that builds it. The published download is for Apple silicon; Intel builds have not been tested. The app uses Swift, AppKit, IOKit, and ServiceManagement, with no third-party packages and no downloads during the build.

To create the downloadable ZIP and checksum file:

```sh
./package.sh
```

To inspect live device discovery from Terminal:

```sh
./Logibat.app/Contents/MacOS/Logibat --diagnose
```

Terminal and the GUI app may have different macOS permissions. `--diagnose --trace` additionally prints raw vendor protocol replies for troubleshooting. Review traces before sharing them: vendor replies may contain device names or identifiers.

## Privacy and scope

No network requests, analytics, advertising, or automatic update checks. Battery queries run locally. Only macOS's built-in launch-at-login service is used when you enable that option.

Logibat is an independent community project and is not affiliated with or endorsed by Logitech or Apple. Product names belong to their respective owners.

## Protocol references

- [Logitech HID++ 2.0 draft specification](https://lekensteyn.nl/files/logitech/logitech_hidpp_2.0_specification_draft_2012-06-04.pdf)
- [Unified Battery wire format](https://openlogi.org/hidpp/features/x1004-unified-battery)

The implementation was independently written using Apple system frameworks.

## License

[MIT](LICENSE). Free to use, modify, and redistribute.
