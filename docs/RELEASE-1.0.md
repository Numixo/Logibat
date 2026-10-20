# Logibat 1.0

A tiny, native macOS menu bar app for Logitech MX keyboard and mouse batteries — including devices connected through a USB receiver.

## Download and install

1. Download **Logibat-1.0-macOS-AppleSilicon.zip** below.
2. Unzip it and move **Logibat.app** to **Applications**.
3. Open the app. Your keyboard and mouse each get their own menu bar icon and battery percentage.

**Requires macOS 13+ and an Apple silicon Mac.** Approximately 43 KB compressed / 176 KB installed. The app is locally signed, not Apple-notarized; macOS may show an unidentified developer warning. See the repository's installation guide before opening it.

## Included

- Separate keyboard and mouse battery percentages.
- Automatic checks every two minutes and after wake.
- Charging indicator and orange low-battery status at 15% or below.
- Manual refresh and optional launch at login.
- Direct HID++ battery queries, with no Logitech software required for battery monitoring.
- No network activity, telemetry, subscription, or third-party runtime packages.

## Verified setup and limitations

Tested with **MX Keys S + MX Master 3S over a Logi Bolt USB receiver**, on Apple silicon and macOS 15.7.9. Other devices, Unifying receivers, and direct Bluetooth interfaces remain unverified. The current app menus are in Dutch; the README explains each action in English.

Free and open source under the MIT license. Not affiliated with Logitech or Apple.

Verify the downloaded ZIP with the accompanying `SHA256SUMS.txt`:

```sh
shasum -a 256 -c SHA256SUMS.txt
```
