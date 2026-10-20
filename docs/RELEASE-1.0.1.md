# Logibat 1.0.1

A tiny, native macOS menu bar app for Logitech MX keyboard and mouse batteries, including devices connected through a Logi Bolt USB receiver.

![Logibat interface illustration](https://raw.githubusercontent.com/Numixo/Logibat/main/docs/preview.svg)

## Changes

- Custom outline keyboard and mouse icons matching the project illustration.
- English-only menus, tooltips, access instructions, and diagnostic labels.
- Initial menu bar order: keyboard first, mouse second (from left to right).

## Download and install

Download **Logibat-1.0.1-macOS-AppleSilicon.zip**, unzip it, move **Logibat.app** into **Applications**, and open it. Quit the old Logibat before replacing it.

**Requires macOS 13 or newer and an Apple silicon Mac (M-series). This download does not support Intel Macs.**

The app is locally signed and not notarized by Apple. macOS may show an unidentified developer warning. See the [installation guide](https://github.com/Numixo/Logibat#download) for details. Updating a locally signed app may require granting Input Monitoring access again.

## Features

Separate keyboard and mouse battery percentages, automatic checks every two minutes and after wake, charging and low-battery indicators, manual refresh, and optional launch at login. No subscription, telemetry, network requests, or third-party runtime packages.

## Hardware verification

Tested with **MX Keys S + MX Master 3S over a Logi Bolt USB receiver**, on an Apple silicon Mac running macOS 15.7.9. Unifying, direct Bluetooth, and other models have not been verified on hardware.

The banner is an interface illustration with example readings, not a desktop screenshot. Free and open source under the MIT license. Not affiliated with Logitech or Apple.

Download `SHA256SUMS.txt` alongside the ZIP and run:

```sh
shasum -a 256 -c SHA256SUMS.txt
```
