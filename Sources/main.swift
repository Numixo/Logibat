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
        for kind in ["keyboard", "mouse"] {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            items[kind] = item
            item.button?.image = NSImage(systemSymbolName: kind == "keyboard" ? "keyboard" : "computermouse", accessibilityDescription: kind == "keyboard" ? "Toetsenbord" : "Muis")
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
            item.button?.toolTip = reading.map { "\($0.name): \(value)" } ?? "\(kind == "keyboard" ? "Toetsenbord" : "Muis"): geen batterijgegevens"
            item.button?.setAccessibilityLabel(item.button?.toolTip)
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let title = NSMenuItem(title: "Logibat", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        if lastScan.readings.isEmpty {
            menu.addItem(withTitle: lastScan.permissionDenied ? "Toegang tot Logitech vereist" : "Geen actieve MX-apparaten gevonden", action: nil, keyEquivalent: "")
            menu.addItem(withTitle: "Zet je muis en toetsenbord aan en ververs.", action: nil, keyEquivalent: "")
        }
        for reading in lastScan.readings {
            let label = "\(reading.name) · \(reading.approximate ? "≈" : "")\(reading.percent)%\(reading.charging ? " · laadt op" : "")"
            let row = NSMenuItem(title: label, action: nil, keyEquivalent: "")
            row.image = NSImage(systemSymbolName: reading.kind == "keyboard" ? "keyboard" : "computermouse", accessibilityDescription: nil)
            menu.addItem(row)
        }
        if let date = checkedAt {
            menu.addItem(withTitle: "Gecontroleerd om \(date.formatted(date: .omitted, time: .shortened)) · elke 2 minuten", action: nil, keyEquivalent: "")
        }
        menu.addItem(.separator())
        let refreshItem = menu.addItem(withTitle: scanning ? "Bezig met uitlezen…" : "Nu verversen", action: #selector(refresh), keyEquivalent: "r")
        refreshItem.target = self
        refreshItem.isEnabled = !scanning
        let permission = menu.addItem(withTitle: "Toegang instellen…", action: #selector(openPermissions), keyEquivalent: "")
        permission.target = self
        let login = menu.addItem(withTitle: "Start bij inloggen", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "Stop Logibat", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
    }

    @objc private func openPermissions() {
        let alert = NSAlert()
        alert.messageText = "Geef Logibat toegang tot je Logitech-apparaten"
        alert.informativeText = "Voeg Logibat.app toe bij Systeeminstellingen → Privacy en beveiliging → Invoermonitoring en schakel de app in. Stop en open Logibat daarna opnieuw.\n\nLogibat leest uitsluitend Logitech-batterijgegevens via de vendor-interface; het registreert geen toetsaanslagen."
        alert.addButton(withTitle: "Open instellingen")
        alert.addButton(withTitle: "Annuleer")
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
            alert.messageText = "Automatisch starten kon niet worden gewijzigd"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
    @objc private func quit() { NSApp.terminate(nil) }
}

if CommandLine.arguments.contains("--diagnose") {
    let result = scanBatteries()
    print("Interfaces: \(result.interfaces), toestemming nodig: \(result.permissionDenied)")
    let data = try JSONEncoder().encode(result.readings)
    print(String(data: data, encoding: .utf8)!)
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
