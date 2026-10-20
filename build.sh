#!/bin/zsh
set -eu
cd "${0:A:h}"
APP="$PWD/Logibat.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" .build/module-cache
xcrun swiftc -O -module-cache-path "$PWD/.build/module-cache" -target "$(uname -m)-apple-macosx13.0" Sources/Battery.swift Sources/main.swift -o "$APP/Contents/MacOS/Logibat" -framework AppKit -framework IOKit -framework ServiceManagement
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "Gemaakt: $APP"
