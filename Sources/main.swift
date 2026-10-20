import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var items: [String: NSStatusItem] = [:]
    private var timer: Timer?
    private var scanning = false
    private var lastScan = ScanResult()
    private var checkedAt: Date?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "nl.local.Logibat").count <= 1 else {
            NSApp.terminate(nil); return
        }
        // macOS places newly inserted status items to the left of earlier ones.
        for kind in ["mouse", "keyboard"] {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            items[kind] = item
            item.button?.image = deviceIcon(kind)
            item.button?.imagePosition = .imageLeading
            item.button?.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            item.button?.title = " —"
            let menu = NSMenu()
            menu.delegate = self
            item.menu = menu
        }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in self?.refresh() }
        timer?.tolerance = 15
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(wokeUp), name: NSWorkspace.didWakeNotification, object: nil)
    }

    @objc private func wokeUp() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.refresh() }
    }

    @objc private func refresh() {
        guard !scanning else { return }
        scanning = true
        DispatchQueue.global(qos: .utility).async {
            let result = scanBatteries()
            DispatchQueue.main.async {
                self.lastScan = result
                self.checkedAt = Date()
                self.scanning = false
                self.render()
            }
        }
    }

    private func render() {
        for (kind, item) in items {
            let reading = lastScan.readings.filter { $0.kind == kind }.min { $0.percent < $1.percent }
            let value = reading.map { "\($0.approximate ? "≈" : "")\($0.percent)%\($0.charging ? "ϟ" : "")" } ?? "—"
            item.button?.title = " " + value
            item.button?.contentTintColor = (reading?.percent ?? 100) <= 15 ? .systemOrange : nil
            item.button?.toolTip = reading.map { "\($0.name): \(value)" } ?? "\(kind == "keyboard" ? "Keyboard" : "Mouse"): no battery data"
            item.button?.setAccessibilityLabel(item.button?.toolTip)
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let title = NSMenuItem(title: "Logibat", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        if lastScan.readings.isEmpty {
            menu.addItem(withTitle: lastScan.permissionDenied ? "Logitech access required" : "No active MX devices found", action: nil, keyEquivalent: "")
            menu.addItem(withTitle: "Wake your mouse and keyboard, then refresh.", action: nil, keyEquivalent: "")
        }
        for reading in lastScan.readings {
            let label = "\(reading.name) · \(reading.approximate ? "≈" : "")\(reading.percent)%\(reading.charging ? " · charging" : "")"
            let row = NSMenuItem(title: label, action: nil, keyEquivalent: "")
            row.image = deviceIcon(reading.kind)
            menu.addItem(row)
        }
        if let date = checkedAt {
            menu.addItem(withTitle: "Checked at \(date.formatted(date: .omitted, time: .shortened)) · every 2 minutes", action: nil, keyEquivalent: "")
        }
        menu.addItem(.separator())
        let refreshItem = menu.addItem(withTitle: scanning ? "Reading batteries…" : "Refresh now", action: #selector(refresh), keyEquivalent: "r")
        refreshItem.target = self
        refreshItem.isEnabled = !scanning
        let permission = menu.addItem(withTitle: "Configure access…", action: #selector(openPermissions), keyEquivalent: "")
        permission.target = self
        let login = menu.addItem(withTitle: "Launch at login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "Quit Logibat", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
    }

    @objc private func openPermissions() {
        let alert = NSAlert()
        alert.messageText = "Allow Logibat to access your Logitech devices"
        alert.informativeText = "Add Logibat.app under System Settings → Privacy & Security → Input Monitoring and enable it. Then quit and reopen Logibat.\n\nLogibat only reads Logitech battery data through the vendor interface; it does not record keystrokes."
        alert.addButton(withTitle: "Open settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
            NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
        }
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not change launch at login"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
    @objc private func quit() { NSApp.terminate(nil) }
}

if CommandLine.arguments.contains("--diagnose") {
    let result = scanBatteries()
    print("Interfaces: \(result.interfaces), permission required: \(result.permissionDenied)")
    let data = try JSONEncoder().encode(result.readings)
    print(String(data: data, encoding: .utf8)!)
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
